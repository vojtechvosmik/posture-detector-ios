//
//  PostureSummaryWidget.swift
//  PostureLiveActivity
//
//  Home screen widget showing posture summary in small, medium, and large sizes
//

import WidgetKit
import SwiftUI

// MARK: - PostureHistory (Widget-local copy for decoding shared data)

struct PostureHistory: Codable, Identifiable {
    var id: String
    var date: Date

    var totalMonitoredSeconds: TimeInterval = 0
    var goodPostureSeconds: TimeInterval = 0
    var badPostureSeconds: TimeInterval = 0
    var alertCount: Int = 0

    var score: Int {
        guard totalMonitoredSeconds > 0 else { return 0 }
        let goodPercentage = (goodPostureSeconds / totalMonitoredSeconds) * 100
        return Int(goodPercentage.rounded())
    }

    var goodPostureDuration: String {
        formatDuration(goodPostureSeconds)
    }

    var totalMonitoredDuration: String {
        formatDuration(totalMonitoredSeconds)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        let minutes = (seconds.truncatingRemainder(dividingBy: 3600)) / 60
        if hours >= 1 {
            return String(format: "%.1fh", hours)
        } else if minutes >= 1 {
            return "\(Int(minutes))m"
        } else {
            return "<1m"
        }
    }

    init(date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.id = formatter.string(from: date)
        self.date = Calendar.current.startOfDay(for: date)
    }

    mutating func updateFromSession(goodSeconds: TimeInterval, badSeconds: TimeInterval, alerts: Int) {
        self.goodPostureSeconds += goodSeconds
        self.badPostureSeconds += badSeconds
        self.totalMonitoredSeconds = goodPostureSeconds + badPostureSeconds
        self.alertCount += alerts
    }
}

// MARK: - Timeline Entry

struct PostureSummaryEntry: TimelineEntry {
    let date: Date
    let todayHistory: PostureHistory?
    let yesterdayHistory: PostureHistory?
    let weekHistory: [PostureHistory]
    let streak: Int
    let hasData: Bool
}

// MARK: - Timeline Provider

struct PostureSummaryProvider: TimelineProvider {

    func placeholder(in context: Context) -> PostureSummaryEntry {
        PostureSummaryEntry(
            date: Date(),
            todayHistory: nil,
            yesterdayHistory: nil,
            weekHistory: [],
            streak: 0,
            hasData: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PostureSummaryEntry) -> Void) {
        completion(createEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PostureSummaryEntry>) -> Void) {
        let entry = createEntry()

        // Refresh at the next hour boundary
        let nextUpdate = Calendar.current.date(
            byAdding: .hour, value: 1, to: Date()
        ) ?? Date().addingTimeInterval(3600)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry() -> PostureSummaryEntry {
        let allHistory = loadHistory()
        let calendar = Calendar.current
        let today = Date()

        let todayHistory = allHistory.first {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        let yesterdayHistory: PostureHistory? = {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
            return allHistory.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        }()

        // Last 7 days for weekly chart
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: today)) ?? today
        let weekHistory = allHistory
            .filter { $0.date >= sevenDaysAgo }
            .sorted { $0.date < $1.date }

        let streak = calculateStreak(from: allHistory)

        let hasData = todayHistory != nil && (todayHistory?.totalMonitoredSeconds ?? 0) > 0

        return PostureSummaryEntry(
            date: today,
            todayHistory: todayHistory,
            yesterdayHistory: yesterdayHistory,
            weekHistory: weekHistory,
            streak: streak,
            hasData: hasData
        )
    }

    private func loadHistory() -> [PostureHistory] {
        guard let data = SharedDefaults.sharedUserDefaults.data(forKey: SharedDefaults.postureHistoryKey),
              let history = try? JSONDecoder().decode([PostureHistory].self, from: data) else {
            return []
        }
        return history
    }

    private func calculateStreak(from history: [PostureHistory]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()

        while let record = history.first(where: { calendar.isDate($0.date, inSameDayAs: checkDate) }),
              record.totalMonitoredSeconds > 0 {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }
}

// MARK: - Widget Definition

struct PostureSummaryWidget: Widget {
    let kind: String = "PostureSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PostureSummaryProvider()) { entry in
            PostureSummaryWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Posture Summary")
        .description("View your daily posture score and trends.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
