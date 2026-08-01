//
//  PosturePatternAnalyzer.swift
//  PostureDetector
//
//  Turns intraday samples into claims that survive scrutiny.
//
//  The analysis itself is easy; the discipline is in what it refuses to say.
//  Three rules run through everything here:
//
//    1. Paired comparisons only. "Afternoons are worse" must be measured
//       within days that contain both halves, otherwise it can just mean
//       "long days are worse" — and long days happen to include afternoons.
//    2. Minimum sample. A pattern needs enough days and enough monitored
//       minutes inside each side of the comparison before it is a pattern.
//    3. Effect size and stability. The difference has to clear an absolute
//       threshold and exceed the standard error of the per-day differences.
//
//  When a check fails the feature is nil, and the coach simply says nothing
//  about it. Silence is the correct output for insufficient data.
//

import Foundation

// MARK: - Results

/// A within-day comparison of two windows.
struct PairedComparison {
    let aScore: Int
    let bScore: Int
    let delta: Int          // a − b
    let days: Int
    let standardError: Double

    var isSolid: Bool {
        days >= 5 && abs(Double(delta)) >= 8 && abs(Double(delta)) > standardError
    }
}

/// Score for one clock-hour across the whole window.
struct HourStat {
    let hour: Int
    let score: Int
    let minutes: Double
    let days: Int
}

struct ModeStat {
    let mode: PostureMode
    let score: Int
    let minutes: Double
    let days: Int
}

struct DecayStat {
    let bucket: Int
    let label: String
    let score: Int
    let minutes: Double
}

struct EpisodeStats {
    let perDay: Double
    let medianMinutes: Double
    let longestMinutes: Double
    let days: Int
    /// Share of bad time spent in episodes of ten minutes or more.
    let longShare: Double
}

struct AlertResponseStats {
    let medianSeconds: Double
    let count: Int
    /// Median in the previous fortnight, when there is enough to compare.
    let previousMedianSeconds: Double?
}

/// Everything the deep rules can draw on. Any field may be nil.
struct PosturePatterns {
    var hours: [HourStat] = []
    var worstBlock: (start: Int, end: Int, comparison: PairedComparison)?
    var bestBlock: (start: Int, end: Int, score: Int)?
    var afternoonDip: PairedComparison?
    var decay: [DecayStat] = []
    var decayDrop: (holdsMinutes: Int, early: Int, late: Int)?
    var modes: [ModeStat] = []
    var modeGap: (weakest: ModeStat, rest: ModeStat)?
    var leanForwardShare: Double?
    var episodes: EpisodeStats?
    var alerts: AlertResponseStats?
    var exerciseEffect: PairedComparison?
    var coveredDays: Int = 0
    var monitoredHours: Double = 0
}

/// How close the intraday data is to supporting pattern analysis.
struct DeepReadiness {
    let days: Int
    let target: Int

    var isReady: Bool { days >= target }
    var fraction: Double { min(1, Double(days) / Double(max(target, 1))) }
    var remaining: Int { max(0, target - days) }
}

// MARK: - Analyzer

enum PosturePatternAnalyzer {

    /// Days with a real session needed before time-of-day and context patterns
    /// can be claimed. Calendar days are irrelevant — only tracked ones count,
    /// so nobody has to track a weekend to get here.
    static let deepDayTarget = 14

    /// A day counts once it holds at least this much monitored time.
    private static let qualifyingMinutes: Double = 20

