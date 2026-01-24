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

class PostureMonitor: NSObject, ObservableObject, AVAudioPlayerDelegate {
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
        }
    }
    private var badPostureTimer: Timer?
    private let badPostureNotificationDelay: TimeInterval = 5.0  // 5 seconds

    // Audio player for sound feedback
    var audioPlayer: AVAudioPlayer?

    // Background audio player to keep app alive
    private var backgroundAudioPlayer: AVAudioPlayer?

    // Background task identifier
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

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
        setupBackgroundAudio()
        setupAudioSessionNotifications()
    }

    private func setupBackgroundAudio() {
        do {
            // Configure audio session for background playback
            let audioSession = AVAudioSession.sharedInstance()

            // Use .playback category with .mixWithOthers to allow background playback
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)

            print("✅ Audio session configured successfully")

            // Create a silent audio buffer
            createSilentAudioPlayer()
        } catch {
            print("❌ Failed to setup background audio: \(error)")
        }
    }

    private func setupAudioSessionNotifications() {
        // Handle audio session interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // Handle audio session route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("⚠️ Audio session interrupted")
        case .ended:
            print("🔄 Audio session interruption ended, resuming playback")
            if isMonitoring {
                // Check if we should resume
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        // Resume audio playback
                        do {
                            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                            backgroundAudioPlayer?.play()
                            print("✅ Audio session resumed successfully")
                        } catch {
                            print("❌ Failed to resume audio: \(error)")
                        }
                    }
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("🔊 Audio route changed: \(reason.rawValue)")

        // If monitoring, ensure audio keeps playing
        if isMonitoring && backgroundAudioPlayer?.isPlaying == false {
            backgroundAudioPlayer?.play()
        }
    }

    private func createSilentAudioPlayer() {
        // Create a very short audio buffer with a quiet tone (0.5 seconds)
        let sampleRate = 44100.0
        let duration = 0.5
        let frameCount = UInt32(sampleRate * duration)
        let frequency = 440.0  // A4 note for debugging

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        // Fill with a quiet tone (for debugging)
        if let channelData = buffer.floatChannelData {
            let amplitude: Float = 0.02  // Much quieter
            for frame in 0..<Int(frameCount) {
                let value = amplitude * sin(2.0 * Float.pi * Float(frequency) * Float(frame) / Float(sampleRate))
                channelData[0][frame] = value
            }
        }

        // Export buffer to a temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("silence.caf")

        do {
            let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try file.write(from: buffer)

            // Create player from the file
            backgroundAudioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            backgroundAudioPlayer?.delegate = self
            backgroundAudioPlayer?.numberOfLoops = -1  // Loop indefinitely
            backgroundAudioPlayer?.volume = 0.05  // Very quiet, just enough to keep app alive
            backgroundAudioPlayer?.prepareToPlay()

            print("✅ Background audio player created successfully")
        } catch {
            print("Failed to create silent audio player: \(error)")
        }
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
        #if targetEnvironment(simulator)
        // Simulator mode - start mock data
        isMonitoring = true
        hapticMedium.impactOccurred()
        startMockMotionUpdates()
        #else
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Please connect AirPods Pro or AirPods Max"
            return
        }

        isMonitoring = true
        hapticMedium.impactOccurred()
        #endif

        // Start background task to prevent app suspension
        startBackgroundTask()

        // Ensure audio session is active before starting audio
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session activated")
        } catch {
            print("❌ Failed to activate audio session: \(error)")
        }

        // Start background audio to keep app alive
        if let player = backgroundAudioPlayer {
            if player.play() {
                print("✅ Background audio started playing (volume: \(player.volume))")
                print("✅ Audio is playing: \(player.isPlaying)")
            } else {
                print("❌ Failed to start background audio playback")
                // Try to recreate the player
                createSilentAudioPlayer()
                backgroundAudioPlayer?.play()
            }
        } else {
            print("❌ Background audio player is nil")
            createSilentAudioPlayer()
            backgroundAudioPlayer?.play()
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
        isMonitoring = false
        hapticMedium.impactOccurred()

        // Stop background audio
        backgroundAudioPlayer?.stop()

        // End background task
        endBackgroundTask()

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

    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Called when time expires
            print("⚠️ Background task expired, restarting...")
            self?.endBackgroundTask()
            // Restart background task
            self?.startBackgroundTask()
        }
        print("✅ Background task started: \(backgroundTask.rawValue)")
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        print("🛑 Ending background task: \(backgroundTask.rawValue)")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
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


    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("⚠️ Background audio finished playing (success: \(flag))")
        // Restart if still monitoring
        if isMonitoring && player == backgroundAudioPlayer {
            player.play()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio player decode error: \(error?.localizedDescription ?? "unknown")")
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
        NotificationCenter.default.removeObserver(self)
        stopMonitoring()
        cancelDisconnectionTimer()
        cancelBadPostureTimer()
        recoveryTimer?.invalidate()
        #if targetEnvironment(simulator)
        mockMotionTimer?.invalidate()
        #endif
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
