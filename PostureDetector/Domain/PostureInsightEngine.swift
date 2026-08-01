//
//  PostureInsightEngine.swift
//  PostureDetector
//
//  The "AI coach" without the AI (yet): a rule engine that recognises ~100
//  distinct states in the posture history — tracking gaps, streaks, score
//  bands, trends, consistency, alert load, session length, milestones and
//  recoveries — and pairs each one with a pre-written summary and a concrete
//  recommendation.
//
//  A real model can be dropped in later behind `PostureInsightEngine.insights(...)`:
//  the screen only ever sees `[PostureInsight]`.
//

import Foundation

// MARK: - Model

enum InsightTone {
    case celebration    // milestone / record
    case positive       // things are going well
    case encouraging    // fine, keep nudging
    case neutral        // informational
    case warning        // slipping
    case critical       // long gap / very poor
}

enum InsightCategory: String {
    case welcome, gap, streak, score, run, trend, consistency, alerts, duration, milestone, recovery, pattern

    /// Short label shown on the card.
    var displayName: String {
        switch self {
        case .welcome:     return "Getting started"
        case .gap:         return "Tracking"
        case .streak:      return "Streak"
        case .score:       return "Latest session"
        case .run:         return "Momentum"
        case .trend:       return "Trend"
        case .consistency: return "Consistency"
        case .alerts:      return "Alerts"
        case .duration:    return "Sessions"
        case .milestone:   return "Milestone"
        case .recovery:    return "Momentum"
        case .pattern:     return "Pattern"
        }
    }
}

struct PostureInsight: Identifiable {
    /// Stable rule key (e.g. "gap.3days") — also useful for analytics.
    let id: String
    let category: InsightCategory
    let tone: InsightTone
    let icon: String
    let title: String
    let summary: String
    let recommendation: String
    let priority: Int
    /// Signed point change when the insight is about movement (trend, day-over-day),
    /// so the UI can show a coloured arrow. nil for everything else.
    let delta: Int?
}

// MARK: - Engine

enum PostureInsightEngine {

    /// Top insights for the history, most important first, at most one per category.
    static func insights(for history: [PostureHistory],
                         samples: [PostureDaySamples] = [],
                         now: Date = Date(),
                         limit: Int = 3) -> [PostureInsight] {
        let ctx = InsightContext(history: history, now: now)

        let candidates: [PostureInsight?] = [
            welcomeInsight(ctx),
            gapInsight(ctx),
            streakInsight(ctx),
            scoreInsight(ctx),
            runInsight(ctx),
            trendInsight(ctx),
            consistencyInsight(ctx),
            patternInsight(ctx),
            alertInsight(ctx),
            durationInsight(ctx),
            milestoneInsight(ctx),
            recoveryInsight(ctx)
        ]

        // Pattern rules only speak once the intraday data supports them.
        let deep = deepInsights(from: samples, now: now)

        return (candidates.compactMap { $0 } + deep)
            .sorted { $0.priority > $1.priority }
            .prefix(limit)
            .map { $0 }
    }

    /// The single headline insight (nil only when there is no history at all).
    static func headline(for history: [PostureHistory],
                         samples: [PostureDaySamples] = [],
                         now: Date = Date()) -> PostureInsight? {
        insights(for: history, samples: samples, now: now, limit: 1).first
    }

    /// Everything the coach has to say: the headline, the other signals it
    /// picked up, the concrete steps that follow from them, and the numbers
    /// the read is based on.
    static func report(for history: [PostureHistory],
                       samples: [PostureDaySamples] = [],
                       now: Date = Date()) -> CoachReport? {
        let found = insights(for: history, samples: samples, now: now, limit: 4)
        guard let headline = found.first else { return nil }
        var signals = Array(found.dropFirst())
        // A signal pointing the opposite way to the headline reads as a contradiction.
        if let lead = headline.delta {
            signals = signals.filter { signal in
                guard let delta = signal.delta else { return true }
                return (delta >= 0) == (lead >= 0)
            }
        }

        // One tip per topic: three different rules all saying "track today"
        // reads as padding, so only the highest-priority one survives.
        var tips: [CoachTip] = []
        var usedTopics: Set<InsightActionTopic> = []
        for insight in [headline] + signals {
            let copy = PostureInsightDetails.tip(for: insight.id)
            guard !tips.contains(where: { $0.title == copy.title }),
                  usedTopics.insert(insight.actionTopic).inserted else { continue }
            tips.append(CoachTip(id: insight.id, icon: insight.icon,
                                 title: copy.title, note: copy.note))
        }

        let ctx = InsightContext(history: history, now: now)
        var metrics: [CoachMetric] = []
        if let average = ctx.avg30 {
            metrics.append(CoachMetric(label: "30-day avg", value: "\(average)", delta: ctx.weekDelta))
        }
        metrics.append(CoachMetric(label: "Streak", value: "\(ctx.currentStreak)d", delta: nil))
        metrics.append(CoachMetric(label: "Tracked", value: "\(ctx.daysTracked30)/30", delta: nil))
        let upright = ctx.uprightHours(daysAgo: 0..<30)
        metrics.append(CoachMetric(label: "Upright",
                                   value: upright >= 10 ? "\(Int(upright))h" : String(format: "%.1fh", upright),
                                   delta: nil))

        let readiness = PosturePatternAnalyzer.readiness(from: samples, now: now)
        let hours = readiness.isReady
            ? PosturePatternAnalyzer.patterns(from: samples, now: now).hours
            : []

        return CoachReport(headline: headline,
                           deepProgress: readiness.isReady ? nil : readiness,
                           signals: signals,
                           tips: Array(tips.prefix(3)),
                           metrics: metrics,
                           daysAnalysed: ctx.daysTracked30,
                           hourProfile: hours)
    }
}

// MARK: - Report

struct CoachMetric: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    /// Signed week-over-week change, when the metric has one.
    let delta: Int?
}

/// One actionable step: a short imperative and a single supporting clause.
struct CoachTip: Identifiable {
    let id: String
    let icon: String
    let title: String
    let note: String
}

struct CoachReport {
    let headline: PostureInsight
    /// Set while the intraday data is still too thin for pattern analysis.
    var deepProgress: DeepReadiness?
    /// The other things the engine noticed, in priority order.
    let signals: [PostureInsight]
    /// Concrete next steps, deduplicated, most important first.
    let tips: [CoachTip]
    let metrics: [CoachMetric]
    let daysAnalysed: Int
    /// Score per clock hour, when the intraday data supports it.
    var hourProfile: [HourStat] = []
}

// MARK: - Context

/// Everything the rules need, derived once from the raw history.
struct InsightContext {
    let now: Date
    let calendar: Calendar