    static func readiness(from days: [PostureDaySamples],
                          now: Date = Date(),
                          window: Int = 42) -> DeepReadiness {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -window, to: now) ?? now
        let qualifying = days.filter {
            $0.date >= cutoff && $0.totals.total >= qualifyingMinutes * 60
        }
        return DeepReadiness(days: qualifying.count, target: deepDayTarget)
    }

    /// Minimum monitored minutes inside a window before it counts for that day.
    private static let minimumWindowMinutes: Double = 20

    static func patterns(from days: [PostureDaySamples],
                         now: Date = Date(),
                         window: Int = 42) -> PosturePatterns {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -window, to: now) ?? now
        let recent = days.filter { $0.date >= cutoff && !$0.slots.isEmpty }

        var result = PosturePatterns()
        guard !recent.isEmpty else { return result }

        result.coveredDays = recent.count
        result.monitoredHours = recent.reduce(0.0) { $0 + $1.totals.total } / 3600
        result.hours = hourStats(recent)
        result.modes = modeStats(recent)
        result.decay = decayStats(recent)
        result.episodes = episodeStats(recent)
        result.alerts = alertStats(recent, now: now, calendar: calendar)
        result.leanForwardShare = leanShare(recent)

        result.worstBlock = worstBlock(recent, hours: result.hours)
        result.bestBlock = bestBlock(result.hours)
        result.afternoonDip = compare(recent, a: 13..<17, b: 8..<12)
        result.decayDrop = decayDrop(result.decay)
        result.modeGap = modeGap(result.modes)
        result.exerciseEffect = exerciseEffect(recent, calendar: calendar)

        return result
    }

    // MARK: Clock hours

    private static func hourStats(_ days: [PostureDaySamples]) -> [HourStat] {
        var totals: [Int: (PostureTotals, Set<String>)] = [:]
        for day in days {
            for slot in day.slots {
                var entry = totals[slot.hour] ?? (PostureTotals(), [])
                entry.0.add(slot.totals)
                entry.1.insert(day.id)
                totals[slot.hour] = entry
            }
        }
        return totals.compactMap { hour, entry in
            guard let score = entry.0.score, entry.0.total >= 600 else { return nil }
            return HourStat(hour: hour, score: score,
                            minutes: entry.0.total / 60, days: entry.1.count)
        }
        .sorted { $0.hour < $1.hour }
    }

    /// The weakest two-hour window, compared against the rest of the same days.
    private static func worstBlock(_ days: [PostureDaySamples],
                                   hours: [HourStat]) -> (start: Int, end: Int, comparison: PairedComparison)? {
        let candidates = hours.filter { $0.days >= 5 }
        guard candidates.count >= 4 else { return nil }

        var worst: (start: Int, comparison: PairedComparison)?
        for stat in candidates {
            let start = stat.hour
            let end = start + 2
            guard candidates.contains(where: { $0.hour == start + 1 }) else { continue }
            guard let comparison = compareBlockAgainstRest(days, block: start..<end) else { continue }
            if worst == nil || comparison.delta < worst!.comparison.delta {
                worst = (start, comparison)
            }
        }
        guard let found = worst, found.comparison.isSolid, found.comparison.delta < 0 else { return nil }
        return (found.start, found.start + 2, found.comparison)
    }

    private static func bestBlock(_ hours: [HourStat]) -> (start: Int, end: Int, score: Int)? {
        let candidates = hours.filter { $0.days >= 5 }
        guard candidates.count >= 4 else { return nil }
        var best: (start: Int, score: Int)?
        for stat in candidates {
            guard let next = candidates.first(where: { $0.hour == stat.hour + 1 }) else { continue }
            let score = (stat.score + next.score) / 2
            if best == nil || score > best!.score { best = (stat.hour, score) }
        }
        guard let found = best else { return nil }
        return (found.start, found.start + 2, found.score)
    }

    /// Block versus everything else, measured inside each day and then averaged.
    private static func compareBlockAgainstRest(_ days: [PostureDaySamples],
                                                block: Range<Int>) -> PairedComparison? {
        var deltas: [Double] = []
        var aTotals = PostureTotals(), bTotals = PostureTotals()

        for day in days {
            let inside = day.totals(hours: block)
            let outside = day.slots.filter { !block.contains($0.hour) }
                .reduce(into: PostureTotals()) { $0.add($1.totals) }
            guard inside.total >= minimumWindowMinutes * 60,
                  outside.total >= minimumWindowMinutes * 60,
                  let a = inside.score, let b = outside.score else { continue }
            deltas.append(Double(a - b))
            aTotals.add(inside)
            bTotals.add(outside)
        }
        return comparison(deltas: deltas, a: aTotals, b: bTotals)
    }

    /// Two named windows, compared only on days that contain both.
    private static func compare(_ days: [PostureDaySamples],
                                a: Range<Int>, b: Range<Int>) -> PairedComparison? {
        var deltas: [Double] = []
        var aTotals = PostureTotals(), bTotals = PostureTotals()

        for day in days {
            let first = day.totals(hours: a)
            let second = day.totals(hours: b)
            guard first.total >= minimumWindowMinutes * 60,
                  second.total >= minimumWindowMinutes * 60,
                  let x = first.score, let y = second.score else { continue }
            deltas.append(Double(x - y))
            aTotals.add(first)
            bTotals.add(second)
        }
        return comparison(deltas: deltas, a: aTotals, b: bTotals)
    }

    private static func comparison(deltas: [Double],
                                   a: PostureTotals, b: PostureTotals) -> PairedComparison? {
        guard deltas.count >= 5, let aScore = a.score, let bScore = b.score else { return nil }
        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(max(deltas.count - 1, 1))
        let standardError = sqrt(variance) / sqrt(Double(deltas.count))
        return PairedComparison(aScore: aScore, bScore: bScore,
                                delta: Int(mean.rounded()),
                                days: deltas.count,
                                standardError: standardError)
    }

    // MARK: Session length

    private static func decayStats(_ days: [PostureDaySamples]) -> [DecayStat] {
        var totals: [Int: PostureTotals] = [:]
        for day in days {
            for bucket in day.decay {
                var entry = totals[bucket.bucket] ?? PostureTotals()
                entry.add(bucket.totals)
                totals[bucket.bucket] = entry
            }
        }
        return totals.compactMap { bucket, entry in
            guard let score = entry.score, entry.total >= 3600 else { return nil }
            let label = PostureDecayBucket.bounds.indices.contains(bucket)
                ? PostureDecayBucket.bounds[bucket].label : ""
            return DecayStat(bucket: bucket, label: label, score: score, minutes: entry.total / 60)
        }
        .sorted { $0.bucket < $1.bucket }
    }

    /// Where posture starts falling off inside a long session.
    private static func decayDrop(_ decay: [DecayStat]) -> (holdsMinutes: Int, early: Int, late: Int)? {
        guard let first = decay.first(where: { $0.bucket == 0 }) else { return nil }
        for stat in decay where stat.bucket > 0 {
            if first.score - stat.score >= 8 {
                let boundary = Int(PostureDecayBucket.bounds[stat.bucket].lower)
                return (boundary, first.score, stat.score)
            }
        }
        return nil
    }

    // MARK: Context

    private static func modeStats(_ days: [PostureDaySamples]) -> [ModeStat] {
        var totals: [Int: (PostureTotals, Set<String>)] = [:]
        for day in days {
            for slot in day.slots {
                var entry = totals[slot.mode] ?? (PostureTotals(), [])
                entry.0.add(slot.totals)
                entry.1.insert(day.id)
                totals[slot.mode] = entry
            }
        }
        return totals.compactMap { raw, entry in
            guard let mode = PostureMode(rawValue: raw),
                  let score = entry.0.score,
                  entry.0.total >= 3600 else { return nil }
            return ModeStat(mode: mode, score: score,
                            minutes: entry.0.total / 60, days: entry.1.count)
        }
        .sorted { $0.minutes > $1.minutes }
    }

    /// The weakest context against everything else, when both are well covered.
    private static func modeGap(_ modes: [ModeStat]) -> (weakest: ModeStat, rest: ModeStat)? {
        guard modes.count >= 2 else { return nil }
        let usable = modes.filter { $0.days >= 4 && $0.minutes >= 120 }
        guard usable.count >= 2, let weakest = usable.min(by: { $0.score < $1.score }) else { return nil }

        let others = usable.filter { $0.mode != weakest.mode }
        let minutes = others.reduce(0.0) { $0 + $1.minutes }
        guard minutes > 0 else { return nil }
        let weighted = others.reduce(0.0) { $0 + Double($1.score) * $1.minutes } / minutes
        let rest = ModeStat(mode: others[0].mode, score: Int(weighted.rounded()),
                            minutes: minutes, days: others.map { $0.days }.max() ?? 0)
        guard rest.score - weakest.score >= 8 else { return nil }
        return (weakest, rest)
    }

    /// Share of bad time spent leaning forward rather than sideways.
    private static func leanShare(_ days: [PostureDaySamples]) -> Double? {
        let totals = days.reduce(into: PostureTotals()) { $0.add($1.totals) }
        guard totals.bad >= 1800 else { return nil }
        return totals.forward / totals.bad
    }

    // MARK: Episodes & alerts

    private static func episodeStats(_ days: [PostureDaySamples]) -> EpisodeStats? {
        let withEpisodes = days.filter { !$0.episodes.isEmpty }
        guard withEpisodes.count >= 4 else { return nil }

        let all = withEpisodes.flatMap { $0.episodes }
        guard all.count >= 8 else { return nil }

        let durations = all.map { $0.duration }.sorted()
        let median = durations[durations.count / 2] / 60
        let longest = (durations.last ?? 0) / 60
        let longTime = all.filter { $0.duration >= 600 }.reduce(0.0) { $0 + $1.duration }
        let allTime = all.reduce(0.0) { $0 + $1.duration }

        return EpisodeStats(perDay: Double(all.count) / Double(withEpisodes.count),
                            medianMinutes: median,
                            longestMinutes: longest,
                            days: withEpisodes.count,
                            longShare: allTime > 0 ? longTime / allTime : 0)
    }

    private static func alertStats(_ days: [PostureDaySamples],
                                   now: Date, calendar: Calendar) -> AlertResponseStats? {
        let recentCutoff = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let previousCutoff = calendar.date(byAdding: .day, value: -28, to: now) ?? now

        func medianRecovery(_ episodes: [SlouchEpisode]) -> Double? {
            let values = episodes.compactMap { $0.recoverySeconds }.sorted()
            guard values.count >= 8 else { return nil }
            return values[values.count / 2]
        }

        let recentEpisodes = days.filter { $0.date >= recentCutoff }.flatMap { $0.episodes }
        guard let median = medianRecovery(recentEpisodes) else { return nil }

        let previousEpisodes = days.filter { $0.date >= previousCutoff && $0.date < recentCutoff }
            .flatMap { $0.episodes }

        return AlertResponseStats(medianSeconds: median,
                                  count: recentEpisodes.compactMap { $0.recoverySeconds }.count,
                                  previousMedianSeconds: medianRecovery(previousEpisodes))
    }

    // MARK: Exercise

    /// Posture in the three hours after a guided exercise, against the same
    /// hours on days without one.
    private static func exerciseEffect(_ days: [PostureDaySamples],
                                       calendar: Calendar) -> PairedComparison? {
        let exerciseDays = days.filter { !$0.exercises.isEmpty }
        let plainDays = days.filter { $0.exercises.isEmpty }
        guard exerciseDays.count >= 4, plainDays.count >= 4 else { return nil }

        var afterTotals = PostureTotals()
        var hoursUsed: Set<Int> = []
        for day in exerciseDays {
            for exercise in day.exercises {
                let hour = calendar.component(.hour, from: exercise)
                let window = hour..<min(24, hour + 3)
                let totals = day.totals(hours: window)
                guard totals.total >= minimumWindowMinutes * 60 else { continue }
                afterTotals.add(totals)
                window.forEach { hoursUsed.insert($0) }
            }
        }
        guard afterTotals.total >= 3600, !hoursUsed.isEmpty, let after = afterTotals.score else { return nil }

        var baselineTotals = PostureTotals()
        var deltas: [Double] = []
        for day in plainDays {
            let totals = day.slots.filter { hoursUsed.contains($0.hour) }
                .reduce(into: PostureTotals()) { $0.add($1.totals) }
            guard totals.total >= minimumWindowMinutes * 60, let score = totals.score else { continue }
            baselineTotals.add(totals)
            deltas.append(Double(after - score))
        }
        guard deltas.count >= 4, let baseline = baselineTotals.score else { return nil }

        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(max(deltas.count - 1, 1))
        let standardError = sqrt(variance) / sqrt(Double(deltas.count))
        let result = PairedComparison(aScore: after, bScore: baseline,
                                      delta: after - baseline,
                                      days: deltas.count,
                                      standardError: standardError)
        return result.isSolid ? result : nil
    }
}
