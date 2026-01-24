//
//  PostureDataStore.swift
//  PostureDetector
//
//  Manages persistence and retrieval of posture history data
//

import Foundation
import Combine

class PostureDataStore: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let historyKey = "postureHistory"

    @Published var todayHistory: PostureHistory
    @Published var yesterdayHistory: PostureHistory?
    @Published private(set) var allHistory: [PostureHistory]

    init() {
        // Load all history from UserDefaults first
        let loadedHistory = Self.loadHistory()
        self.allHistory = loadedHistory

        // Get or create today's record
        let today = Date()
        if let existing = loadedHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            self.todayHistory = existing
        } else {
            self.todayHistory = PostureHistory(date: today)
        }

        // Get yesterday's record
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) {
            self.yesterdayHistory = loadedHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: yesterday) })
        } else {
            self.yesterdayHistory = nil
        }
    }

    // MARK: - Session Management

    /// Update today's history with session data
    func updateTodayHistory(goodSeconds: TimeInterval, badSeconds: TimeInterval, alerts: Int) {
        todayHistory.updateFromSession(
            goodSeconds: goodSeconds,
            badSeconds: badSeconds,
            alerts: alerts
        )
        saveHistory()
    }

    /// Save current state to UserDefaults
    func saveHistory() {
        // Update or add today's record in the array
        if let index = allHistory.firstIndex(where: { $0.id == todayHistory.id }) {
            allHistory[index] = todayHistory
        } else {
            allHistory.append(todayHistory)
        }

        // Keep only last 90 days of history
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        allHistory = allHistory.filter { $0.date >= cutoffDate }

        // Sort by date descending
        allHistory.sort { $0.date > $1.date }

        // Encode and save
        if let encoded = try? JSONEncoder().encode(allHistory) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }

    // MARK: - History Retrieval

    /// Get history for a specific date
    func getHistory(for date: Date) -> PostureHistory? {
        return allHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
    }

    /// Get history for a date range
    func getHistory(from startDate: Date, to endDate: Date) -> [PostureHistory] {
        return allHistory.filter { $0.date >= startDate && $0.date <= endDate }
    }

    // MARK: - Private Helpers

    private static func loadHistory() -> [PostureHistory] {
        guard let data = UserDefaults.standard.data(forKey: "postureHistory"),
              let history = try? JSONDecoder().decode([PostureHistory].self, from: data) else {
            return []
        }
        return history
    }

    // MARK: - Computed Properties

    /// Score improvement compared to yesterday
    var scoreImprovement: Int {
        guard let yesterday = yesterdayHistory else { return 0 }
        return todayHistory.score - yesterday.score
    }

    /// Score improvement percentage string (e.g., "+5%" or "-3%")
    var scoreImprovementPercentage: String {
        guard let yesterday = yesterdayHistory, yesterday.score > 0 else { return "N/A" }
        let improvement = todayHistory.score - yesterday.score
        let percentage = (Double(improvement) / Double(yesterday.score)) * 100

        if improvement > 0 {
            return String(format: "+%.0f%%", percentage)
        } else if improvement < 0 {
            return String(format: "%.0f%%", percentage)
        } else {
            return "0%"
        }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    /// Fill database with realistic sample data for screenshots
    func fillWithSampleData() {
        var sampleHistory: [PostureHistory] = []
        let calendar = Calendar.current

        // Generate 30 days of data
        for daysAgo in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }

            // Create realistic varying data
            let baseScore = 70 + Int.random(in: -15...25) // Scores between 55-95
            let monitoredHours = Double.random(in: 2.0...8.0) // 2-8 hours
            let totalSeconds = monitoredHours * 3600

            // Good posture percentage varies based on score
            let goodPercentage = Double(baseScore) / 100.0 + Double.random(in: -0.1...0.1)
            let goodSeconds = totalSeconds * goodPercentage
            let badSeconds = totalSeconds - goodSeconds

            // Alert count based on bad posture time
            let alertCount = Int(badSeconds / 300) + Int.random(in: -2...2) // ~1 alert per 5 min of bad posture
            let finalAlertCount = max(0, alertCount)

            var history = PostureHistory(date: date)
            history.updateFromSession(
                goodSeconds: goodSeconds,
                badSeconds: badSeconds,
                alerts: finalAlertCount
            )

            sampleHistory.append(history)
        }

        // Save all sample data
        self.allHistory = sampleHistory

        // Update today's history
        if let todayData = sampleHistory.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
            self.todayHistory = todayData
        }

        // Update yesterday's history
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
           let yesterdayData = sampleHistory.first(where: { calendar.isDate($0.date, inSameDayAs: yesterday) }) {
            self.yesterdayHistory = yesterdayData
        }

        // Encode and save
        if let encoded = try? JSONEncoder().encode(allHistory) {
            userDefaults.set(encoded, forKey: historyKey)
        }

        print("✅ Database filled with 30 days of sample data")
    }

    /// Clear all data
    func clearAllData() {
        allHistory = []
        todayHistory = PostureHistory(date: Date())
        yesterdayHistory = nil
        userDefaults.removeObject(forKey: historyKey)
        print("🗑️ All data cleared")
    }
    #endif
}
