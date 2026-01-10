//
//  PostureHistory.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import Foundation

struct PostureHistory: Codable, Identifiable {
    var id: String // Date string "yyyy-MM-dd"
    var date: Date

    // Time tracking (in seconds)
    var totalMonitoredSeconds: TimeInterval = 0
    var goodPostureSeconds: TimeInterval = 0
    var badPostureSeconds: TimeInterval = 0

    // Alert tracking
    var alertCount: Int = 0

    // Computed score (0-100)
    var score: Int {
        guard totalMonitoredSeconds > 0 else { return 0 }
        let goodPercentage = (goodPostureSeconds / totalMonitoredSeconds) * 100
        return Int(goodPercentage.rounded())
    }

    // Human-readable good posture duration
    var goodPostureDuration: String {
        formatDuration(goodPostureSeconds)
    }

    // Percentage of bad posture
    var badPosturePercentage: Double {
        guard totalMonitoredSeconds > 0 else { return 0 }
        return (badPostureSeconds / totalMonitoredSeconds) * 100
    }

    // Helper to format duration as "X.Xh" or "Xm"
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

    // Initialize with date
    init(date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.id = formatter.string(from: date)
        self.date = Calendar.current.startOfDay(for: date)
    }

    // Update metrics from a session
    mutating func updateFromSession(
        goodSeconds: TimeInterval,
        badSeconds: TimeInterval,
        alerts: Int
    ) {
        self.goodPostureSeconds += goodSeconds
        self.badPostureSeconds += badSeconds
        self.totalMonitoredSeconds = goodPostureSeconds + badPostureSeconds
        self.alertCount += alerts
    }
}
