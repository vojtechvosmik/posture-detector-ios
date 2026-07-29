//
//  CalendarScreen.swift
//  PostureDetector
//
//  The "Posture Journal": a premium, data-forward history view — a hero 30-day
//  average with a flowing score wave, a glowing 13-week consistency heatmap, and
//  highlight stats. Adaptive light / dark aurora throughout.
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
    @State private var appeared = false
    @State private var currentMonth = Date()

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(showsIndicators: false) {
            if hasAnyData {
                VStack(spacing: 16) {
                    heroCard
                    heatmapCard
                    monthCalendarCard
                    highlightsRow
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 28)
            } else {
                emptyState
                    .padding(.top, 30)
                    .padding(.horizontal, 18)
            }
        }
        .background(CalAurora())
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDate) { item in
            DayDetailView(date: item.date, history: dataStore.getHistory(for: item.date))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        let avg = avg30
        let color = Aura.scoreColor(avg)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAST 30 DAYS")
                        .font(.system(size: 11, weight: .heavy)).tracking(0.8).foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(avg)")
                            .font(.system(size: 56, weight: .heavy))
                            .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.65)],
                                                            startPoint: .top, endPoint: .bottom))
                        Text("avg").font(.system(size: 17, weight: .semibold)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                trendChip
            }

            ScoreWave(scores: waveScores, tint: color)
                .frame(height: 74)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.9), value: appeared)

            HStack(spacing: 8) {
                Image(systemName: insightIcon).font(.system(size: 13, weight: .bold)).foregroundColor(color)
                Text(insight).font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .calCard()
    }

    @ViewBuilder private var trendChip: some View {
        let d = trendDelta
        if d != 0 {
            let up = d > 0
            HStack(spacing: 4) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.system(size: 11, weight: .heavy))
                Text("\(abs(d)) pts").font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(up ? Aura.green : Aura.coral)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background((up ? Aura.green : Aura.coral).opacity(0.14), in: Capsule())
        }
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        let weeks = heatmapWeeks()
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Consistency").font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                Spacer()
                Text("\(daysTracked) days tracked").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
            }

            PostureHeatmap(weeks: weeks) { date in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedDate = IdentifiableDate(date: date)
            }

            HStack {
                Text(monthLabel(weeks.first?.first?.date))
                    .font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text("Today").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                legendItem(Aura.coral, "Needs work")
                legendItem(Aura.orange, "Good")
                legendItem(Aura.green, "Great")
                Spacer()
            }
            .padding(.top, 2)
        }
        .calCard()
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color).frame(width: 12, height: 12)
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
        }
    }

    // MARK: - Month calendar (browse & tap individual days)

    private var monthCalendarCard: some View {
        VStack(spacing: 16) {
            HStack {
                monthNavButton("chevron.left") { changeMonth(-1) }
                Spacer()
                Text(monthYearTitle)
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.primary)
                    .id(monthYearTitle).transition(.opacity)
                Spacer()
                monthNavButton("chevron.right", disabled: !canGoNext) { changeMonth(1) }
            }
            .padding(.horizontal, 2)

            CalendarGridView(
                month: currentMonth,
                history: dataStore.allHistory,
                onDayTapped: { date in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedDate = IdentifiableDate(date: date)
                }
            )
        }
        .calCard()
    }

    private func monthNavButton(_ icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(disabled ? .secondary.opacity(0.4) : .primary)
                .frame(width: 38, height: 38)
                .background(Aura.softFill, in: Circle())
                .overlay(Circle().stroke(Aura.hairline, lineWidth: 1))
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }

    private var monthYearTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
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

    // MARK: - Highlights

    private var highlightsRow: some View {
        HStack(spacing: 12) {
            statCard("flame.fill", Aura.orange, "\(streak)", streak == 1 ? "Day streak" : "Day streak")
            statCard("star.fill", Aura.green, "\(bestScore)", "Best day")
            statCard("clock.fill", Aura.accent, uprightText, "Upright")
        }
    }

    private func statCard(_ icon: String, _ color: Color, _ value: String, _ label: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundColor(color)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .calCard(0)
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

    private var trendDelta: Int {
        let cur = trackedScores(daysAgo: 0..<30)
        let prev = trackedScores(daysAgo: 30..<60)
        guard !cur.isEmpty, !prev.isEmpty else { return 0 }
        return cur.reduce(0, +) / cur.count - prev.reduce(0, +) / prev.count
    }

    /// Daily scores for the last 30 days (0 for untracked), oldest → newest.
    private var waveScores: [Double] {
        let today = calendar.startOfDay(for: Date())
        return (0..<30).reversed().map { off in
            let d = calendar.date(byAdding: .day, value: -off, to: today) ?? today
            let h = dataStore.getHistory(for: d)
            return (h?.totalMonitoredSeconds ?? 0) > 0 ? Double(h?.score ?? 0) : 0
        }
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

    private var bestScore: Int { trackedDays.map { $0.score }.max() ?? 0 }
    private var daysTracked: Int { trackedDays.count }

    private var uprightText: String {
        let secs = trackedDays.reduce(0.0) { $0 + $1.goodPostureSeconds }
        let hours = secs / 3600
        if hours >= 10 { return "\(Int(hours))h" }
        if hours >= 1 { return String(format: "%.1fh", hours) }
        return "\(Int(secs / 60))m"
    }

    private var insight: String {
        if streak >= 7 { return "\(streak)-day streak — you're on fire" }
        if trendDelta >= 3 { return "Trending up \(trendDelta) pts vs last month" }
        if avg30 >= 80 { return "Excellent — your posture is dialed in" }
        if streak >= 3 { return "\(streak) days in a row — keep it going" }
        if avg30 == 0 { return "Start a session to build your journal" }
        return "Every upright minute adds up"
    }

    private var insightIcon: String {
        if streak >= 7 { return "flame.fill" }
        if trendDelta >= 3 { return "arrow.up.right" }
        if avg30 >= 80 { return "sparkles" }
        return "chart.line.uptrend.xyaxis"
    }

    /// 13 weeks of days as columns (Mon→Sun rows), oldest week first, ending this week.
    private func heatmapWeeks() -> [[HeatDay]] {
        let numWeeks = 13
        let today = calendar.startOfDay(for: Date())
        // Monday-indexed weekday (Mon = 0 … Sun = 6)
        let weekdayMon = (calendar.component(.weekday, from: today) + 5) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -weekdayMon, to: today),
              let start = calendar.date(byAdding: .day, value: -(numWeeks - 1) * 7, to: thisMonday) else { return [] }

        return (0..<numWeeks).map { w in
            (0..<7).map { r -> HeatDay in
                let date = calendar.date(byAdding: .day, value: w * 7 + r, to: start) ?? start
                let future = date > today
                let h = future ? nil : dataStore.getHistory(for: date)
                let score = (h?.totalMonitoredSeconds ?? 0) > 0 ? h?.score : nil
                return HeatDay(date: date, score: score, future: future,
                               isToday: calendar.isDateInToday(date))
            }
        }
    }

    private func monthLabel(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

// MARK: - Heatmap

struct HeatDay: Identifiable {
    var id: Date { date }
    let date: Date
    let score: Int?     // nil = no data
    let future: Bool
    let isToday: Bool
}

/// A GitHub-style contribution grid, reimagined with the posture palette: each
/// day is a rounded cell coloured by its score, great days glow, today is ringed.
struct PostureHeatmap: View {
    let weeks: [[HeatDay]]
    let onTap: (Date) -> Void

    private let cell: CGFloat = 18
    private let gap: CGFloat = 4

    var body: some View {
        HStack(spacing: gap) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, column in
                VStack(spacing: gap) {
                    ForEach(column) { day in
                        cellView(day)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func cellView(_ day: HeatDay) -> some View {
        if day.future {
            Color.clear.frame(width: cell, height: cell)
        } else if let score = day.score {
            let color = Aura.scoreColor(score)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LinearGradient(colors: [color, color.opacity(0.78)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: cell, height: cell)
                .shadow(color: score >= 80 ? color.opacity(0.55) : .clear, radius: 4)
                .overlay(todayRing(day.isToday))
                .contentShape(Rectangle())
                .onTapGesture { onTap(day.date) }
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Aura.softFill)
                .frame(width: cell, height: cell)
                .overlay(todayRing(day.isToday))
        }
    }

    @ViewBuilder
    private func todayRing(_ isToday: Bool) -> some View {
        if isToday {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Aura.accent, lineWidth: 1.6)
        }
    }
}

// MARK: - Score wave (hero sparkline)

/// A smooth gradient area chart of daily scores — the hero's flowing "pulse".
struct ScoreWave: View {
    let scores: [Double]     // 0…100
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let pts = points(w: geo.size.width, h: geo.size.height)
            ZStack {
                // baseline
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height - 1))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 1))
                }
                .stroke(Aura.hairline, lineWidth: 1)

                areaPath(pts, height: geo.size.height)
                    .fill(LinearGradient(colors: [tint.opacity(0.34), tint.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                linePath(pts)
                    .stroke(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let last = pts.last {
                    Circle().fill(tint).frame(width: 8, height: 8)
                        .shadow(color: tint.opacity(0.8), radius: 4)
                        .position(last)
                }
            }
        }
    }

    private func points(w: CGFloat, h: CGFloat) -> [CGPoint] {
        guard scores.count > 1 else {
            return scores.isEmpty ? [] : [CGPoint(x: w / 2, y: h / 2)]
        }
        let n = scores.count
        let pad: CGFloat = 5
        return scores.enumerated().map { i, s in
            let x = w * CGFloat(i) / CGFloat(n - 1)
            let clamped = CGFloat(min(max(s, 0), 100) / 100)
            let y = (h - pad) - (h - 2 * pad) * clamped
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path { smooth(pts) }

    private func areaPath(_ pts: [CGPoint], height: CGFloat) -> Path {
        var p = smooth(pts)
        if let last = pts.last, let first = pts.first {
            p.addLine(to: CGPoint(x: last.x, y: height))
            p.addLine(to: CGPoint(x: first.x, y: height))
            p.closeSubpath()
        }
        return p
    }

    /// Smooth curve with horizontal control points at segment midpoints.
    private func smooth(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        guard pts.count > 1 else { return p }
        for i in 1..<pts.count {
            let prev = pts[i - 1], cur = pts[i]
            let midX = (prev.x + cur.x) / 2
            p.addCurve(to: cur,
                       control1: CGPoint(x: midX, y: prev.y),
                       control2: CGPoint(x: midX, y: cur.y))
        }
        return p
    }
}
