//
//  PostureMonitor.swift
//  PostureDetector
//
//  Monitors head position using AirPods motion data
//

import Foundation
import CoreMotion
import Combine
import UserNotifications
import AVFoundation
import UIKit
import BackgroundTasks

class PostureMonitor: NSObject, ObservableObject {
    private let motionManager = CMHeadphoneMotionManager()
    let notificationCenter = UNUserNotificationCenter.current()

    #if targetEnvironment(simulator)
    @Published var isConnected = true {
        didSet {
            // Only update if the connection state actually changed
            guard oldValue != isConnected else { return }

            // Handle disconnection timeout
            if #available(iOS 16.1, *), currentActivity != nil {
                if !isConnected {
                    startDisconnectionTimer()
                } else {
                    cancelDisconnectionTimer()
                }
            }
        }
    }
    #else
    @Published var isConnected = false {
        didSet {
            // Only update if the connection state actually changed
            guard oldValue != isConnected else { return }

            // Handle disconnection timeout
            if #available(iOS 16.1, *), currentActivity != nil {
                if !isConnected {
                    startDisconnectionTimer()
                } else {
                    cancelDisconnectionTimer()
                }
            }
        }
    }
    #endif
    @Published var postureStatus: PostureStatus = .unknown
    @Published var pitch: Double = 0.0  // Forward/backward tilt
    @Published var roll: Double = 0.0   // Left/right tilt
    @Published var errorMessage: String?
    @Published var isMonitoring = false

    // Session tracking
    let sessionTracker = SessionTracker()
    var dataStore: PostureDataStore?

    // Live Activity
    #if canImport(ActivityKit)
    var currentActivity: Any?  // Activity<PostureAttributes> on iOS 16.1+
    #endif

    // Disconnection timer
    private var disconnectionTimer: Timer?
    private let disconnectionTimeout: TimeInterval = 60.0  // 60 seconds

    // Notification settings
    @Published var isNotificationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isNotificationEnabled, forKey: "isNotificationEnabled")
        }
    }
    @Published var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "isSoundEnabled")
            // Update background audio manager
            backgroundAudio.setSoundEnabled(isSoundEnabled)
        }
    }
    private var badPostureTimer: DispatchSourceTimer?
    private let badPostureNotificationDelay: TimeInterval = 5.0  // 5 seconds

    // Haptic feedback
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticSuccess = UINotificationFeedbackGenerator()

    // Error recovery
    private var motionUpdateFailureCount = 0
    private let maxFailureCount = 5
    private var recoveryTimer: Timer?

    // Simulator mock data
    #if targetEnvironment(simulator)
    private var mockMotionTimer: Timer?
    private var mockPostureState: Int = 0 // 0 = good, 1 = forward lean, 2 = sideways
    #endif

    // Debug logging
    private let logger = DebugLogger.shared
    private var loggingTimer: DispatchSourceTimer?

    // Background audio for keep-alive
    private let backgroundAudio = BackgroundAudioManager.shared

    // Lifecycle observers
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    // Calibration: Good posture is around pitch 0 and roll 0
    private let targetPitch: Double = 0.0
    private let targetRoll: Double = 0.0

    // Thresholds for bad posture detection (in radians)
    private let pitchThreshold: Double = 0.20  // ~20 degrees forward/backward
    private let rollThreshold: Double = 0.20   // ~15 degrees sideways

    override init() {
        // Load saved preferences
        self.isNotificationEnabled = UserDefaults.standard.object(forKey: "isNotificationEnabled") as? Bool ?? true
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "isSoundEnabled") as? Bool ?? true

        super.init()
        checkAvailability()
        requestNotificationPermission()
        setupLifecycleObservers()
    }

    func setDataStore(_ dataStore: PostureDataStore) {
        self.dataStore = dataStore
    }

    func checkAvailability() {
        #if targetEnvironment(simulator)
        // Simulator mode - always available
        errorMessage = nil
        isConnected = true
        print("🔧 Running in Simulator - Mock motion data enabled")
        #else
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Headphone motion tracking not available on this device"
            return
        }
        errorMessage = nil
        isConnected = true
        #endif
    }


    func startMonitoring() {
        logger.log("🟢 Starting monitoring", category: "MONITOR")

        #if targetEnvironment(simulator)
        // Simulator mode - start mock data
        isMonitoring = true
        hapticMedium.impactOccurred()
        startMockMotionUpdates()
        #else
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Please connect AirPods Pro or AirPods Max"
            logger.log("❌ Device motion not available", category: "ERROR")
            return
        }

        isMonitoring = true
        hapticMedium.impactOccurred()
        #endif

        // Start debug logging timer
        startLoggingTimer()

        // Use silent audio to keep app alive in background
        backgroundAudio.setSoundEnabled(isSoundEnabled)
        backgroundAudio.startBackgroundAudio()
        logger.log("Started silent audio for background keep-alive", category: "BACKGROUND")

        // Setup audio session for alert sounds
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            logger.log("Audio session activated", category: "AUDIO")
        } catch {
            logger.log("Failed to activate audio session: \(error)", category: "ERROR")
        }

        // Start session tracking
        if let dataStore = dataStore {
            sessionTracker.startSession(dataStore: dataStore)
        }

        #if !targetEnvironment(simulator)
        // Start Live Activity
        if #available(iOS 16.1, *) {
            startLiveActivity()
        }

        // Note: CMHeadphoneMotionManager doesn't support setting update interval
        // It updates at its own optimized frequency for battery efficiency

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.isConnected = false
                self.motionUpdateFailureCount += 1

                // Attempt recovery if failures exceed threshold
                if self.motionUpdateFailureCount >= self.maxFailureCount {
                    print("⚠️ Motion updates failing, attempting recovery...")
                    self.attemptMotionRecovery()
                }
                return
            }

            guard let motion = motion else {
                self.isConnected = false
                self.motionUpdateFailureCount += 1

                if self.motionUpdateFailureCount >= self.maxFailureCount {
                    print("⚠️ No motion data, attempting recovery...")
                    self.attemptMotionRecovery()
                }
                return
            }

            // Reset failure count on successful update
            self.motionUpdateFailureCount = 0
            self.isConnected = true
            self.errorMessage = nil

            // Get pitch (forward/backward tilt) and roll (left/right tilt)
            let currentPitch = motion.attitude.pitch
            let currentRoll = motion.attitude.roll

            self.pitch = currentPitch
            self.roll = currentRoll

            // Calculate deviation from target (pitch 0, roll 0)
            let pitchDeviation = abs(currentPitch - self.targetPitch)
            let rollDeviation = abs(currentRoll - self.targetRoll)

            // Detect bad posture based on deviation magnitude
            let isForwardLean = pitchDeviation > self.pitchThreshold
            let isSidewaysLean = rollDeviation > self.rollThreshold

            let previousStatus = self.postureStatus

            if isForwardLean && isSidewaysLean {
                self.postureStatus = .poorPosture
            } else if isForwardLean {
                self.postureStatus = .forwardLean
            } else if isSidewaysLean {
                self.postureStatus = .sidewaysLean
            } else {
                self.postureStatus = .good
            }

            // Track posture time
            self.sessionTracker.updatePostureStatus(self.postureStatus)

            // Update background audio based on posture
            if self.postureStatus == .good {
                self.backgroundAudio.setPostureState(.good)
            } else {
                self.backgroundAudio.setPostureState(.bad)
            }

            // Handle posture status changes
            if previousStatus == .good && self.postureStatus != .good {
                // Bad posture detected - start 5 second timer
                self.hapticLight.impactOccurred()
                self.startBadPostureTimer()
            } else if previousStatus != .good && self.postureStatus == .good {
                // Posture improved - cancel timer and remove notifications
                self.hapticSuccess.notificationOccurred(.success)
                self.cancelBadPostureTimer()
                self.removePostureNotifications()
            }
        }
        #endif
    }

    func stopMonitoring() {
        logger.log("🔴 Stopping monitoring", category: "MONITOR")

        isMonitoring = false
        hapticMedium.impactOccurred()

        // Stop debug logging timer
        stopLoggingTimer()

        // Stop silent audio
        backgroundAudio.stopBackgroundAudio()
        logger.log("Stopped silent audio", category: "BACKGROUND")

        // End session tracking
        sessionTracker.endSession()

        #if targetEnvironment(simulator)
        stopMockMotionUpdates()
        #else
        motionManager.stopDeviceMotionUpdates()
        #endif

        //isConnected = false
        postureStatus = .unknown

        if #available(iOS 16.1, *) {
            endLiveActivity()
        }
    }

    private func startDisconnectionTimer() {
        disconnectionTimer?.invalidate()
        disconnectionTimer = Timer.scheduledTimer(withTimeInterval: disconnectionTimeout, repeats: false) { [weak self] _ in
            print("[PostureMonitor] Disconnection timeout reached - ending Live Activity")
            if #available(iOS 16.1, *) {
                self?.endLiveActivity()
            }
        }
    }

    private func cancelDisconnectionTimer() {
        disconnectionTimer?.invalidate()
        disconnectionTimer = nil
    }

    private func startBadPostureTimer() {
        // Cancel any existing timer
        cancelBadPostureTimer()

        // Create DispatchSourceTimer for reliable background execution
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + badPostureNotificationDelay)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            // Check if still in bad posture
            if self.postureStatus != .good {
                self.logger.log("⚠️ Bad posture detected for 5s - triggering notification", category: "ALERT")

                // Send notification if enabled
                if self.isNotificationEnabled {
                    self.sendBadPostureNotification()
                }

                self.sessionTracker.incrementAlertCount()
            }
        }
        timer.resume()
        badPostureTimer = timer
    }

    private func cancelBadPostureTimer() {
        badPostureTimer?.cancel()
        badPostureTimer = nil
    }

    func endLiveActivityIfNotMonitoring() {
        if !isMonitoring {
            if #available(iOS 16.1, *) {
                endLiveActivity()
            }
        }
    }


    private func attemptMotionRecovery() {
        guard isMonitoring else { return }

        // Cancel any existing recovery timer
        recoveryTimer?.invalidate()

        // Stop and restart motion updates after a brief delay
        recoveryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, self.isMonitoring else { return }

            print("🔄 Restarting motion updates...")
            self.motionManager.stopDeviceMotionUpdates()
            self.motionUpdateFailureCount = 0

            // Restart monitoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.isMonitoring {
                    // Re-trigger the motion updates by stopping and starting
                    let wasMonitoring = self.isMonitoring
                    self.stopMonitoring()
                    if wasMonitoring {
                        self.startMonitoring()
                    }
                }
            }
        }
    }

    deinit {
        stopMonitoring()
        cancelDisconnectionTimer()
        cancelBadPostureTimer()
        recoveryTimer?.invalidate()
        stopLoggingTimer()
        removeLifecycleObservers()
        #if targetEnvironment(simulator)
        mockMotionTimer?.invalidate()
        #endif
    }

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        // Observe when app enters background
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }

        // Observe when app enters foreground
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }

        logger.log("Lifecycle observers set up", category: "LIFECYCLE")
    }

    private func removeLifecycleObservers() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        logger.log("Lifecycle observers removed", category: "LIFECYCLE")
    }

    private func handleDidEnterBackground() {
        logger.log("📱 App entered background (monitoring: \(isMonitoring))", category: "LIFECYCLE")

        if isMonitoring {
            // Reactivate audio session to ensure it stays active
            backgroundAudio.reactivateAudioSession()

            #if !targetEnvironment(simulator)
            // Log motion manager state
            logger.log("Motion manager active: \(motionManager.isDeviceMotionActive)", category: "LIFECYCLE")
            #endif
        }
    }

    private func handleWillEnterForeground() {
        logger.log("📱 App entering foreground (monitoring: \(isMonitoring))", category: "LIFECYCLE")

        if isMonitoring {
            // Reactivate audio session
            backgroundAudio.reactivateAudioSession()

            #if !targetEnvironment(simulator)
            // Check if motion updates are still active
            if !motionManager.isDeviceMotionActive {
                logger.log("⚠️ Motion updates stopped - restarting", category: "LIFECYCLE")
                restartMotionUpdates()
            } else {
                logger.log("✅ Motion updates still active", category: "LIFECYCLE")
            }
            #endif

            // Force check connection status
            checkAvailability()
        }
    }

    private func restartMotionUpdates() {
        #if !targetEnvironment(simulator)
        logger.log("🔄 Restarting motion updates", category: "LIFECYCLE")

        // Stop existing updates
        motionManager.stopDeviceMotionUpdates()

        // Small delay before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.isMonitoring else { return }

            self.motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isConnected = false
                    self.logger.log("Motion update error: \(error.localizedDescription)", category: "ERROR")
                    return
                }

                guard let motion = motion else {
                    self.isConnected = false
                    self.logger.log("No motion data received", category: "ERROR")
                    return
                }

                // Reset failure count on successful update
                self.motionUpdateFailureCount = 0
                self.isConnected = true
                self.errorMessage = nil

                // Get pitch (forward/backward tilt) and roll (left/right tilt)
                let currentPitch = motion.attitude.pitch
                let currentRoll = motion.attitude.roll

                self.pitch = currentPitch
                self.roll = currentRoll

                // Calculate deviation from target (pitch 0, roll 0)
                let pitchDeviation = abs(currentPitch - self.targetPitch)
                let rollDeviation = abs(currentRoll - self.targetRoll)

                // Detect bad posture based on deviation magnitude
                let isForwardLean = pitchDeviation > self.pitchThreshold
                let isSidewaysLean = rollDeviation > self.rollThreshold

                let previousStatus = self.postureStatus

                if isForwardLean && isSidewaysLean {
                    self.postureStatus = .poorPosture
                } else if isForwardLean {
                    self.postureStatus = .forwardLean
                } else if isSidewaysLean {
                    self.postureStatus = .sidewaysLean
                } else {
                    self.postureStatus = .good
                }

                // Track posture time
                self.sessionTracker.updatePostureStatus(self.postureStatus)

                // Update background audio based on posture
                if self.postureStatus == .good {
                    self.backgroundAudio.setPostureState(.good)
                } else {
                    self.backgroundAudio.setPostureState(.bad)
                }

                // Handle posture status changes
                if previousStatus == .good && self.postureStatus != .good {
                    // Bad posture detected - start 5 second timer
                    self.hapticLight.impactOccurred()
                    self.startBadPostureTimer()
                } else if previousStatus != .good && self.postureStatus == .good {
                    // Posture improved - cancel timer and remove notifications
                    self.hapticSuccess.notificationOccurred(.success)
                    self.cancelBadPostureTimer()
                    self.removePostureNotifications()
                }
            }

            self.logger.log("✅ Motion updates restarted", category: "LIFECYCLE")
        }
        #endif
    }

    // MARK: - Debug Logging

    private func startLoggingTimer() {
        stopLoggingTimer()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            let appState = UIApplication.shared.applicationState
            let stateString = appState == .active ? "FG" : appState == .background ? "BG" : "INACTIVE"

            self.logger.log(
                "pitch=\(String(format: "%.3f", self.pitch)), roll=\(String(format: "%.3f", self.roll)), status=\(self.postureStatus), state=\(stateString)",
                category: "POSTURE"
            )
        }
        timer.resume()
        loggingTimer = timer
        logger.log("📊 Logging timer started", category: "DEBUG")
    }

    private func stopLoggingTimer() {
        loggingTimer?.cancel()
        loggingTimer = nil
        logger.log("📊 Logging timer stopped", category: "DEBUG")
    }

    // MARK: - Simulator Mock Data

    #if targetEnvironment(simulator)
    private func startMockMotionUpdates() {
        print("🔧 Starting mock motion updates")
        isConnected = true
        errorMessage = nil

        // Start Live Activity
        if #available(iOS 16.1, *) {
            startLiveActivity()
        }

        // Update mock data every 2 seconds
        mockMotionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isMonitoring else { return }

            // Cycle through different posture states
            self.mockPostureState = (self.mockPostureState + 1) % 10

            let previousStatus = self.postureStatus

            switch self.mockPostureState {
            case 0...5: // 60% good posture
                self.pitch = Double.random(in: -0.1...0.1)
                self.roll = Double.random(in: -0.1...0.1)
                self.postureStatus = .good
            case 6...7: // 20% forward lean
                self.pitch = Double.random(in: 0.25...0.35)
                self.roll = Double.random(in: -0.1...0.1)
                self.postureStatus = .forwardLean
            case 8: // 10% sideways lean
                self.pitch = Double.random(in: -0.1...0.1)
                self.roll = Double.random(in: 0.25...0.35)
                self.postureStatus = .sidewaysLean
            default: // 10% poor posture
                self.pitch = Double.random(in: 0.3...0.4)
                self.roll = Double.random(in: 0.2...0.3)
                self.postureStatus = .poorPosture
            }

            print("🔧 Mock: pitch=\(String(format: "%.2f", self.pitch)), roll=\(String(format: "%.2f", self.roll)), status=\(self.postureStatus)")

            // Track posture time
            self.sessionTracker.updatePostureStatus(self.postureStatus)

            // Update background audio based on posture
            if self.postureStatus == .good {
                self.backgroundAudio.setPostureState(.good)
            } else {
                self.backgroundAudio.setPostureState(.bad)
            }

            // Handle posture status changes
            if previousStatus == .good && self.postureStatus != .good {
                self.hapticLight.impactOccurred()
                self.startBadPostureTimer()
            } else if previousStatus != .good && self.postureStatus == .good {
                self.hapticSuccess.notificationOccurred(.success)
                self.cancelBadPostureTimer()
                self.removePostureNotifications()
            }
        }

        // Start session tracking
        if let dataStore = dataStore {
            sessionTracker.startSession(dataStore: dataStore)
        }
    }

    private func stopMockMotionUpdates() {
        print("🔧 Stopping mock motion updates")
        mockMotionTimer?.invalidate()
        mockMotionTimer = nil
    }
    #endif
}
