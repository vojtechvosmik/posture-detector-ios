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

class PostureMonitor: ObservableObject {
    private let motionManager = CMHeadphoneMotionManager()
    let notificationCenter = UNUserNotificationCenter.current()

    @Published var isConnected = false
    @Published var postureStatus: PostureStatus = .unknown
    @Published var pitch: Double = 0.0  // Forward/backward tilt
    @Published var roll: Double = 0.0   // Left/right tilt
    @Published var errorMessage: String?

    // Live Activity
    #if canImport(ActivityKit)
    var currentActivity: Any?  // Activity<PostureAttributes> on iOS 16.1+
    #endif

    // Calibration: Good posture is around pitch 0 and roll 0
    private let targetPitch: Double = 0.0
    private let targetRoll: Double = 0.0

    // Thresholds for bad posture detection (in radians)
    private let pitchThreshold: Double = 0.20  // ~20 degrees forward/backward
    private let rollThreshold: Double = 0.20   // ~15 degrees sideways

    // Notification throttling
    var lastNotificationTime: Date?
    let notificationCooldown: TimeInterval = 60  // Send notification max once per minute

    init() {
        checkAvailability()
        requestNotificationPermission()
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

        // Start Live Activity
        if #available(iOS 16.1, *) {
            startLiveActivity()
        }

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.isConnected = false
                return
            }

            guard let motion = motion else {
                self.isConnected = false
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
            print("[PostureMonitor] pitchDeviation: \(pitchDeviation), rollDeviation: \(rollDeviation)")

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

            // Send notification if posture changed to bad
            if previousStatus == .good && self.postureStatus != .good {
                self.sendBadPostureNotification()
            }

            // Update Live Activity
            if #available(iOS 16.1, *) {
                self.updateLiveActivity()
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isConnected = false
        postureStatus = .unknown

        if #available(iOS 16.1, *) {
            endLiveActivity()
        }
    }

    deinit {
        stopMonitoring()
    }
}
