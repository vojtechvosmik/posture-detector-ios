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
}
