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
        /// Bad time split by direction, for the pattern analyzer.
        private var forwardAccumulator: TimeInterval = 0
        private var sidewaysAccumulator: TimeInterval = 0
        private var lastUpdateTime: Date?

        // Alert tracking
        private var sessionAlertCount = 0

        // Public accessor for alert count
        var alertCount: Int {
            return sessionAlertCount
        }

        // Reference to data store
        weak var dataStore: PostureDataStore?

        /// Mode the monitor is currently running in, stamped onto every slot.
        var currentMode: PostureMode = .desk

        // Intraday samples
        private let samples = PostureSampleStore.shared
        private var slotAlerts = 0

        /// Open slouch episode: when it started and whether it has alerted.
        private var episodeStart: Date?
        private var episodeAlertedAt: Date?

        // Timer for periodic saves
        private var saveTimer: Timer?

        func startSession(dataStore: PostureDataStore) {
            self.dataStore = dataStore
            self.sessionStartTime = Date()
            self.lastUpdateTime = Date()
            self.goodPostureAccumulator = 0
            self.badPostureAccumulator = 0
            self.forwardAccumulator = 0
            self.sidewaysAccumulator = 0
            self.sessionAlertCount = 0
            self.slotAlerts = 0
            self.episodeStart = nil
            self.episodeAlertedAt = nil
            self.isMonitoring = true

            // Start periodic save timer (every 5 seconds)
            saveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.saveCurrentSession()
            }
        }

        func endSession() {
            closeEpisode(at: Date())
            saveCurrentSession()
            samples.flush(force: true)
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
            case .forwardLean:
                badPostureAccumulator += elapsed
                forwardAccumulator += elapsed
            case .sidewaysLean:
                badPostureAccumulator += elapsed
                sidewaysAccumulator += elapsed
            case .poorPosture:
                // Both at once — attribute to the dominant direction, forward.
                badPostureAccumulator += elapsed
                forwardAccumulator += elapsed
            case .unknown:
                break // Don't count unknown state
            }

            lastUpdateTime = now
        }

        func incrementAlertCount() {
            guard isMonitoring else { return }
            sessionAlertCount += 1
            slotAlerts += 1
            if episodeAlertedAt == nil { episodeAlertedAt = Date() }
        }

        // MARK: - Episodes

        /// Called when posture leaves the good state.
        func beginEpisode(at date: Date = Date()) {
            guard isMonitoring, episodeStart == nil else { return }
            episodeStart = date
            episodeAlertedAt = nil
        }

        /// Called when posture returns to good — records the finished episode
        /// along with how long the correction took after any alert.
        func closeEpisode(at date: Date = Date()) {
            guard let start = episodeStart else { return }
            episodeStart = nil
            let alertedAt = episodeAlertedAt
            episodeAlertedAt = nil

            samples.recordEpisode(start: start,
                                  duration: date.timeIntervalSince(start),
                                  alerted: alertedAt != nil,
                                  recoverySeconds: alertedAt.map { date.timeIntervalSince($0) })
        }

        private func saveCurrentSession() {
            guard isMonitoring else { return }

            dataStore?.updateTodayHistory(
                goodSeconds: goodPostureAccumulator,
                badSeconds: badPostureAccumulator,
                alerts: sessionAlertCount
            )

            let minutesIn = sessionStartTime.map { Date().timeIntervalSince($0) / 60 } ?? 0
            samples.record(good: goodPostureAccumulator,
                           forward: forwardAccumulator,
                           sideways: sidewaysAccumulator,
                           alerts: slotAlerts,
                           mode: currentMode.rawValue,
                           minutesIntoSession: minutesIn)

            // Reset accumulators after save
            goodPostureAccumulator = 0
            badPostureAccumulator = 0
            forwardAccumulator = 0
            sidewaysAccumulator = 0
            sessionAlertCount = 0
            slotAlerts = 0
        }

        deinit {
            saveTimer?.invalidate()
        }
    }
}
