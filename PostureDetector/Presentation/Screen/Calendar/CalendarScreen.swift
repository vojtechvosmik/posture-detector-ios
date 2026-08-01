//
//  CalendarScreen.swift
//  PostureDetector
//
//  The "Posture Journal": a full-bleed month of score rings, a swipeable deck of
//  bold stat cards, and the week's rhythm as a bar chart. Adaptive light / dark.
//

import SwiftUI

// MARK: - Shared calendar theme (backed by the adaptive Aura palette)

enum CalTheme {
    static let accent = Aura.accent
    static let violet = Aura.violet
    static let green  = Aura.green
    static let orange = Aura.orange
    static let coral  = Aura.coral
    static func scoreColor(_ score: Int) -> Color { Aura.scoreColor(score) }
}

typealias CalAurora = AuraBackground

extension View {
    func calCard(_ padding: CGFloat = 18) -> some View { auraCard(padding: padding, cornerRadius: 22) }
}

// Wrapper to make Date identifiable for sheet presentation
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct CalendarScreen: View {
    @ObservedObject private var dataStore = PostureDataStore.shared
    @State private var selectedDate: IdentifiableDate?
    @State private var currentMonth = Date()
    @State private var showingCoach = false

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(showsIndicators: false) {
            if hasAnyData {
                VStack(alignment: .leading, spacing: 26) {
                    calendarSection
                    coachSection
                    statDeck
                    dayMix
                }
                .padding(.top, 4)
                .padding(.bottom, 34)
            } else {
                emptyState
                    .padding(.top, 30)
                    .padding(.horizontal, 18)
            }
        }
        .background(CalAurora())
        // No nav bar: the month header is the title, so the grid sits right at the top.
        .navigationBarHidden(true)
        .sheet(item: $selectedDate) { item in
            DayDetailView(date: item.date, history: dataStore.getHistory(for: item.date))
        }
    }

    // MARK: - Month calendar (edge to edge)

    private var calendarSection: some View {
        VStack(spacing: 18) {
            HStack {
                monthNavButton("chevron.left") { changeMonth(-1) }
                Spacer()
                VStack(spacing: 1) {
                    Text(monthTitle)
                        .font(.system(size: 21, weight: .bold)).foregroundColor(.primary)
                    Text(yearTitle)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        .tracking(1.2)
                }
                .id(monthTitle).transition(.opacity)
                Spacer()
                monthNavButton("chevron.right", disabled: !canGoNext) { changeMonth(1) }
            }
            .padding(.horizontal, 20)

            CalendarGridView(
                month: currentMonth,
                history: dataStore.allHistory,
                onDayTapped: { date in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedDate = IdentifiableDate(date: date)
                }
            )
            .padding(.horizontal, 10)
        }
        // A soft bloom in the month's own colour keeps the edge-to-edge grid from
        // feeling unanchored without boxing it into a card.
        .background(
            Circle()
                .fill(Aura.scoreColor(monthAverage))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .opacity(0.16)
                .offset(y: -30)
                .allowsHitTesting(false),
            alignment: .top
        )
    }

    private func monthNavButton(_ icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(disabled ? .secondary.opacity(0.4) : .primary)
                .frame(width: 40, height: 40)
                .background(Aura.softFill, in: Circle())
                .overlay(Circle().stroke(Aura.hairline, lineWidth: 1))
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: currentMonth)
    }

    private var yearTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: currentMonth)
    }

    /// Don't let the user page into future months.
    private var canGoNext: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return false }
        return calendar.compare(next, to: Date(), toGranularity: .month) != .orderedDescending
    }

    private func changeMonth(_ delta: Int) {
        guard let m = calendar.date(byAdding: .month, value: delta, to: currentMonth) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { currentMonth = m }
    }

    // MARK: - Coach (rule-based insights, ready to be swapped for a model)

    @ViewBuilder private var coachSection: some View {
        if let report = PostureInsightEngine.report(for: dataStore.allHistory,
                                                     samples: PostureSampleStore.shared.days) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showingCoach = true
            } label: {
                CoachPanel(report: report)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .sheet(isPresented: $showingCoach) {
                CoachDetailSheet(report: report)
            }
        }
    }

    // MARK: - Stat deck (swipe through the highlights)

    private var statDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .font(.system(size: 20, weight: .bold)).foregroundColor(.primary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(deckCards) { card in
                        StatDeckCard(card: card)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
    }

    private var deckCards: [DeckCard] {
        var cards: [DeckCard] = [
            DeckCard(icon: "waveform.path.ecg", color: Aura.scoreColor(avg30),
                     value: "\(avg30)", unit: nil,
                     label: "30-day average", detail: trendText),
            DeckCard(icon: "checkmark.seal.fill", color: Aura.accent,
                     value: "\(consistency)", unit: "%",
                     label: "Consistency", detail: "\(daysTracked30) of the last 30 days"),
            DeckCard(icon: "flame.fill", color: Aura.orange,
                     value: "\(streak)", unit: streak == 1 ? "day" : "days",
                     label: "Current streak",
                     detail: longestStreak > streak ? "Best run \(longestStreak) days" : "Your best run yet"),
            DeckCard(icon: "clock.fill", color: Aura.violet,
                     value: uprightValue, unit: uprightUnit,
                     label: "Upright time", detail: "Good posture, last 30 days")
        ]

        if let best = bestDay {
            cards.append(DeckCard(icon: "trophy.fill", color: Aura.green,
                                  value: "\(best.score)", unit: nil,
                                  label: "Personal best", detail: dayLabel(best.date)))
        }
        if alertsPerDay > 0 {
            cards.append(DeckCard(icon: "bell.badge.fill", color: Aura.coral,
                                  value: String(format: "%.1f", alertsPerDay), unit: "/day",
                                  label: "Slouch alerts", detail: "Average while tracking"))
        }
        return cards
    }

    // MARK: - Day mix (how the last 30 days landed)

    private var dayMix: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 30 days")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(.primary)
                Spacer(minLength: 8)
                Text(mixHeadline)
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                DayMixDonut(segments: mixSegments,
                            centerValue: "\(daysTracked30)",
                            centerLabel: "of 30 days")
                    .frame(width: 128, height: 128)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(mixSegments) { segment in
                        HStack(spacing: 9) {
                            Circle().fill(segment.color)
                                .overlay(Circle().stroke(Aura.hairline, lineWidth: 1))
                                .frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(segment.label)
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                                Text(segment.range)
                                    .font(.system(size: 10.5)).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 6)
                            Text("\(segment.count)")
                                .font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .calCard()
        .padding(.horizontal, 18)
    }

    /// Counts of great / good / rough / untracked days over the last 30.
    private var mixSegments: [MixSegment] {
        let scores = trackedScores(daysAgo: 0..<30)
        let great = scores.filter { $0 >= 80 }.count
        let good = scores.filter { $0 >= 60 && $0 < 80 }.count
        let rough = scores.filter { $0 < 60 }.count
        return [
            MixSegment(color: Aura.green,  label: "Great",      range: "80 and up", count: great),
            MixSegment(color: Aura.orange, label: "Good",       range: "60 – 79",   count: good),
            MixSegment(color: Aura.coral,  label: "Needs work", range: "under 60",  count: rough),
            MixSegment(color: Aura.softFill, label: "Untracked", range: "no session", count: 30 - scores.count)
        ]
    }

    private var mixHeadline: String {
        let segments = mixSegments.dropLast()          // ignore untracked
        guard let top = segments.max(by: { $0.count < $1.count }), top.count > 0 else {
            return "No sessions yet"
        }
        return "Mostly \(top.label.lowercased()) days"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(CalTheme.accent).frame(width: 100, height: 100).blur(radius: 34).opacity(0.4)
                Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 50)).foregroundColor(.primary)
            }
            Text("Your journal is empty").font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
            Text("Track your posture and watch this fill with a glowing history of your progress.")
                .font(.system(size: 15)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 12) {
                emptyStep("1.circle.fill", "Connect your AirPods")
                emptyStep("2.circle.fill", "Open the Overview tab")
                emptyStep("3.circle.fill", "Press Start to begin")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .calCard()
            .padding(.top, 6)
        }
        .padding(.horizontal, 6)
    }

    private func emptyStep(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(CalTheme.accent)
            Text(text).font(.system(size: 14)).foregroundColor(.secondary)
        }
    }

    // MARK: - Data

    private var hasAnyData: Bool {
        dataStore.allHistory.contains { $0.totalMonitoredSeconds > 0 }
    }

    private var trackedDays: [PostureHistory] {
        dataStore.allHistory.filter { $0.totalMonitoredSeconds > 0 }
    }

    /// Scores of tracked days within a days-ago window (0 = today).
    private func trackedScores(daysAgo range: Range<Int>) -> [Int] {
        let today = calendar.startOfDay(for: Date())
        return range.compactMap { off -> Int? in
            guard let d = calendar.date(byAdding: .day, value: -off, to: today) else { return nil }
            let h = dataStore.getHistory(for: d)
            return (h?.totalMonitoredSeconds ?? 0) > 0 ? h?.score : nil
        }
    }

    private var avg30: Int {
        let s = trackedScores(daysAgo: 0..<30)
        return s.isEmpty ? 0 : s.reduce(0, +) / s.count
    }

    /// Average of the month currently on screen — drives the section's bloom colour.
    private var monthAverage: Int {
        let scores = dataStore.allHistory
            .filter { $0.totalMonitoredSeconds > 0 && calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month) }
            .map { $0.score }
        return scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
    }

    /// This week's average minus the previous week's (0 when either is empty).
    private var trendDelta7: Int {
        let cur = trackedScores(daysAgo: 0..<7)
        let prev = trackedScores(daysAgo: 7..<14)
        guard !cur.isEmpty, !prev.isEmpty else { return 0 }
        return cur.reduce(0, +) / cur.count - prev.reduce(0, +) / prev.count
    }

    private var trendText: String {
        if trendDelta7 > 0 { return "Up \(trendDelta7) pts this week" }
        if trendDelta7 < 0 { return "Down \(abs(trendDelta7)) pts this week" }
        return "Holding steady"
    }

    /// Consecutive tracked days ending today.
    private var streak: Int {
        var s = 0
        var d = Date()
        while let h = dataStore.getHistory(for: d), h.totalMonitoredSeconds > 0 {
            s += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: d) else { break }
            d = prev
        }
        return s
    }

    /// Longest run of consecutive tracked days anywhere in the history.
    private var longestStreak: Int {
        let days = Set(trackedDays.map { calendar.startOfDay(for: $0.date) })
        var best = 0
        for day in days {
            // Only measure from the first day of a run.
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day), !days.contains(prev) else { continue }
            var run = 0
            var cursor = day
            while days.contains(cursor) {
                run += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            best = max(best, run)
        }
        return best
    }

    private var daysTracked30: Int { trackedScores(daysAgo: 0..<30).count }
    private var consistency: Int { Int((Double(daysTracked30) / 30 * 100).rounded()) }

    private var bestDay: PostureHistory? { trackedDays.max(by: { $0.score < $1.score }) }

    /// Total good-posture time over the last 30 days, split into value + unit.
    private var uprightSeconds: TimeInterval {
        let today = calendar.startOfDay(for: Date())
        return (0..<30).reduce(0.0) { acc, off in
            guard let d = calendar.date(byAdding: .day, value: -off, to: today) else { return acc }
            return acc + (dataStore.getHistory(for: d)?.goodPostureSeconds ?? 0)
        }
    }

    private var uprightValue: String {
        let hours = uprightSeconds / 3600
        if hours >= 10 { return "\(Int(hours))" }
        if hours >= 1 { return String(format: "%.1f", hours) }
        return "\(Int(uprightSeconds / 60))"
    }

    private var uprightUnit: String { uprightSeconds / 3600 >= 1 ? "h" : "m" }

    private var alertsPerDay: Double {
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = trackedDays.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return Double(recent.reduce(0) { $0 + $1.alertCount }) / Double(recent.count)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}

