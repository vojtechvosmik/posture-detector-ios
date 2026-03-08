//
//  PostureSummaryWidgetViews.swift
//  PostureLiveActivity
//
//  Widget views for small, medium, and large posture summary widgets
//

import SwiftUI
import WidgetKit

// MARK: - Entry View (dispatches by family)

struct PostureSummaryWidgetEntryView: View {
    var entry: PostureSummaryEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallPostureWidget(entry: entry)
        case .systemMedium:
            MediumPostureWidget(entry: entry)
        case .systemLarge:
            LargePostureWidget(entry: entry)
        default:
            SmallPostureWidget(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallPostureWidget: View {
    let entry: PostureSummaryEntry

    var body: some View {
        if entry.hasData, let today = entry.todayHistory {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("Today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: CGFloat(today.score) / 100.0)
                        .stroke(
                            scoreColor(today.score),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    Text("\(today.score)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(scoreColor(today.score))
                }

                Spacer()

                Text("Posture Score")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.stand")
                .font(.system(size: 32))
                .foregroundStyle(.gray.opacity(0.4))

            Text("No Data Yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Start monitoring")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Medium Widget

struct MediumPostureWidget: View {
    let entry: PostureSummaryEntry

    var body: some View {
        if entry.hasData, let today = entry.todayHistory {
            HStack(spacing: 16) {
                // Left: Score ring
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                        Circle()
                            .trim(from: 0, to: CGFloat(today.score) / 100.0)
                            .stroke(
                                scoreColor(today.score),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Text("\(today.score)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(scoreColor(today.score))
                    }
                    .frame(width: 90, height: 90)

                    Text("Today's Score")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    // Trend vs yesterday
                    trendLabel
                }

                Divider()

                // Right: Stats column
                VStack(alignment: .leading, spacing: 10) {
                    WidgetStatRow(
                        icon: "clock.fill",
                        label: "Monitored",
                        value: today.totalMonitoredDuration,
                        color: .blue
                    )
                    WidgetStatRow(
                        icon: "checkmark.circle.fill",
                        label: "Good Posture",
                        value: today.goodPostureDuration,
                        color: .green
                    )
                    WidgetStatRow(
                        icon: "exclamationmark.triangle.fill",
                        label: "Alerts",
                        value: "\(today.alertCount)",
                        color: .orange
                    )
                }
            }
        } else {
            mediumEmptyState
        }
    }

    @ViewBuilder
    private var trendLabel: some View {
        if let yesterday = entry.yesterdayHistory,
           yesterday.totalMonitoredSeconds > 0,
           let today = entry.todayHistory {
            let diff = today.score - yesterday.score
            HStack(spacing: 2) {
                Image(systemName: diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "arrow.right")
                    .font(.system(size: 10))
                Text("\(abs(diff))pts")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(diff > 0 ? .green : diff < 0 ? .red : .secondary)
        }
    }

    private var mediumEmptyState: some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.stand")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.4))

            VStack(alignment: .leading, spacing: 4) {
                Text("No Posture Data Yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Open the app and start monitoring to see your posture summary here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
            }
        }
    }
}

// MARK: - Large Widget

struct LargePostureWidget: View {
    let entry: PostureSummaryEntry

    var body: some View {
        if entry.hasData, let today = entry.todayHistory {
            VStack(spacing: 14) {
                // Top: Score + Stats (same as medium layout)
                HStack(spacing: 16) {
                    // Score ring
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                            Circle()
                                .trim(from: 0, to: CGFloat(today.score) / 100.0)
                                .stroke(
                                    scoreColor(today.score),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            Text("\(today.score)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(scoreColor(today.score))
                        }
                        .frame(width: 90, height: 90)

                        Text("Today's Score")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        // Trend vs yesterday
                        trendLabel
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        WidgetStatRow(
                            icon: "clock.fill",
                            label: "Monitored",
                            value: today.totalMonitoredDuration,
                            color: .blue
                        )
                        WidgetStatRow(
                            icon: "checkmark.circle.fill",
                            label: "Good Posture",
                            value: today.goodPostureDuration,
                            color: .green
                        )
                        WidgetStatRow(
                            icon: "exclamationmark.triangle.fill",
                            label: "Alerts",
                            value: "\(today.alertCount)",
                            color: .orange
                        )
                    }
                }

                Divider()

                // Bottom: 7-day chart
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("This Week")
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        if entry.streak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)

                                Text("\(entry.streak) day streak")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    WeeklyChartView(weekHistory: entry.weekHistory)
                }
            }
        } else {
            largeEmptyState
        }
    }

    @ViewBuilder
    private var trendLabel: some View {
        if let yesterday = entry.yesterdayHistory,
           yesterday.totalMonitoredSeconds > 0,
           let today = entry.todayHistory {
            let diff = today.score - yesterday.score
            HStack(spacing: 2) {
                Image(systemName: diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "arrow.right")
                    .font(.system(size: 10))
                Text("\(abs(diff))pts")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(diff > 0 ? .green : diff < 0 ? .red : .secondary)
        }
    }

    private var largeEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.stand")
                .font(.system(size: 48))
                .foregroundStyle(.gray.opacity(0.4))

            Text("No Posture Data Yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Open the app and start monitoring your posture. Your daily scores and weekly trends will appear here.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Weekly Chart

struct WeeklyChartView: View {
    let weekHistory: [PostureHistory]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(last7Days(), id: \.self) { date in
                let score = scoreForDate(date)
                let isToday = Calendar.current.isDateInToday(date)

                VStack(spacing: 4) {
                    if score > 0 {
                        Text("\(score)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(score > 0 ? scoreColor(score) : Color.gray.opacity(0.15))
                        .frame(height: score > 0 ? max(8, CGFloat(score) / 100.0 * 60) : 8)

                    Text(dayAbbreviation(date))
                        .font(.system(size: 10, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 90)
    }

    private func last7Days() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -(6 - offset), to: today)
        }
    }

    private func scoreForDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        return weekHistory.first { calendar.isDate($0.date, inSameDayAs: date) }?.score ?? 0
    }

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let str = formatter.string(from: date)
        return String(str.prefix(2))
    }
}

// MARK: - Shared Components

struct WidgetStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Helpers

func scoreColor(_ score: Int) -> Color {
    if score >= 80 { return .green }
    if score >= 60 { return .orange }
    return .red
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    PostureSummaryWidget()
} timeline: {
    PostureSummaryEntry(
        date: Date(),
        todayHistory: previewTodayHistory(),
        yesterdayHistory: previewYesterdayHistory(),
        weekHistory: previewWeekHistory(),
        streak: 3,
        hasData: true
    )
}

#Preview("Medium", as: .systemMedium) {
    PostureSummaryWidget()
} timeline: {
    PostureSummaryEntry(
        date: Date(),
        todayHistory: previewTodayHistory(),
        yesterdayHistory: previewYesterdayHistory(),
        weekHistory: previewWeekHistory(),
        streak: 5,
        hasData: true
    )
}

#Preview("Large", as: .systemLarge) {
    PostureSummaryWidget()
} timeline: {
    PostureSummaryEntry(
        date: Date(),
        todayHistory: previewTodayHistory(),
        yesterdayHistory: previewYesterdayHistory(),
        weekHistory: previewWeekHistory(),
        streak: 5,
        hasData: true
    )
}

#Preview("Empty Small", as: .systemSmall) {
    PostureSummaryWidget()
} timeline: {
    PostureSummaryEntry(
        date: Date(),
        todayHistory: nil,
        yesterdayHistory: nil,
        weekHistory: [],
        streak: 0,
        hasData: false
    )
}

// MARK: - Preview Helpers

private func previewTodayHistory() -> PostureHistory {
    var h = PostureHistory(date: Date())
    h.updateFromSession(goodSeconds: 5400, badSeconds: 1200, alerts: 4)
    return h
}

private func previewYesterdayHistory() -> PostureHistory {
    var h = PostureHistory(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
    h.updateFromSession(goodSeconds: 4800, badSeconds: 1800, alerts: 6)
    return h
}

private func previewWeekHistory() -> [PostureHistory] {
    let calendar = Calendar.current
    return (0..<7).map { offset in
        let date = calendar.date(byAdding: .day, value: -(6 - offset), to: Date())!
        var h = PostureHistory(date: date)
        let goodSeconds = Double.random(in: 3000...7000)
        let badSeconds = Double.random(in: 500...2500)
        h.updateFromSession(goodSeconds: goodSeconds, badSeconds: badSeconds, alerts: Int.random(in: 0...8))
        return h
    }
}
