//
//  CalendarScreen.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

// Wrapper to make Date identifiable for sheet presentation
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct CalendarScreen: View {
    @StateObject private var dataStore = PostureDataStore()
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: IdentifiableDate?
    @State private var showDayDetail = false

    private let calendar = Calendar.current

    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Calendar grid
                CalendarGridView(
                    month: currentMonth,
                    history: dataStore.allHistory,
                    onDayTapped: { date in
                        selectedDate = IdentifiableDate(date: date)
                        showDayDetail = true
                    }
                )
                .padding(.horizontal, 20)

                // Monthly summary
                monthlySummaryCard

                // Legend
                legendCard
            }
            .padding(.vertical, 20)
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle(monthYearTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(item: $selectedDate) { identifiableDate in
            DayDetailView(
                date: identifiableDate.date,
                history: dataStore.getHistory(for: identifiableDate.date)
            )
        }
    }

    @ViewBuilder
    private var monthlySummaryCard: some View {
        let monthHistory = getMonthHistory()

        VStack(spacing: 16) {
            HStack {
                Text("This Month")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }

            HStack(spacing: 16) {
                MonthlyStat(
                    icon: "calendar",
                    value: "\(monthHistory.count)",
                    label: "Days Tracked",
                    color: .blue
                )

                MonthlyStat(
                    icon: "chart.bar.fill",
                    value: "\(calculateMonthlyAverage(monthHistory))",
                    label: "Avg Score",
                    color: .green
                )

                MonthlyStat(
                    icon: "flame.fill",
                    value: "\(calculateStreak())",
                    label: "Day Streak",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var legendCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Score Legend")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 8) {
                LegendRow(color: .green, label: "Excellent (80-100)")
                LegendRow(color: .orange, label: "Good (60-79)")
                LegendRow(color: .red, label: "Needs Improvement (0-59)")
                LegendRow(color: .gray.opacity(0.2), label: "No Data")
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }

    // MARK: - Helper Methods

    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentMonth = newMonth
            }
        }
    }

    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentMonth = newMonth
            }
        }
    }

    private func getMonthHistory() -> [PostureHistory] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }

        return dataStore.getHistory(from: monthInterval.start, to: monthInterval.end)
            .filter { $0.totalMonitoredSeconds > 0 }
    }

    private func calculateMonthlyAverage(_ history: [PostureHistory]) -> Int {
        guard !history.isEmpty else { return 0 }
        let total = history.reduce(0) { $0 + $1.score }
        return total / history.count
    }

    private func calculateStreak() -> Int {
        var streak = 0
        var checkDate = Date()

        while let history = dataStore.getHistory(for: checkDate),
              history.totalMonitoredSeconds > 0 {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }
}

struct MonthlyStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LegendRow: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 24, height: 24)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}
