//
//  PostureMonitor+Session.swift
//  PostureDetector
//
//  Session tracking extension for PostureMonitor
//

import Foundation
import Combine

extension PostureMonitor {

    // MARK: - Session Tracking

    /// Session state tracking
    class SessionTracker: ObservableObject {
        @Published var isMonitoring = false
        @Published var sessionStartTime: Date?

        // Time tracking
        private var goodPostureAccumulator: TimeInterval = 0
        private var badPostureAccumulator: TimeInterval = 0
        private var lastUpdateTime: Date?

        // Alert tracking
        private var sessionAlertCount = 0

        // Public accessor for alert count
        var alertCount: Int {
            return sessionAlertCount
        }

        // Reference to data store
        weak var dataStore: PostureDataStore?

        // Timer for periodic saves
        private var saveTimer: Timer?

        func startSession(dataStore: PostureDataStore) {
            self.dataStore = dataStore
            self.sessionStartTime = Date()
            self.lastUpdateTime = Date()
            self.goodPostureAccumulator = 0
            self.badPostureAccumulator = 0
            self.sessionAlertCount = 0
            self.isMonitoring = true

            // Start periodic save timer (every 5 seconds)
            saveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.saveCurrentSession()
            }
        }

        func endSession() {
            saveCurrentSession()
            saveTimer?.invalidate()
            saveTimer = nil
            self.isMonitoring = false
            self.sessionStartTime = nil
            self.lastUpdateTime = nil
        }

        func updatePostureStatus(_ status: PostureStatus) {
            guard isMonitoring, let lastUpdate = lastUpdateTime else { return }

            let now = Date()
            let elapsed = now.timeIntervalSince(lastUpdate)

            // Only accumulate if elapsed time is reasonable (not on app wake from background)
            guard elapsed < 2.0 else {
                lastUpdateTime = now
                return
            }

            // Accumulate time based on posture status
            switch status {
            case .good:
                goodPostureAccumulator += elapsed
            case .forwardLean, .sidewaysLean, .poorPosture:
                badPostureAccumulator += elapsed
            case .unknown:
                break // Don't count unknown state
            }

            lastUpdateTime = now
        }

        func incrementAlertCount() {
            guard isMonitoring else { return }
            sessionAlertCount += 1
        }

        private func saveCurrentSession() {
            guard isMonitoring else { return }

            dataStore?.updateTodayHistory(
                goodSeconds: goodPostureAccumulator,
                badSeconds: badPostureAccumulator,
                alerts: sessionAlertCount
            )

            // Reset accumulators after save
            goodPostureAccumulator = 0
            badPostureAccumulator = 0
            sessionAlertCount = 0
        }

        deinit {
            saveTimer?.invalidate()
        }
    }
}