    /// Days that actually have a session, oldest → newest.
    let tracked: [PostureHistory]
    private let byDay: [Date: PostureHistory]

    init(history: [PostureHistory], now: Date) {
        let cal = Calendar.current
        self.calendar = cal
        self.now = now

        let withData = history.filter { $0.totalMonitoredSeconds > 0 }
        self.tracked = withData.sorted { $0.date < $1.date }
        self.byDay = Dictionary(
            withData.map { (cal.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { a, b in a.totalMonitoredSeconds >= b.totalMonitoredSeconds ? a : b }
        )
    }

    // MARK: Days

    var today: Date { calendar.startOfDay(for: now) }

    func day(_ daysAgo: Int) -> PostureHistory? {
        guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
        return byDay[date]
    }

    var todayHistory: PostureHistory? { day(0) }
    var yesterdayHistory: PostureHistory? { day(1) }
    var latest: PostureHistory? { tracked.last }
    var hasAnyData: Bool { !tracked.isEmpty }
    var totalTrackedDays: Int { tracked.count }

    /// 0 when there is a session today, nil when nothing was ever tracked.
    var daysSinceLastSession: Int? {
        guard let latest = latest else { return nil }
        let last = calendar.startOfDay(for: latest.date)
        return calendar.dateComponents([.day], from: last, to: today).day
    }

    // MARK: Scores

    /// Scores of tracked days inside a days-ago window (0 = today).
    func scores(daysAgo range: Range<Int>) -> [Int] {
        range.compactMap { day($0)?.score }
    }

    func average(daysAgo range: Range<Int>) -> Int? {
        let s = scores(daysAgo: range)
        guard !s.isEmpty else { return nil }
        return s.reduce(0, +) / s.count
    }

    var avg7: Int? { average(daysAgo: 0..<7) }
    var prevAvg7: Int? { average(daysAgo: 7..<14) }
    var avg30: Int? { average(daysAgo: 0..<30) }
    var prevAvg30: Int? { average(daysAgo: 30..<60) }

    /// Week-over-week change; nil when either week has no sessions.
    var weekDelta: Int? {
        guard let a = avg7, let b = prevAvg7 else { return nil }
        return a - b
    }

    var monthDelta: Int? {
        guard let a = avg30, let b = prevAvg30 else { return nil }
        return a - b
    }

    /// Spread of the last week's scores — high means an erratic week.
    var weekSpread: Int? {
        let s = scores(daysAgo: 0..<7)
        guard s.count >= 4, let min = s.min(), let max = s.max() else { return nil }
        return max - min
    }

    var daysTracked30: Int { scores(daysAgo: 0..<30).count }
    var daysTracked7: Int { scores(daysAgo: 0..<7).count }

    var bestDay: PostureHistory? { tracked.max(by: { $0.score < $1.score }) }
    var isPersonalBestToday: Bool {
        guard let today = todayHistory, let best = bestDay else { return false }
        return calendar.isDate(best.date, inSameDayAs: today.date) && tracked.count >= 3
    }

    /// Best / worst score of the last 14 tracked days, excluding today.
    var bestOfRecent: Int? { scores(daysAgo: 1..<14).max() }
    var worstOfRecent: Int? { scores(daysAgo: 1..<14).min() }

    // MARK: Streaks

    /// Consecutive tracked days ending today (or ending yesterday if today is still empty).
    var currentStreak: Int {
        var streak = 0
        var offset = day(0) == nil ? 1 : 0
        while day(offset) != nil {
            streak += 1
            offset += 1
        }
        return streak
    }

    /// Longest run of consecutive tracked days in the whole history.
    var longestStreak: Int {
        let days = Set(tracked.map { calendar.startOfDay(for: $0.date) })
        var best = 0
        for start in days {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: start),
                  !days.contains(previous) else { continue }
            var run = 0
            var cursor = start
            while days.contains(cursor) {
                run += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            best = max(best, run)
        }
        return best
    }

    /// Length of the run that the current gap interrupted (0 when no gap).
    var brokenStreakLength: Int {
        guard let since = daysSinceLastSession, since >= 1 else { return 0 }
        var run = 0
        var offset = since
        while day(offset) != nil {
            run += 1
            offset += 1
        }
        return run
    }

    /// Days of silence right before the latest session (0 when there is no
    /// earlier session at all, or when the day before was tracked too).
    var gapBeforeLatest: Int {
        guard let latest = latest else { return 0 }
        let latestDay = calendar.startOfDay(for: latest.date)
        let earlier = tracked
            .map { calendar.startOfDay(for: $0.date) }
            .filter { $0 < latestDay }
        guard let previous = earlier.max() else { return 0 }
        return (calendar.dateComponents([.day], from: previous, to: latestDay).day ?? 1) - 1
    }

    /// Longest streak that does not include the run currently in progress —
    /// the bar a new record has to clear.
    var bestStreakBeforeCurrent: Int {
        let days = Set(tracked.map { calendar.startOfDay(for: $0.date) })
        let currentRun = Set((0..<currentStreak).compactMap { offset -> Date? in
            let base = day(0) == nil ? 1 : 0
            return calendar.date(byAdding: .day, value: -(offset + base), to: today)
        })
        let older = days.subtracting(currentRun)
        var best = 0
        for start in older {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: start),
                  !older.contains(previous) else { continue }
            var run = 0
            var cursor = start
            while older.contains(cursor) {
                run += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            best = max(best, run)
        }
        return best
    }

    // MARK: Runs

    /// How many of the most recent tracked days scored at or above `threshold`.
    func runAtLeast(_ threshold: Int) -> Int {
        var run = 0
        for history in tracked.reversed() {
            if history.score >= threshold { run += 1 } else { break }
        }
        return run
    }

    /// How many of the most recent tracked days scored below `threshold`.
    func runBelow(_ threshold: Int) -> Int {
        var run = 0
        for history in tracked.reversed() {
            if history.score < threshold { run += 1 } else { break }
        }
        return run
    }

    /// True when the last three tracked days climbed (or fell) every day.
    var isImprovingRun: Bool {
        let last = tracked.suffix(3).map { $0.score }
        guard last.count == 3 else { return false }
        return last[0] < last[1] && last[1] < last[2]
    }

    var isDecliningRun: Bool {
        let last = tracked.suffix(3).map { $0.score }
        guard last.count == 3 else { return false }
        return last[0] > last[1] && last[1] > last[2]
    }

    // MARK: Time & alerts

    var totalUprightHours: Double {
        tracked.reduce(0.0) { $0 + $1.goodPostureSeconds } / 3600
    }

    /// Good-posture hours inside a window.
    func uprightHours(daysAgo range: Range<Int>) -> Double {
        range.compactMap { day($0)?.goodPostureSeconds }.reduce(0, +) / 3600
    }

    func monitoredHours(daysAgo range: Range<Int>) -> Double {
        range.compactMap { day($0)?.totalMonitoredSeconds }.reduce(0, +) / 3600
    }

    /// Average length of a tracked day's monitoring, in minutes, over the last 7 days.
    var avgSessionMinutes: Double? {
        let durations = (0..<7).compactMap { day($0)?.totalMonitoredSeconds }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count) / 60
    }

    /// Total alerts inside a window, with the hours they were spread over.
    func alertLoad(daysAgo range: Range<Int>) -> (alerts: Int, hours: Double) {
        let days = range.compactMap { day($0) }
        return (days.reduce(0) { $0 + $1.alertCount },
                days.reduce(0.0) { $0 + $1.totalMonitoredSeconds } / 3600)
    }

    /// True when today is the longest session ever recorded by a clear margin.
    var isLongestSessionEver: Bool {
        guard let today = todayHistory, tracked.count >= 5 else { return false }
        let others = tracked.filter { !calendar.isDate($0.date, inSameDayAs: today.date) }
        guard let longest = others.map({ $0.totalMonitoredSeconds }).max() else { return false }
        return today.totalMonitoredSeconds > longest * 1.15
    }

    /// The missed days between the last session and today are all weekend days.
    var missedDaysAreWeekend: Bool {
        guard let since = daysSinceLastSession, since >= 1, since <= 2 else { return false }
        return (1...since).allSatisfy { offset in
            guard let date = calendar.date(byAdding: .day, value: -(offset - 1), to: today) else { return false }
            let weekday = calendar.component(.weekday, from: date)
            return weekday == 1 || weekday == 7
        }
    }

    func alertsPerHour(daysAgo range: Range<Int>) -> Double? {
        let days = range.compactMap { day($0) }
        let hours = days.reduce(0.0) { $0 + $1.totalMonitoredSeconds } / 3600
        guard hours >= 0.5 else { return nil }
        return Double(days.reduce(0) { $0 + $1.alertCount }) / hours
    }

    // MARK: Weekday pattern

    /// Average score per weekday (1 = Sunday), only where there are 2+ samples.
    var weekdayAverages: [Int: Int] {
        var sums: [Int: (total: Int, count: Int)] = [:]
        for history in tracked {
            let weekday = calendar.component(.weekday, from: history.date)
            let current = sums[weekday] ?? (0, 0)
            sums[weekday] = (current.total + history.score, current.count + 1)
        }
        return sums.filter { $0.value.count >= 2 }.mapValues { $0.total / $0.count }
    }

    func weekdayName(_ weekday: Int) -> String {
        let symbols = DateFormatter().weekdaySymbols ?? []
        let index = weekday - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    /// Weekend average vs weekday average, when both have enough samples.
    var weekendGap: (weekend: Int, weekday: Int)? {
        var weekend: [Int] = [], week: [Int] = []
        for history in tracked {
            let day = calendar.component(.weekday, from: history.date)
            if day == 1 || day == 7 { weekend.append(history.score) } else { week.append(history.score) }
        }
        guard weekend.count >= 3, week.count >= 3 else { return nil }
        return (weekend.reduce(0, +) / weekend.count, week.reduce(0, +) / week.count)
    }
}

// MARK: - Rules

extension PostureInsightEngine {

    static func make(_ id: String, _ category: InsightCategory, _ tone: InsightTone,
                     _ icon: String, _ title: String, _ summary: String,
                     _ recommendation: String, _ priority: Int,
                     delta: Int? = nil) -> PostureInsight {
        PostureInsight(id: id, category: category, tone: tone, icon: icon,
                       title: title, summary: summary, recommendation: recommendation,
                       priority: priority, delta: delta)
    }
}

private extension PostureInsightEngine {

    // MARK: A — First steps

    static func welcomeInsight(_ ctx: InsightContext) -> PostureInsight? {
        guard ctx.totalTrackedDays <= 7 else { return nil }
        // A long gap is a different story — let the gap rules speak instead.
        guard !ctx.hasAnyData || (ctx.daysSinceLastSession ?? 0) <= 2 else { return nil }

        if !ctx.hasAnyData {
            return make("welcome.empty", .welcome, .neutral, "sparkles",
                        "Let's get your baseline",
                        "There's nothing to analyse yet — your journal is empty.",
                        "Pop in your AirPods and run a 20-minute session while you work. That's enough for your first score.",
                        100)
        }

        let days = ctx.totalTrackedDays

        if days == 1, ctx.todayHistory != nil {
            let score = ctx.todayHistory?.score ?? 0
            return make("welcome.firstDay", .welcome, .celebration, "sparkles",
                        "Your first session is in",
                        "You scored \(score) on day one. That's your baseline — everything from here is progress you can see.",
                        "Track again tomorrow. Two days is all it takes before trends start appearing.",
                        96)
        }
        if days == 1 {
            return make("welcome.firstDayPast", .welcome, .encouraging, "sparkles",
                        "One session down",
                        "You have a single day on record, so there's no pattern to read yet.",
                        "Add a second session today — the coach needs a few days before it can spot habits.",
                        94)
        }
        if days == 2 {
            return make("welcome.secondDay", .welcome, .encouraging, "sparkles",
                        "Two days on the board",
                        "Two sessions recorded. Enough for a first comparison, not yet enough for a trend.",
                        "Aim for three days this week — that's the point where daily patterns start to show.",
                        90)
        }
        if days <= 4 {
            return make("welcome.earlyDays", .welcome, .encouraging, "chart.line.uptrend.xyaxis",
                        "Finding your baseline",
                        "\(days) sessions recorded. Your average will settle once there's about a week of data.",
                        "Track on a normal working day — an unusual day will skew your baseline.",
                        86)
        }
        return make("welcome.firstWeek", .welcome, .positive, "checkmark.seal.fill",
                    "First week nearly complete",
                    "\(days) days tracked. Your weekly average is starting to mean something.",
                    "Keep going to seven days — then you'll get week-over-week comparisons.",
                    84)
    }

    // MARK: B — Tracking gaps

    static func gapInsight(_ ctx: InsightContext) -> PostureInsight? {
        guard let since = ctx.daysSinceLastSession, since >= 1 else { return nil }
        let broken = ctx.brokenStreakLength

        if ctx.missedDaysAreWeekend, ctx.totalTrackedDays >= 5 {
            return make("gap.weekend", .gap, .neutral, "calendar",
                        "Weekend off the clock",
                        "The only days without a session were the weekend — your working-week record is unbroken.",
                        "If you spend weekends on a laptop too, one short weekend session is worth tracking.",
                        66)
        }

        switch since {
        case 1:
            if broken >= 5 {
                return make("gap.1day.streakAtRisk", .gap, .warning, "exclamationmark.triangle.fill",
                            "Your streak ends today",
                            "No session yet today, and a \(broken)-day streak is on the line.",
                            "Even ten minutes counts. Start a short session before the day is out.",
                            92)
            }
            return make("gap.1day", .gap, .encouraging, "clock.badge.exclamationmark",
                        "No session yet today",
                        "You tracked yesterday but today is still empty.",
                        "Start a session next time you sit down to work — consecutive days are what move the average.",
                        70)
        case 2:
            return make("gap.2days", .gap, .encouraging, "clock.badge.exclamationmark",
                        "Two quiet days",
                        "It's been two days since your last session, so this week's average is thinning out.",
                        "Track today, even briefly. Short sessions keep the picture honest.",
                        78)
        case 3:
            return make("gap.3days", .gap, .warning, "exclamationmark.triangle.fill",
                        "Three days without data",
                        "Nothing has been recorded for three days. Trends go stale fast at this point.",
                        "Get one session in today — a single day is enough to restart your streak.",
                        84)
        case 4...6:
            return make("gap.4to6days", .gap, .warning, "exclamationmark.triangle.fill",
                        "\(since) days off the radar",
                        "You've been away \(since) days\(broken >= 3 ? ", ending a \(broken)-day run" : ""). Your 30-day average is drifting toward older data.",
                        "Restart small: one 15-minute session today, then aim for two more this week.",
                        88)
        case 7...13:
            return make("gap.week", .gap, .critical, "moon.zzz.fill",
                        "A week without tracking",
                        "It's been \(since) days. Whatever changed in your posture since then isn't in the data.",
                        "Treat today as a fresh baseline — track one normal working session and compare from there.",
                        94)
        case 14...29:
            return make("gap.fortnight", .gap, .critical, "moon.zzz.fill",
                        "Two weeks of silence",
                        "\(since) days without a session. Your recent stats now describe someone else's month.",
                        "Start over gently: one session today, no targets. Just get a current reading.",
                        96)
        default:
            return make("gap.month", .gap, .critical, "moon.zzz.fill",
                        "It's been a while",
                        "\(since) days since your last session — long enough that your old habits may have crept back.",
                        "Recalibrate your AirPods and run one session today to see where you actually stand.",
                        98)
        }
    }

    // MARK: C — Streaks

    static func streakInsight(_ ctx: InsightContext) -> PostureInsight? {
        let streak = ctx.currentStreak
        guard streak >= 2, ctx.todayHistory != nil || ctx.daysSinceLastSession == 0 else {
            return streakOffDayInsight(ctx)
        }
        let best = ctx.longestStreak

        // Records: only on the day the old best is actually beaten or matched.
        let previousBest = ctx.bestStreakBeforeCurrent
        if previousBest >= 4, streak == previousBest + 1 {
            return make("streak.record", .streak, .celebration, "crown.fill",
                        "\(streak) days — a new record",
                        "You just passed your previous best run of \(previousBest) days. Consistency like this is what actually changes posture.",
                        "Protect the streak with a minimum: ten tracked minutes counts on a busy day.",
                        93)
        }
        if previousBest >= 4, streak == previousBest {
            return make("streak.nearRecord", .streak, .positive, "flame.fill",
                        "You've matched your record",
                        "\(streak) days in a row — level with your best ever run. One more sets a new mark.",
                        "Schedule tomorrow's session now so the decision is already made.",
                        91)
        }
        _ = best

        switch streak {
        case 2:
            return make("streak.2", .streak, .encouraging, "flame.fill",
                        "Two days in a row",
                        "Back-to-back sessions. Two is where a habit starts to feel real.",
                        "Track tomorrow at the same time of day — repetition beats intensity.",
                        62)
        case 3:
            return make("streak.3", .streak, .positive, "flame.fill",
                        "Three-day streak",
                        "Three consecutive days tracked. Your weekly average is now built on real data.",
                        "Push for five. That's the point where most people stop having to think about it.",
                        68)
        case 4:
            return make("streak.4", .streak, .positive, "flame.fill",
                        "Four days running",
                        "Four in a row. Your posture data is dense enough to spot daily patterns.",
                        "One more day makes it a full working week — worth the effort.",
                        70)
        case 5:
            return make("streak.5", .streak, .positive, "flame.fill",
                        "Five-day streak",
                        "A full working week of sessions. Nicely done.",
                        "Track one weekend day too — weekend posture is usually a different story.",
                        74)
        case 6:
            return make("streak.6", .streak, .positive, "flame.fill",
                        "Six days in a row",
                        "Six consecutive days. One more and you've got a perfect week.",
                        "Finish the week — then take stock of how your average moved.",
                        76)
        case 7:
            return make("streak.7", .streak, .celebration, "flame.fill",
                        "A perfect week",
                        "Seven days without a gap. Every day of the last week is on record.",
                        "Now aim for quality, not just presence: try to beat your weekly average by 3 points.",
                        86)
        case 8...9:
            return make("streak.8to9", .streak, .positive, "flame.fill",
                        "\(streak)-day streak",
                        "Over a week of unbroken tracking. Your data is as good as it gets.",
                        "Ten days is in reach — keep the same routine for two more days.",
                        66)
        case 10...13:
            return make("streak.10", .streak, .celebration, "flame.fill",
                        "Ten days and counting",
                        "\(streak) days in a row. This is habit territory now.",
                        "Use the momentum: pick your worst weekday and give it extra attention.",
                        70)
        case 14...20:
            return make("streak.14", .streak, .celebration, "crown.fill",
                        "Two solid weeks",
                        "\(streak) consecutive days tracked. Very few people get this far.",
                        "Compare this week to last — at this consistency the trend line is trustworthy.",
                        72)
        case 21...29:
            return make("streak.21", .streak, .celebration, "crown.fill",
                        "Three weeks unbroken",
                        "\(streak) days in a row. Tracking has stopped being a chore.",
                        "Raise the bar: set your target score 5 points above your 30-day average.",
                        73)
        case 30...49:
            return make("streak.30", .streak, .celebration, "crown.fill",
                        "A full month, every day",
                        "\(streak) consecutive days. Your history is now a genuine record of your posture, not a sample.",
                        "Look back at day one and compare — the difference is usually bigger than it feels.",
                        74)
        case 50...99:
            return make("streak.50", .streak, .celebration, "crown.fill",
                        "\(streak) days straight",
                        "Fifty-plus consecutive days. This is exceptional consistency.",
                        "Keep it effortless — protect the routine rather than chasing bigger numbers.",
                        75)
        default:
            return make("streak.100", .streak, .celebration, "crown.fill",
                        "\(streak) days — remarkable",
                        "A hundred-plus day streak. Your posture habit is fully established.",
                        "Consider what's next: fewer alerts per hour is a better goal than more days.",
                        76)
        }
    }

    /// Streak-adjacent states when today hasn't been tracked yet.
    static func streakOffDayInsight(_ ctx: InsightContext) -> PostureInsight? {
        let broken = ctx.brokenStreakLength
        if ctx.daysTracked7 >= 5, ctx.currentStreak < 3 {
            return make("streak.mostOfWeek", .streak, .positive, "calendar.badge.checkmark",
                        "\(ctx.daysTracked7) of the last 7 days",
                        "No unbroken run, but you've tracked most of the week. Coverage matters more than a perfect chain.",
                        "Two days back to back would turn this into a streak — try today and tomorrow.",
                        64)
        }
        guard let since = ctx.daysSinceLastSession, since >= 2, broken >= 5 else { return nil }
        return make("streak.broken", .streak, .warning, "flame",
                    "A \(broken)-day run ended",
                    "Your \(broken)-day streak stopped \(since) days ago. It happens — the history is still yours.",
                    "Start a new one today. Getting back within a week keeps your monthly average intact.",
                    82)
    }

    // MARK: D — Latest score

    static func scoreInsight(_ ctx: InsightContext) -> PostureInsight? {
        let isToday = ctx.todayHistory != nil
        guard let day = ctx.todayHistory ?? ctx.latest else { return nil }
        let score = day.score
        let label = isToday ? "Today" : "Your last session"
        let lowered = isToday ? "today" : "in your last session"

        if ctx.isPersonalBestToday {
            return make("score.personalBest", .score, .celebration, "trophy.fill",
                        "Personal best: \(score)",
                        "\(label) is the best score you've ever recorded. Whatever you did, it worked.",
                        "Note what was different — chair, desk height, break rhythm — and repeat it tomorrow.",
                        94)
        }

        if score == 100 {
            return make("score.flawless", .score, .celebration, "star.circle.fill",
                        "A flawless session",
                        "Not a single minute of poor posture \(lowered). Perfect score.",
                        "Sessions this clean are usually short — try holding it across a longer stretch next.",
                        82)
        }
        if let average = ctx.avg30, score >= average + 15, ctx.daysTracked30 >= 5 {
            return make("score.aboveUsual", .score, .positive, "arrow.up.forward.circle.fill",
                        "\(score) — well above your usual",
                        "\(label) beat your 30-day average of \(average) by \(score - average) points.",
                        "Work out what was different today and copy it tomorrow — days like this aren't luck.",
                        79, delta: score - average)
        }

        switch score {
        case 95...100:
            return make("score.perfect", .score, .celebration, "star.fill",
                        "Near-perfect \(score)",
                        "You held good posture almost the entire session \(lowered). That's about as clean as it gets.",
                        "Don't chase 100 — keep this setup and let the average catch up instead.",
                        80)
        case 90...94:
            return make("score.excellent", .score, .positive, "star.fill",
                        "Excellent — \(score)",
                        "\(label) landed in the top band. Only a handful of minutes were spent slouching.",
                        "Keep the same desk setup tomorrow; consistency at this level compounds fast.",
                        76)
        case 80...89:
            return make("score.great", .score, .positive, "checkmark.circle.fill",
                        "Strong day at \(score)",
                        "\(label) sits comfortably in the great band — four out of five minutes upright.",
                        "The easiest gain now is the last hour of the day, when posture usually drops.",
                        70)
        case 70...79:
            return make("score.good", .score, .encouraging, "checkmark.circle",
                        "Solid \(score)",
                        "\(label) was good but not great — roughly a quarter of the time was spent leaning forward.",
                        "Set a 30-minute stand-up reminder; short resets are what push this band into the 80s.",
                        64)
        case 60...69:
            return make("score.fair", .score, .encouraging, "minus.circle",
                        "Middling \(score)",
                        "\(label) hovered around the middle. A third of your monitored time was poor posture.",
                        "Raise your screen to eye level — a low screen is the usual cause of scores in this range.",
                        66)
        case 45...59:
            return make("score.poor", .score, .warning, "exclamationmark.circle.fill",
                        "Rough session: \(score)",
                        "Nearly half of \(lowered)'s monitored time was spent slouching.",
                        "Check your chair height and lumbar support before the next session — posture this low is usually a setup problem, not willpower.",
                        72)
        default:
            return make("score.veryPoor", .score, .critical, "exclamationmark.octagon.fill",
                        "Tough one — \(score)",
                        "Most of \(lowered) was spent out of position. Worth a look at the physical setup.",
                        "Try one session sitting somewhere else entirely — if the score jumps, your desk is the problem.",
                        78)
        }
    }

    // MARK: E — Runs of good / bad days

    static func runInsight(_ ctx: InsightContext) -> PostureInsight? {
        let goodRun = ctx.runAtLeast(80)
        let badRun = ctx.runBelow(60)

        if goodRun >= 10 {
            return make("run.great10", .run, .celebration, "sparkles",
                        "\(goodRun) great days without a miss",
                        "Ten-plus consecutive sessions at 80 or above. Your default posture has genuinely changed.",
                        "Nothing to fix here — put the effort into keeping the sessions happening at all.",
                        91)
        }
        if goodRun >= 7 {
            return make("run.great7", .run, .celebration, "sparkles",
                        "\(goodRun) great days in a row",
                        "Every one of your last \(goodRun) sessions scored 80 or better. That's not luck any more.",
                        "Bank it: keep your current setup untouched for another week.",
                        87)
        }
        if goodRun >= 5 {
            return make("run.great5", .run, .positive, "sparkles",
                        "\(goodRun) strong sessions",
                        "Your last \(goodRun) tracked days all scored 80+. Your baseline has genuinely shifted.",
                        "Try adding an hour to your monitored time — good posture is easier to extend than to rebuild.",
                        81)
        }
        if goodRun >= 3 {
            return make("run.great3", .run, .positive, "sparkles",
                        "\(goodRun) good ones back to back",
                        "Three consecutive sessions above 80. The habit is holding.",
                        "Same time, same chair tomorrow — routine is doing the heavy lifting here.",
                        73)
        }
        if badRun >= 5 {
            return make("run.rough5", .run, .critical, "exclamationmark.triangle.fill",
                        "\(badRun) weak sessions in a row",
                        "Your last \(badRun) tracked days all came in under 60. Something in your setup or routine has changed.",
                        "Recalibrate, then run one session with the screen raised and feet flat. Change one variable at a time.",
                        89)
        }
        if badRun >= 3 {
            return make("run.rough3", .run, .warning, "exclamationmark.triangle",
                        "\(badRun) soft days in a row",
                        "Three sessions under 60 back to back. Worth catching before it becomes the new normal.",
                        "Take a two-minute stretch every half hour tomorrow and watch what it does to the score.",
                        79)
        }
        if let spread = ctx.weekSpread, spread >= 35 {
            return make("run.volatile", .run, .neutral, "waveform.path.ecg",
                        "An up-and-down week",
                        "Your scores swung by \(spread) points this week. Something about certain days is very different.",
                        "Compare a good day and a bad day — location, meetings, desk. The gap usually has one obvious cause.",
                        67)
        }
        return nil
    }

    // MARK: F — Trends

    static func trendInsight(_ ctx: InsightContext) -> PostureInsight? {
        if let delta = ctx.weekDelta, let avg = ctx.avg7, ctx.daysTracked7 >= 3 {
            switch delta {
            case 10...:
                return make("trend.upBig", .trend, .celebration, "arrow.up.right",
                            "Up \(delta) points this week",
                            "This week averages \(avg) — a big jump on last week. That's a real change, not noise.",
                            "Write down what changed this week. Whatever it was, it's worth keeping.",
                            85, delta: delta)
            case 5...9:
                return make("trend.upMedium", .trend, .positive, "arrow.up.right",
                            "Trending up \(delta) points",
                            "Your weekly average climbed to \(avg). Steady, visible improvement.",
                            "Hold the routine for one more week before changing anything.",
                            77, delta: delta)
            case 2...4:
                return make("trend.upSmall", .trend, .positive, "arrow.up.right",
                            "Slightly better week",
                            "You're up \(delta) points to an average of \(avg). Small, but heading the right way.",
                            "Add one extra reset break per day — small trends respond well to small changes.",
                            65, delta: delta)
            case -1...1:
                return make("trend.flat", .trend, .neutral, "equal.circle",
                            "Holding steady at \(avg)",
                            "Your weekly average is flat compared to last week. Stable, but not moving.",
                            "To break the plateau, change one thing: screen height, chair, or break frequency.",
                            60)
            case -4...(-2):
                return make("trend.downSmall", .trend, .encouraging, "arrow.down.right",
                            "Slightly down this week",
                            "You dropped \(abs(delta)) points to \(avg). Within normal variation, but worth noticing.",
                            "Check whether your monitored hours went up — longer days usually cost a few points.",
                            63, delta: delta)
            case -9...(-5):
                return make("trend.downMedium", .trend, .warning, "arrow.down.right",
                            "Down \(abs(delta)) points",
                            "This week averages \(avg), noticeably below last week.",
                            "Look at the calendar: heavy meeting days and laptop-only days are the usual culprits.",
                            75, delta: delta)
            default:
                return make("trend.downBig", .trend, .critical, "arrow.down.right",
                            "Sharp drop of \(abs(delta)) points",
                            "Your average fell to \(avg) this week — a big move in the wrong direction.",
                            "Recalibrate the sensor first, then check your desk. A drop this size usually has a physical cause.",
                            83, delta: delta)
            }
        }

        if let delta = ctx.monthDelta, let avg = ctx.avg30 {
            if delta >= 5 {
                return make("trend.monthUp", .trend, .positive, "chart.line.uptrend.xyaxis",
                            "Better month by \(delta) points",
                            "Your 30-day average is \(avg), clearly above the month before.",
                            "You're past the hard part. Keep the routine and let the numbers accumulate.",
                            71, delta: delta)
            }
            if delta <= -5 {
                return make("trend.monthDown", .trend, .warning, "chart.line.downtrend.xyaxis",
                            "Weaker month by \(abs(delta)) points",
                            "Your 30-day average slipped to \(avg) compared with the previous month.",
                            "Pick the single worst week and look at what was different — that's usually where it went.",
                            73, delta: delta)
            }
        }
        return nil
    }

    // MARK: G — Consistency

    static func consistencyInsight(_ ctx: InsightContext) -> PostureInsight? {
        let tracked = ctx.daysTracked30
        guard ctx.totalTrackedDays >= 8 else { return nil }

        switch tracked {
        case 28...30:
            return make("consistency.near30", .consistency, .celebration, "checkmark.seal.fill",
                        "You tracked \(tracked) of 30 days",
                        "Almost complete coverage of the last month. Your stats are as reliable as they get.",
                        "With data this complete, start trusting the weekday patterns — they're statistically real now.",
                        82)
        case 21...27:
            return make("consistency.high", .consistency, .positive, "checkmark.seal.fill",
                        "\(tracked) of the last 30 days",
                        "Strong coverage — about \(Int(Double(tracked) / 30 * 100))% of the month is on record.",
                        "Track one weekend day to see whether weekends are quietly pulling your average down.",
                        69)
        case 14...20:
            return make("consistency.medium", .consistency, .encouraging, "calendar",
                        "Half the month tracked",
                        "\(tracked) of the last 30 days have data. Enough for trends, thin for weekday patterns.",
                        "Aim for four days a week — that's the level where weekday comparisons become meaningful.",
                        61)
        case 7...13:
            return make("consistency.low", .consistency, .encouraging, "calendar.badge.exclamationmark",
                        "\(tracked) days in the last month",
                        "Coverage is patchy, so your average leans on a handful of days.",
                        "Pick two fixed days a week and always track them. Rhythm beats volume early on.",
                        64)
        case 3...6:
            return make("consistency.sparse", .consistency, .warning, "calendar.badge.exclamationmark",
                        "Only \(tracked) days this month",
                        "With this little data, a single rough session moves your whole average.",
                        "Try three days in the same week — one comparable week is worth more than scattered days.",
                        68)
        default:
            return nil
        }
    }

    // MARK: H — Weekday & weekend patterns

    static func patternInsight(_ ctx: InsightContext) -> PostureInsight? {
        guard ctx.totalTrackedDays >= 8 else { return nil }

        if let gap = ctx.weekendGap {
            let difference = gap.weekday - gap.weekend
            if difference >= 8 {
                return make("pattern.weekendWorse", .pattern, .neutral, "calendar",
                            "Weekends cost you \(difference) points",
                            "You average \(gap.weekday) on workdays but \(gap.weekend) at weekends — sofa posture is a real thing.",
                            "Treat one weekend hour like work time: proper chair, screen at eye level.",
                            72)
            }
            if difference <= -8 {
                return make("pattern.weekdayWorse", .pattern, .neutral, "calendar",
                            "Workdays are the weak spot",
                            "Weekends average \(gap.weekend) versus \(gap.weekday) on workdays. Your desk setup is the difference.",
                            "Spend ten minutes adjusting your work chair and monitor — that's where the points are.",
                            74)
            }
        }

        let averages = ctx.weekdayAverages
        guard averages.count >= 4,
              let worst = averages.min(by: { $0.value < $1.value }),
              let best = averages.max(by: { $0.value < $1.value }),
              best.value - worst.value >= 10 else { return nil }

        return make("pattern.weekdaySpread", .pattern, .neutral, "chart.bar.fill",
                    "\(ctx.weekdayName(worst.key))s are your weak day",
                    "\(ctx.weekdayName(worst.key))s average \(worst.value) while \(ctx.weekdayName(best.key))s reach \(best.value).",
                    "Plan your hardest desk work for \(ctx.weekdayName(best.key))s and add extra breaks on \(ctx.weekdayName(worst.key))s.",
                    66)
    }

    // MARK: I — Alerts

    static func alertInsight(_ ctx: InsightContext) -> PostureInsight? {
        guard let recent = ctx.alertsPerHour(daysAgo: 0..<7) else { return nil }
        let previous = ctx.alertsPerHour(daysAgo: 7..<14)

        let load = ctx.alertLoad(daysAgo: 0..<2)
        if load.alerts == 0, load.hours >= 1 {
            return make("alerts.none", .alerts, .celebration, "bell.slash.fill",
                        "Not a single nudge",
                        String(format: "You held position for %.1f hours without one alert.", load.hours),
                        "That's the target state. Keep the same setup and see if it holds over a longer day.",
                        80)
        }

        if let previous = previous, previous >= 1 {
            let change = (recent - previous) / previous
            if change <= -0.3 {
                return make("alerts.down", .alerts, .positive, "bell.slash.fill",
                            "Fewer nudges needed",
                            String(format: "Alerts dropped from %.1f to %.1f per hour — you're correcting before the app has to.", previous, recent),
                            "Consider tightening the sensitivity a notch to keep catching the small slips.",
                            75)
            }
            if change >= 0.3 {
                return make("alerts.up", .alerts, .warning, "bell.badge.fill",
                            "More alerts than usual",
                            String(format: "You're averaging %.1f alerts an hour, up from %.1f last week.", recent, previous),
                            "Check your chair and desk before blaming willpower — a jump like this usually means something moved.",
                            76)
            }
        }

        switch recent {
        case ..<0.5:
            return make("alerts.veryLow", .alerts, .positive, "bell.slash.fill",
                        "Barely any alerts",
                        String(format: "Only %.1f alerts per hour. You're holding position without prompting.", recent),
                        "Tighten the alert thresholds a notch — the current ones almost never fire.",
                        63)
        case 0.5..<2:
            return make("alerts.low", .alerts, .positive, "bell.fill",
                        "Light alert load",
                        String(format: "About %.1f alerts an hour — occasional reminders, nothing constant.", recent),
                        "Keep the settings as they are; this is a healthy nudge rate.",
                        58)
        case 2..<5:
            return make("alerts.medium", .alerts, .encouraging, "bell.fill",
                        String(format: "%.1f alerts every hour", recent),
                        "You're being reminded fairly often, which means posture drifts back quickly after each correction.",
                        "Try a lumbar cushion or raising your seat — sustained position beats repeated correction.",
                        67)
        default:
            return make("alerts.high", .alerts, .warning, "bell.badge.fill",
                        String(format: "%.0f alerts an hour is a lot", recent),
                        "The app is nudging you constantly, so your neutral position is probably out of reach in this setup.",
                        "Recalibrate while sitting the way you actually want to sit — the target may simply be set wrong.",
                        77)
        }
    }

    // MARK: J — Session length

    static func durationInsight(_ ctx: InsightContext) -> PostureInsight? {
        guard let minutes = ctx.avgSessionMinutes, ctx.daysTracked7 >= 2 else { return nil }

        if ctx.isLongestSessionEver, let today = ctx.todayHistory {
            return make("duration.longest", .duration, .neutral, "timer",
                        String(format: "Longest session yet: %.1f h", today.totalMonitoredSeconds / 3600),
                        "Today is the most time you've ever monitored in one day, so the score covers unusually long exposure.",
                        "Compare it with a normal day — if the score held up, your setup is working.",
                        69)
        }

        let thisWeek = ctx.monitoredHours(daysAgo: 0..<7)
        let lastWeek = ctx.monitoredHours(daysAgo: 7..<14)
        if lastWeek >= 2, thisWeek >= 2 {
            let change = (thisWeek - lastWeek) / lastWeek
            if change >= 0.4 {
                return make("duration.up", .duration, .neutral, "clock.arrow.circlepath",
                            "Much longer week at the desk",
                            String(format: "You monitored %.1f hours this week versus %.1f last — %.0f%% more time seated.", thisWeek, lastWeek, change * 100),
                            "Longer days need more breaks, not more willpower. Add one extra stand-up per hour.",
                            65)
            }
            if change <= -0.4 {
                return make("duration.down", .duration, .neutral, "clock.arrow.circlepath",
                            "Lighter week overall",
                            String(format: "Monitored time fell from %.1f to %.1f hours.", lastWeek, thisWeek),
                            "Short weeks flatter the average — check the score per hour rather than the total.",
                            57)
            }
        }

        switch minutes {
        case ..<20:
            return make("duration.veryShort", .duration, .encouraging, "timer",
                        "Very short sessions",
                        String(format: "Your sessions average %.0f minutes, which is too brief to show how posture decays.", minutes),
                        "Aim for at least 45 minutes — posture usually holds fine for the first half hour.",
                        62)
        case 20..<60:
            return make("duration.short", .duration, .neutral, "timer",
                        "Short but useful sessions",
                        String(format: "About %.0f minutes per session on average.", minutes),
                        "Try one long session a week — it's the only way to see the late-afternoon slump.",
                        55)
        case 60..<180:
            return make("duration.medium", .duration, .positive, "timer",
                        String(format: "Around %.1f hours a session", minutes / 60),
                        "A solid monitoring window — long enough to capture how your posture changes over time.",
                        "Compare your first and last hour; the gap tells you when to schedule breaks.",
                        54)
        case 180..<360:
            return make("duration.long", .duration, .neutral, "timer",
                        String(format: "Long days: %.1f hours tracked", minutes / 60),
                        "You're monitoring most of a working day, so your score reflects real conditions.",
                        "At this length, a five-minute walk every 90 minutes is worth more than sitting perfectly.",
                        59)
        default:
            return make("duration.veryLong", .duration, .warning, "timer",
                        String(format: "%.1f hours seated per session", minutes / 60),
                        "That's a very long stretch at the desk. Even perfect posture gets uncomfortable at this duration.",
                        "Break the day in two with a proper walk — total sitting time matters as much as the angle.",
                        68)
        }
    }

    // MARK: K — Milestones

    static func milestoneInsight(_ ctx: InsightContext) -> PostureInsight? {
        let days = ctx.totalTrackedDays
        let hours = ctx.totalUprightHours

        // Day-count milestones (exact hits so they feel like events).
        switch days {
        case 10:
            return make("milestone.days10", .milestone, .celebration, "flag.checkered",
                        "Ten sessions tracked",
                        "Double figures. There's now enough history for the coach to compare weeks properly.",
                        "Open the calendar and find your best day — then work out what made it different.",
                        79)
        case 25:
            return make("milestone.days25", .milestone, .celebration, "flag.checkered",
                        "25 days on record",
                        "A month's worth of sessions. Your averages are stable and meaningful.",
                        "Set a target: beat your 30-day average by 5 points over the next fortnight.",
                        81)
        case 50:
            return make("milestone.days50", .milestone, .celebration, "flag.checkered",
                        "50 sessions",
                        "Fifty tracked days. Very few people stick with anything this long.",
                        "Compare your first ten days with your last ten — that's your actual progress.",
                        85)
        case 100:
            return make("milestone.days100", .milestone, .celebration, "crown.fill",
                        "100 days tracked",
                        "A hundred sessions on record. This is a long-term habit now, not an experiment.",
                        "Time to raise the target — set your goal band to 85 and see how it feels.",
                        90)
        default:
            break
        }

        // Upright-time milestones, announced as thresholds are passed.
        let thresholds: [(Double, String, String)] = [
            (500, "milestone.hours500", "500 hours upright"),
            (250, "milestone.hours250", "250 hours upright"),
            (100, "milestone.hours100", "100 hours upright"),
            (50,  "milestone.hours50",  "50 hours upright"),
            (10,  "milestone.hours10",  "10 hours upright")
        ]
        for (limit, id, title) in thresholds where hours >= limit && hours < limit * 1.15 {
            return make(id, .milestone, .celebration, "clock.badge.checkmark",
                        title,
                        String(format: "You've logged %.0f hours of good posture in total. That's real time your neck didn't spend under load.", hours),
                        "Keep the sessions coming — the next milestone arrives sooner than the last one did.",
                        80)
        }
        return nil
    }

    // MARK: L — Recovery & momentum

    static func recoveryInsight(_ ctx: InsightContext) -> PostureInsight? {
        // Came back after a break.
        if ctx.gapBeforeLatest >= 7, ctx.todayHistory != nil {
            return make("recovery.longComeback", .recovery, .celebration, "arrow.uturn.up",
                        "Welcome back",
                        "You're tracking again after \(ctx.gapBeforeLatest) days away. Restarting is the hardest part and it's done.",
                        "Don't chase your old numbers today — just get two more sessions in this week.",
                        86)
        }
        if ctx.gapBeforeLatest >= 3, ctx.todayHistory != nil {
            return make("recovery.comeback", .recovery, .positive, "arrow.uturn.up",
                        "Back on track",
                        "First session after \(ctx.gapBeforeLatest) quiet days. The gap barely dents your monthly average.",
                        "Track tomorrow as well — back-to-back days rebuild the streak fastest.",
                        78)
        }

        // Bounce back from a bad day.
        if let today = ctx.todayHistory, let yesterday = ctx.yesterdayHistory {
            if today.score >= 80 && yesterday.score < 60 {
                return make("recovery.bounce", .recovery, .celebration, "arrow.up.forward",
                            "Big rebound today",
                            "You went from \(yesterday.score) yesterday to \(today.score) today — a \(today.score - yesterday.score) point swing.",
                            "Make whatever you changed today the default — one good day proves the setup works.",
                            84, delta: today.score - yesterday.score)
            }
            if today.score - yesterday.score >= 15 {
                return make("recovery.better", .recovery, .positive, "arrow.up.forward",
                            "\(today.score - yesterday.score) points better than yesterday",
                            "Today came in at \(today.score) against \(yesterday.score) yesterday.",
                            "Repeat today's conditions tomorrow before the reason gets lost.",
                            70, delta: today.score - yesterday.score)
            }
            if yesterday.score - today.score >= 15 {
                return make("recovery.worse", .recovery, .warning, "arrow.down.forward",
                            "\(yesterday.score - today.score) points below yesterday",
                            "Today scored \(today.score) after \(yesterday.score) yesterday. A drop that size is usually situational.",
                            "Think about what moved — a different room, a laptop instead of a monitor, a long meeting.",
                            71, delta: today.score - yesterday.score)
            }
        }

        // Only worth celebrating when the score being matched is actually good.
        if let today = ctx.todayHistory, let best = ctx.bestDay,
           today.score == best.score, today.score >= 70,
           !ctx.isPersonalBestToday, ctx.totalTrackedDays >= 5 {
            return make("recovery.tiedBest", .recovery, .celebration, "equal.circle.fill",
                        "You matched your best day",
                        "Today's \(today.score) ties the highest score in your history.",
                        "One more point makes it a record — same setup, slightly longer session.",
                        81)
        }

        if ctx.isImprovingRun {
            return make("recovery.climbing", .recovery, .positive, "chart.line.uptrend.xyaxis",
                        "Three days of gains",
                        "Each of your last three sessions beat the one before. That's a genuine upward run.",
                        "Keep the routine identical for one more day and see how far it goes.",
                        74)
        }
        if ctx.isDecliningRun {
            return make("recovery.sliding", .recovery, .warning, "chart.line.downtrend.xyaxis",
                        "Three days of slipping",
                        "Your last three sessions each scored lower than the one before.",
                        "Break the pattern deliberately: shorter session tomorrow, full attention on setup.",
                        76)
        }

        // Standing out from the recent field.
        if let today = ctx.todayHistory, let best = ctx.bestOfRecent, today.score > best, ctx.daysTracked30 >= 5 {
            return make("recovery.bestOfFortnight", .recovery, .positive, "star.circle.fill",
                        "Best day in two weeks",
                        "Today's \(today.score) is higher than anything in the last fortnight.",
                        "Note the time of day — your best sessions usually cluster around the same hours.",
                        72)
        }
        if let today = ctx.todayHistory, let worst = ctx.worstOfRecent, today.score < worst, ctx.daysTracked30 >= 5 {
            return make("recovery.worstOfFortnight", .recovery, .warning, "exclamationmark.circle",
                        "Weakest day in two weeks",
                        "Today's \(today.score) is below every session in the last fortnight.",
                        "One-off days happen. If tomorrow looks similar, recalibrate before drawing conclusions.",
                        73)
        }
        return nil
    }
}
