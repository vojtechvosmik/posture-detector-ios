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

class PostureMonitor: ObservableObject {
    private let motionManager = CMHeadphoneMotionManager()
    let notificationCenter = UNUserNotificationCenter.current()

    @Published var isConnected = false {
        didSet {
            // Update Live Activity when connection state changes
            if #available(iOS 16.1, *), currentActivity != nil {
                updateLiveActivity()

                // Handle disconnection timeout
                if !isConnected {
                    startDisconnectionTimer()
                } else {
                    cancelDisconnectionTimer()
                }
            }
        }
    }
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
    @Published var isNotificationEnabled = true
    @Published var isSoundEnabled = true
    private var badPostureTimer: Timer?
    private let badPostureNotificationDelay: TimeInterval = 5.0  // 5 seconds

    // Audio player for sound feedback
    var audioPlayer: AVAudioPlayer?

    // Calibration: Good posture is around pitch 0 and roll 0
    private let targetPitch: Double = 0.0
    private let targetRoll: Double = 0.0

    // Thresholds for bad posture detection (in radians)
    private let pitchThreshold: Double = 0.20  // ~20 degrees forward/backward
    private let rollThreshold: Double = 0.20   // ~15 degrees sideways

    init() {
        checkAvailability()
        requestNotificationPermission()
    }

    func setDataStore(_ dataStore: PostureDataStore) {
        self.dataStore = dataStore
    }

    func checkAvailability() {
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Headphone motion tracking not available on this device"
            return
        }
        errorMessage = nil
    }

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Please connect AirPods Pro or AirPods Max"
            return
        }

        isMonitoring = true

        // Start session tracking
        if let dataStore = dataStore {
            sessionTracker.startSession(dataStore: dataStore)
        }

        // Start Live Activity
        if #available(iOS 16.1, *) {
            startLiveActivity()
        }

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.isConnected = false

                // Update Live Activity to show disconnected state
                if #available(iOS 16.1, *) {
                    self.updateLiveActivity()
                }
                return
            }

            guard let motion = motion else {
                self.isConnected = false

                // Update Live Activity to show disconnected state
                if #available(iOS 16.1, *) {
                    self.updateLiveActivity()
                }
                return
            }

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

            // Handle posture status changes
            if previousStatus == .good && self.postureStatus != .good {
                // Bad posture detected - start 5 second timer
                self.startBadPostureTimer()
            } else if previousStatus != .good && self.postureStatus == .good {
                // Posture improved - cancel timer and remove notifications
                self.cancelBadPostureTimer()
                self.removePostureNotifications()
            }

            // Update Live Activity
            if #available(iOS 16.1, *) {
                self.updateLiveActivity()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false

        // End session tracking
        sessionTracker.endSession()

        motionManager.stopDeviceMotionUpdates()
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

        // Start new timer
        badPostureTimer = Timer.scheduledTimer(withTimeInterval: badPostureNotificationDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Check if still in bad posture
            if self.postureStatus != .good {
                // Play sound if enabled
                if self.isSoundEnabled {
                    self.playBadPostureSound()
                }

                // Send notification if enabled
                if self.isNotificationEnabled {
                    self.sendBadPostureNotification()
                }

                self.sessionTracker.incrementAlertCount()
            }
        }
    }

    private func cancelBadPostureTimer() {
        badPostureTimer?.invalidate()
        badPostureTimer = nil
    }

    func endLiveActivityIfNotMonitoring() {
        if !isMonitoring {
            if #available(iOS 16.1, *) {
                endLiveActivity()
            }
        }
    }

    deinit {
        stopMonitoring()
        cancelDisconnectionTimer()
        cancelBadPostureTimer()
    }
}
