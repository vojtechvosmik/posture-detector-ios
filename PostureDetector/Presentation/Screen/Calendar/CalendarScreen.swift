//
//  CalendarScreen.swift
//  PostureDetector
//
//  Dark "aurora" calendar: a living gradient backdrop with frosted glass cards,
//  matching the home & onboarding language.
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
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: IdentifiableDate?
    @State private var showStreakCelebration = false
    @State private var celebrationMessage = ""

    private let calendar = Calendar.current

    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                monthSwitcher

                if dataStore.allHistory.filter({ $0.totalMonitoredSeconds > 0 }).isEmpty {
                    emptyStateView.padding(.top, 24)
                } else {
                    calendarCard
                    monthlySummaryCard
                    legendCard
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .background(CalAurora())
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDate) { identifiableDate in
            DayDetailView(date: identifiableDate.date,
                          history: dataStore.getHistory(for: identifiableDate.date))
        }
        .overlay(alignment: .center) { streakCelebration }
        .onAppear { checkForMilestoneStreak() }
    }

    // MARK: - Month switcher

    private var monthSwitcher: some View {
        HStack {
            navButton("chevron.left", action: previousMonth)
            Spacer()
            Text(monthYearTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .id(monthYearTitle)
                .transition(.opacity)
            Spacer()
            navButton("chevron.right", action: nextMonth)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(Aura.softFill, in: Circle())
                .overlay(Circle().stroke(Aura.hairline, lineWidth: 1))
        }
    }

    // MARK: - Cards

    private var calendarCard: some View {
        CalendarGridView(
            month: currentMonth,
            history: dataStore.allHistory,
            onDayTapped: { date in selectedDate = IdentifiableDate(date: date) }
        )
        .calCard()
    }

    private var monthlySummaryCard: some View {
        let monthHistory = getMonthHistory()
        return VStack(alignment: .leading, spacing: 16) {
            Text("This Month")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 10) {
                monthlyStat("calendar", "\(monthHistory.count)", "Days", CalTheme.accent)
                statDivider
                monthlyStat("chart.bar.fill", "\(calculateMonthlyAverage(monthHistory))", "Avg Score", CalTheme.green)
                statDivider
                monthlyStat("flame.fill", "\(calculateStreak())", "Streak", CalTheme.orange)
                    .onTapGesture {
                        let streak = calculateStreak()
                        if streak >= 7 { celebrateStreak(streak: streak) }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .calCard()
    }

    private var statDivider: some View {
        Rectangle().fill(Aura.hairline).frame(width: 1, height: 44)
    }

    private func monthlyStat(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundColor(color)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Legend")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            legendRow(CalTheme.green, "Excellent · 80–100")
            legendRow(CalTheme.orange, "Good · 60–79")
            legendRow(CalTheme.coral, "Needs work · 0–59")
            legendRow(Aura.softFill, "No data")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .calCard()
    }

    private func legendRow(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 22, height: 22)
            Text(label).font(.system(size: 14)).foregroundColor(.primary)
            Spacer()
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(CalTheme.accent).frame(width: 100, height: 100).blur(radius: 34).opacity(0.4)
                Image(systemName: "calendar.badge.clock").font(.system(size: 54)).foregroundColor(.primary)
            }
            Text("No posture data yet").font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
            Text("Start monitoring to see your progress fill in here.")
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

    // MARK: - Streak celebration

    @ViewBuilder private var streakCelebration: some View {
        if showStreakCelebration {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                    .onTapGesture { withAnimation { showStreakCelebration = false } }

                VStack(spacing: 18) {
                    Text("🔥").font(.system(size: 76))
                        .scaleEffect(showStreakCelebration ? 1 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showStreakCelebration)
                    Text(celebrationMessage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Button(action: { withAnimation { showStreakCelebration = false } }) {
                        Text("Awesome!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 34).padding(.vertical, 13)
                            .background(LinearGradient(colors: [CalTheme.orange, CalTheme.coral],
                                                       startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(34)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Aura.cardStroke, lineWidth: 1))
                .padding(40)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }

    private func celebrateStreak(streak: Int) {
        let message: String
        if streak >= 365 { message = "Amazing! \(streak) day streak!\n🏆 You're a posture champion!" }
        else if streak >= 100 { message = "Incredible! \(streak) day streak!\n💪 Keep up the great work!" }
        else if streak >= 30 { message = "Fantastic! \(streak) day streak!\n🌟 A full month of good posture!" }
        else if streak >= 7 { message = "Great job! \(streak) day streak!\n🎉 A full week achieved!" }
        else { return }
        celebrationMessage = message
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showStreakCelebration = true }
    }

    private func checkForMilestoneStreak() {
        let streak = calculateStreak()
        let lastShownStreak = UserDefaults.standard.integer(forKey: "lastCelebratedStreak")
        let milestones = [7, 14, 30, 60, 100, 365]
        if let milestone = milestones.first(where: { streak >= $0 && lastShownStreak < $0 }) {
            _ = milestone
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                celebrateStreak(streak: streak)
                UserDefaults.standard.set(streak, forKey: "lastCelebratedStreak")
            }
        }
    }

    // MARK: - Data helpers

    private func previousMonth() {
        if let m = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { currentMonth = m }
        }
    }

    private func nextMonth() {
        if let m = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { currentMonth = m }
        }
    }

    private func getMonthHistory() -> [PostureHistory] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        return dataStore.getHistory(from: monthInterval.start, to: monthInterval.end)
            .filter { $0.totalMonitoredSeconds > 0 }
    }

    private func calculateMonthlyAverage(_ history: [PostureHistory]) -> Int {
        guard !history.isEmpty else { return 0 }
        return history.reduce(0) { $0 + $1.score } / history.count
    }

    private func calculateStreak() -> Int {
        var streak = 0
        var checkDate = Date()
        while let history = dataStore.getHistory(for: checkDate), history.totalMonitoredSeconds > 0 {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }
        return streak
    }
}
