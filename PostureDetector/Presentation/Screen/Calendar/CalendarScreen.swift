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
                    records
                    scoreMix
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

    // MARK: - Records

    /// Personal bests rather than another set of averages — the coach panel
    /// above already carries the running numbers.
    private var records: some View {
        CalSection("RECORDS") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    RecordTile(icon: "trophy.fill",
                               value: bestDay.map { "\($0.score)" } ?? "–",
                               label: "Best day",
                               caption: bestDay.map { dayLabel($0.date) } ?? "No sessions yet",
                               tint: bestDay.map { Aura.scoreColor($0.score) } ?? .secondary)
                    RecordTile(icon: "flame.fill",
                               value: longestStreak > 0 ? "\(longestStreak)" : "–",
                               label: longestStreak == 1 ? "Day in a row" : "Days in a row",
                               caption: streak == longestStreak && streak > 0 ? "Running now" : "Longest run",
                               tint: Aura.orange)
                }
                HStack(spacing: 10) {
                    RecordTile(icon: "clock.fill",
                               value: longestUprightDay.map { uprightText($0.goodPostureSeconds) } ?? "–",
                               label: "Most upright",
                               caption: longestUprightDay.map { dayLabel($0.date) } ?? "In one day",
                               tint: Aura.green)
                    RecordTile(icon: "checkmark.seal.fill",
                               value: "\(trackedDays.count)",
                               label: trackedDays.count == 1 ? "Session" : "Sessions",
                               caption: "Since you started",
                               tint: Aura.accent)
                }
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Score mix

    /// How the last thirty days split across the score bands, as one bar.
    private var scoreMix: some View {
        CalSection("SCORE MIX") {
            VStack(alignment: .leading, spacing: 14) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(mixBands) { band in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(band.color)
                                .frame(width: max(band.count == 0 ? 0 : 4,
                                                  (geo.size.width - 6) * CGFloat(band.count) / 30))
                        }
                    }
                }
                .frame(height: 14)

                // Legend, wrapped into two rows so the labels stay readable.
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        ForEach(mixBands.prefix(2)) { band in
                            mixLegend(band)
                        }
                    }
                    HStack(spacing: 0) {
                        ForEach(mixBands.suffix(2)) { band in
                            mixLegend(band)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .auraCard(padding: 0, cornerRadius: 18)
        }
        .padding(.horizontal, 18)
    }

    private func mixLegend(_ band: MixBand) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(band.color)
                .frame(width: 9, height: 9)
            Text(band.label)
                .font(.system(size: 12.5)).foregroundColor(.secondary)
            Text("\(band.count)")
                .font(.system(size: 12.5, weight: .bold)).foregroundColor(.primary)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mixBands: [MixBand] {
        let scores = trackedScores(daysAgo: 0..<30)
        return [
            MixBand(label: "Great", color: Aura.green, count: scores.filter { $0 >= 80 }.count),
            MixBand(label: "Good", color: Aura.orange, count: scores.filter { $0 >= 60 && $0 < 80 }.count),
            MixBand(label: "Needs work", color: Aura.coral, count: scores.filter { $0 < 60 }.count),
            MixBand(label: "Untracked", color: Aura.softFill, count: 30 - scores.count)
        ]
    }

    private var longestUprightDay: PostureHistory? {
        trackedDays.max(by: { $0.goodPostureSeconds < $1.goodPostureSeconds })
    }

    private func uprightText(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        if hours >= 10 { return "\(Int(hours))h" }
        if hours >= 1 { return String(format: "%.1fh", hours) }
        return "\(Int(seconds / 60))m"
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

// MARK: - Building blocks

/// Section label + content, matching the coach sections.
private struct CalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9.5, weight: .heavy)).tracking(1.2)
                .foregroundColor(.secondary)
            content
        }
    }
}

/// One personal best: glyph, number, what it is, and when it happened.
private struct RecordTile: View {
    let icon: String
    let value: String
    let label: String
    let caption: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 24, weight: .bold)).foregroundColor(.primary)
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 12.5, weight: .medium)).foregroundColor(.primary)
                Text(caption)
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .auraCard(padding: 0, cornerRadius: 16)
    }
}

struct MixBand: Identifiable {
    var id: String { label }
    let label: String
    let color: Color
    let count: Int
}