// MARK: - Coach cards

extension InsightTone {
    /// The palette each tone speaks in.
    var color: Color {
        switch self {
        case .celebration: return Aura.violet
        case .positive:    return Aura.green
        case .encouraging: return Aura.accent
        case .neutral:     return Aura.accent
        case .warning:     return Aura.orange
        case .critical:    return Aura.coral
        }
    }
}

// MARK: - Stat deck

struct DeckCard: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let value: String
    let unit: String?
    let label: String
    let detail: String
}

/// One card in the highlight deck: a compact gradient tile with a glyph
/// watermark behind the number.
private struct StatDeckCard: View {
    let card: DeckCard

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [card.color, card.color.opacity(0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            Image(systemName: card.icon)
                .font(.system(size: 58, weight: .semibold))
                .foregroundColor(.white.opacity(0.16))
                .rotationEffect(.degrees(-12))
                .offset(x: 74, y: 48)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: card.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Text(card.label.uppercased())
                        .font(.system(size: 9.5, weight: .heavy)).tracking(0.5)
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(card.value)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundColor(.white)
                    if let unit = card.unit {
                        Text(unit)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(card.detail)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
        }
        .frame(width: 142, height: 116)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: card.color.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - Day mix donut

struct MixSegment: Identifiable {
    var id: String { label }
    let color: Color
    let label: String
    let range: String
    let count: Int
}

/// A segmented ring showing how the last 30 days split across score bands.
struct DayMixDonut: View {
    let segments: [MixSegment]
    let centerValue: String
    let centerLabel: String

    @State private var drawn = false

    private let lineWidth: CGFloat = 15
    /// Small visual gap between neighbouring segments.
    private let gap: CGFloat = 0.006

    private var total: Int { max(segments.reduce(0) { $0 + $1.count }, 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Aura.softFill, lineWidth: lineWidth)

            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                let bounds = range(at: index)
                Circle()
                    .trim(from: bounds.start, to: drawn ? bounds.end : bounds.start)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.55).delay(Double(index) * 0.09), value: drawn)
            }

            VStack(spacing: 0) {
                Text(centerValue)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                Text(centerLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear { drawn = true }
    }

    /// Start / end of a segment's arc, leaving a hairline gap after it.
    private func range(at index: Int) -> (start: CGFloat, end: CGFloat) {
        let before = segments.prefix(index).reduce(0) { $0 + $1.count }
        let start = CGFloat(before) / CGFloat(total)
        let raw = start + CGFloat(segments[index].count) / CGFloat(total)
        return (start, max(start, raw - (raw < 1 ? gap : 0)))
    }
}
