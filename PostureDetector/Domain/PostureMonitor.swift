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

// MARK: - Posture Mode

/// A usage context the user (or auto-detection) picks. Each mode bundles the
/// detection strictness, how long bad posture must persist before alerting, and
/// the sound-alert delay — so the user chooses *what they're doing* instead of
/// an abstract "sensitivity" number.
enum PostureMode: Int, CaseIterable, Identifiable {
    case desk = 0       // sitting at a computer — strict, quick correction
    case relaxed = 1    // couch / reading / multi-monitor desks — lenient, fewer nags
    case active = 2     // walking / on the go — ignores head sway, catches text-neck
    case custom = 3     // power users dial in their own numbers

    var id: Int { rawValue }

    /// The three presets offered as choices (Custom is configured, not "picked").
    static var presets: [PostureMode] { [.desk, .relaxed, .active] }

    var displayName: String {
        switch self {
        case .desk: return "Desk"
        case .relaxed: return "Relaxed"
        case .active: return "Active"
        case .custom: return "Custom"
        }
    }

    var shortDescription: String {
        switch self {
        case .desk: return "Precise correction while working at a computer."
        case .relaxed: return "Easygoing — for the couch, TV, or turning between several monitors."
        case .active: return "Ignores natural head movement while you walk."
        case .custom: return "Set your own detection thresholds."
        }
    }

    var icon: String {
        switch self {
        case .desk: return "desktopcomputer"
        case .relaxed: return "book.fill"
        case .active: return "figure.walk"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// Fixed parameters for the presets. `custom` returns nil — its parameters
    /// live on the monitor because the user edits them.
    var presetParameters: PostureModeParameters? {
        switch self {
        case .desk:    return PostureModeParameters(pitchThreshold: 0.24, rollThreshold: 0.24, monitorsRoll: true,  graceDuration: 5,  alertDelay: 5)
        case .relaxed: return PostureModeParameters(pitchThreshold: 0.34, rollThreshold: 0.36, monitorsRoll: true,  graceDuration: 10, alertDelay: 10)
        case .active:  return PostureModeParameters(pitchThreshold: 0.50, rollThreshold: 0.60, monitorsRoll: false, graceDuration: 20, alertDelay: 30)
        case .custom:  return nil
        }
    }
}

/// The concrete knobs a mode resolves to. Detection reads these, never the mode.
struct PostureModeParameters {
    var pitchThreshold: Double        // forward-lean threshold (radians from neutral)
    var rollThreshold: Double         // sideways-lean threshold (radians from neutral)
    var monitorsRoll: Bool            // Active disables roll — side sway while walking is noise
    var graceDuration: TimeInterval   // how long bad posture must persist before notifying
    var alertDelay: TimeInterval      // delay before the sound alert starts
}

class PostureMonitor: NSObject, ObservableObject {
    private let motionManager = CMHeadphoneMotionManager()
    let notificationCenter = UNUserNotificationCenter.current()

    #if targetEnvironment(simulator)
    @Published var isConnected = true {
        didSet {
            // Only update if the connection state actually changed
            guard oldValue != isConnected else { return }

            handleConnectionStateChange()
        }
    }
    #else
    @Published var isConnected = false {
        didSet {
            // Only update if the connection state actually changed
            guard oldValue != isConnected else { return }

            handleConnectionStateChange()
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
    /// True while a session is paused specifically because the AirPods dropped.
    private var pausedByDisconnect = false

    var currentActivity: Any?  // Activity<PostureAttributes> on iOS 16.1+
    var liveActivityStartTime: Date?
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
    @Published var beepVolume: Float {
        didSet {
            UserDefaults.standard.set(beepVolume, forKey: "beepVolume")
            // Update background audio manager
            backgroundAudio.setBeepVolume(beepVolume)
        }
    }
    private var badPostureTimer: DispatchSourceTimer?

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
    private var toggleMonitoringObserver: NSObjectProtocol?

    // Calibration: the user's neutral head position, captured during onboarding
    // (or later re-calibrated). Falls back to 0 when never calibrated.
    private var targetPitch: Double { CalibrationStore.pitch }
    private var targetRoll: Double { CalibrationStore.roll }

    /// Re-captures the current head orientation as the neutral baseline.
    func recalibrate() {
        CalibrationStore.save(pitch: pitch, roll: roll)
        hapticSuccess.notificationOccurred(.success)
        logger.log("🎯 Recalibrated to pitch=\(pitch), roll=\(roll)", category: "MONITOR")
    }

    // MARK: - Posture mode

    /// The user's chosen usage context. Drives detection strictness, grace and
    /// alert timing through `effectiveParameters`.
    @Published var mode: PostureMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "postureMode")
            applyEffectiveParameters()
        }
    }

    /// Custom-mode detection threshold (radians), applied to both pitch & roll.
    @Published var customThreshold: Double {
        didSet {
            UserDefaults.standard.set(customThreshold, forKey: "customThreshold")
            if mode == .custom { applyEffectiveParameters() }
        }
    }

    /// Custom-mode sound alert delay (seconds).
    @Published var customAlertDelay: TimeInterval {
        didSet {
            UserDefaults.standard.set(customAlertDelay, forKey: "customAlertDelay")
            if mode == .custom { applyEffectiveParameters() }
        }
    }

    /// When on, sustained walking temporarily switches detection to Active so
    /// natural head movement doesn't trigger alerts. Reverts once you stop.
    @Published var autoRelaxOnWalking: Bool {
        didSet {
            UserDefaults.standard.set(autoRelaxOnWalking, forKey: "autoRelaxOnWalking")
            guard isMonitoring else { return }
            if autoRelaxOnWalking {
                startWalkDetection()
            } else {
                stopWalkDetection()
            }
        }
    }

    /// True while auto-detection currently sees you moving (walking/running/etc).
    @Published private(set) var autoWalkActive = false

    // MARK: Debug telemetry (surfaced by the live debug screen)

    /// When the current stretch of bad posture began (nil while good). The debug
    /// screen uses this + `effectiveParameters.graceDuration` to draw a live
    /// countdown to the alert.
    @Published private(set) var badPostureStartedAt: Date?
    /// When the most recent posture alert actually fired.
    @Published private(set) var lastAlertFiredAt: Date?
    /// Human-readable current motion activity (e.g. "Walking · high").
    @Published private(set) var currentActivityDescription: String = "—"

    /// The mode detection actually runs with right now — Active while auto-walk
    /// is engaged, otherwise the user's chosen mode.
    var effectiveMode: PostureMode {
        (autoRelaxOnWalking && autoWalkActive) ? .active : mode
    }

    /// Concrete detection parameters for the current effective mode.
    var effectiveParameters: PostureModeParameters {
        if let preset = effectiveMode.presetParameters { return preset }
        // Custom: user-set threshold, fixed grace, roll monitored.
        return PostureModeParameters(
            pitchThreshold: customThreshold,
            rollThreshold: customThreshold,
            monitorsRoll: true,
            graceDuration: 5,
            alertDelay: customAlertDelay
        )
    }

    // Auto-walk detection: CMPedometer is the responsive primary signal (counts
    // steps in near-real-time and works even hand-held); CMMotionActivity adds
    // context and catches cycling/automotive.
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private var isWalkDetecting = false
    private var walkReleaseTimer: Timer?
    private var lastPedometerSteps = 0

    /// Engaged while steps are actively accruing (fast, reliable).
    private var walkingByPedometer = false { didSet { recomputeAutoWalk() } }
    /// Engaged when Core Motion's activity classifier reports sustained movement.
    private var movingByActivity = false { didSet { recomputeAutoWalk() } }

    override init() {
        // Load saved preferences
        self.isNotificationEnabled = UserDefaults.standard.object(forKey: "isNotificationEnabled") as? Bool ?? true
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "isSoundEnabled") as? Bool ?? true
        self.beepVolume = UserDefaults.standard.object(forKey: "beepVolume") as? Float ?? 1.0
        self.customThreshold = UserDefaults.standard.object(forKey: "customThreshold") as? Double ?? 0.24
        self.customAlertDelay = UserDefaults.standard.object(forKey: "customAlertDelay") as? TimeInterval ?? 5.0
        self.autoRelaxOnWalking = UserDefaults.standard.object(forKey: "autoRelaxOnWalking") as? Bool ?? true

        // Resolve the active mode, migrating legacy "sensitivity" users.
        if let modeRaw = UserDefaults.standard.object(forKey: "postureMode") as? Int,
           let saved = PostureMode(rawValue: modeRaw) {
            self.mode = saved
        } else if let legacy = UserDefaults.standard.object(forKey: "sensitivity") as? Int {
            // low → relaxed, medium/high → desk (there's no stricter preset)
            self.mode = (legacy == 0) ? .relaxed : .desk
        } else {
            self.mode = .desk
        }

        super.init()
        checkAvailability()
        requestNotificationPermission()
        setupLifecycleObservers()
    }

    /// Pushes the current effective mode's alert timing to the audio engine.
    private func applyEffectiveParameters() {
        backgroundAudio.setAlertDelay(effectiveParameters.alertDelay)
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
        backgroundAudio.setAlertDelay(effectiveParameters.alertDelay)
        backgroundAudio.setBeepVolume(beepVolume)
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

        pausedByDisconnect = false

        // Start session tracking
        if let dataStore = dataStore {
            sessionTracker.startSession(dataStore: dataStore)
        }

        #if !targetEnvironment(simulator)
        // Start or update Live Activity
        if #available(iOS 16.1, *) {
            if currentActivity != nil {
                // Update existing Live Activity
                updateLiveActivityState()
            } else {
                // Create new Live Activity
                startLiveActivity()
            }
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

            self.evaluatePosture(currentPitch: motion.attitude.pitch,
                                 currentRoll: motion.attitude.roll)
        }

        // Begin auto-walk detection (no-op if unavailable or disabled)
        startWalkDetection()
        #endif
    }

    // MARK: - Posture evaluation (shared)

    /// Single source of truth for turning a raw (pitch, roll) sample into a
    /// posture status, using the current effective mode's parameters. Used by
    /// both the initial and the restarted motion-update streams.
    private func evaluatePosture(currentPitch: Double, currentRoll: Double) {
        self.pitch = currentPitch
        self.roll = currentRoll

        let params = effectiveParameters

        // Deviation from the user's calibrated neutral position.
        let pitchDeviation = abs(currentPitch - targetPitch)
        let rollDeviation = abs(currentRoll - targetRoll)

        let isForwardLean = pitchDeviation > params.pitchThreshold
        // Active mode disables roll — side sway while walking is noise, not slouch.
        let isSidewaysLean = params.monitorsRoll && rollDeviation > params.rollThreshold

        let previousStatus = postureStatus

        if isForwardLean && isSidewaysLean {
            postureStatus = .poorPosture
        } else if isForwardLean {
            postureStatus = .forwardLean
        } else if isSidewaysLean {
            postureStatus = .sidewaysLean
        } else {
            postureStatus = .good
        }

        handlePostureTransition(previousStatus: previousStatus)
    }

    /// Reacts to a posture status change: tracking, audio, haptics and the
    /// grace timer that eventually fires a notification.
    private func handlePostureTransition(previousStatus: PostureStatus) {
        // Track posture time
        sessionTracker.currentMode = effectiveMode
        sessionTracker.updatePostureStatus(postureStatus)

        // Update background audio based on posture
        backgroundAudio.setPostureState(postureStatus == .good ? .good : .bad)

        if previousStatus == .good && postureStatus != .good {
            // Bad posture just started — begin the grace timer
            hapticLight.impactOccurred()
            startBadPostureTimer()
            sessionTracker.beginEpisode()
        } else if previousStatus != .good && postureStatus == .good {
            // Posture improved — cancel timer and remove notifications
            hapticSuccess.notificationOccurred(.success)
            cancelBadPostureTimer()
            removePostureNotifications()
            sessionTracker.closeEpisode()
        }
    }

    // MARK: - Auto-walk detection

    /// Starts motion-activity updates so sustained walking can relax detection.
    /// Prompts for Motion & Fitness permission on first use; degrades silently
    /// if unavailable or denied.
    private func startWalkDetection() {
        guard autoRelaxOnWalking, !isWalkDetecting else { return }
        isWalkDetecting = true

        logMotionAuthorization()

        // Pedometer — responsive walking detection via live step updates. Steps
        // are counted in near-real-time and register even with the phone in hand.
        if CMPedometer.isStepCountingAvailable() {
            lastPedometerSteps = 0
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                let steps = data.numberOfSteps.intValue
                DispatchQueue.main.async {
                    // New steps since the last callback → the user is walking now.
                    guard steps > self.lastPedometerSteps else { return }
                    self.lastPedometerSteps = steps
                    self.walkingByPedometer = true
                    self.scheduleWalkRelease()
                    if !self.movingByActivity {
                        let cadence = data.currentCadence?.doubleValue ?? 0
                        self.currentActivityDescription = cadence > 0
                            ? "Walking · \(String(format: "%.1f", cadence)) st/s"
                            : "Walking · steps"
                    }
                }
            }
        } else {
            logger.log("Pedometer step counting unavailable", category: "MOTION")
        }

        // Activity classifier — adds context and catches cycling / driving.
        // Permissive on engaging (any confidence), conservative on releasing.
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self = self, let activity = activity else { return }
                self.currentActivityDescription = Self.describe(activity)
                let moving = activity.walking || activity.running || activity.automotive || activity.cycling
                if moving {
                    self.movingByActivity = true
                } else if activity.stationary && activity.confidence != .low {
                    self.movingByActivity = false
                }
            }
        }

        logger.log("🚶 Auto-walk detection started", category: "MOTION")
    }

    private func stopWalkDetection() {
        guard isWalkDetecting else { return }
        isWalkDetecting = false
        pedometer.stopUpdates()
        activityManager.stopActivityUpdates()
        walkReleaseTimer?.invalidate()
        walkReleaseTimer = nil
        walkingByPedometer = false
        movingByActivity = false
        currentActivityDescription = "—"
        logger.log("🚶 Auto-walk detection stopped", category: "MOTION")
    }

    /// Releases the pedometer "walking" flag after a few quiet seconds without
    /// new steps, so a brief pause doesn't immediately snap back to strict mode.
    private func scheduleWalkRelease() {
        walkReleaseTimer?.invalidate()
        walkReleaseTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            self?.walkingByPedometer = false
        }
    }

    /// Active whenever either signal currently sees movement; reverts only once
    /// both are quiet.
    private func recomputeAutoWalk() {
        setAutoWalkActive(walkingByPedometer || movingByActivity)
    }

    /// Flips the auto-walk override and re-applies alert timing when it changes.
    private func setAutoWalkActive(_ active: Bool) {
        guard autoWalkActive != active else { return }
        autoWalkActive = active
        logger.log("🚶 Auto-walk \(active ? "engaged → Active mode" : "released")", category: "MOTION")
        applyEffectiveParameters()
    }

    /// Logs (and surfaces, when off) the Motion & Fitness authorization — the
    /// most common reason auto-walk silently does nothing.
    private func logMotionAuthorization() {
        let status = CMMotionActivityManager.authorizationStatus()
        let name: String
        switch status {
        case .authorized: name = "authorized"
        case .denied: name = "denied"
        case .restricted: name = "restricted"
        case .notDetermined: name = "notDetermined"
        @unknown default: name = "unknown"
        }
        logger.log("Motion & Fitness authorization: \(name)", category: "MOTION")
        if status == .denied || status == .restricted {
            currentActivityDescription = "Motion & Fitness off"
        }
    }

    private static func describe(_ activity: CMMotionActivity) -> String {
        let confidence: String
        switch activity.confidence {
        case .low: confidence = "low"
        case .medium: confidence = "medium"
        case .high: confidence = "high"
        @unknown default: confidence = "?"
        }
        let state: String
        if activity.walking { state = "Walking" }
        else if activity.running { state = "Running" }
        else if activity.cycling { state = "Cycling" }
        else if activity.automotive { state = "Automotive" }
        else if activity.stationary { state = "Stationary" }
        else { state = "Unknown" }
        return "\(state) · \(confidence)"
    }

    /// Debug-only override that forces (or releases) the auto-walk state so the
    /// live debug screen can exercise the Active-mode behaviour without walking.
    func debugForceAutoWalk(_ on: Bool) {
        setAutoWalkActive(on)
    }

    func stopMonitoring(keepLiveActivity: Bool = false) {
        logger.log("🔴 Stopping monitoring", category: "MONITOR")

        isMonitoring = false
        hapticMedium.impactOccurred()

        // First thing, while the app still holds background execution: the
        // silent audio below is what keeps us alive, and once it stops the
        // system can suspend us before an async Live Activity update lands.
        if #available(iOS 16.1, *), keepLiveActivity {
            updateLiveActivityState()
        }

        // Stop debug logging timer
        stopLoggingTimer()

        // Cancel any pending bad posture timer
        cancelBadPostureTimer()

        // Remove any pending bad posture notifications
        removePostureNotifications()

        // Stop silent audio
        backgroundAudio.stopBackgroundAudio()
        logger.log("Stopped silent audio", category: "BACKGROUND")

        // Stop auto-walk detection
        stopWalkDetection()

        // End session tracking
        sessionTracker.endSession()

        #if targetEnvironment(simulator)
        stopMockMotionUpdates()
        #else
        motionManager.stopDeviceMotionUpdates()
        #endif

        postureStatus = .unknown

        if #available(iOS 16.1, *) {
            if !keepLiveActivity {
                // End Live Activity completely
                endLiveActivity()
            }
        }
    }

    private func handleConnectionStateChange() {
        if !isConnected {
            // AirPods disconnected
            logger.log("🎧 AirPods disconnected", category: "CONNECTION")

            // Pause monitoring if currently running
            if isMonitoring {
                pausedByDisconnect = true
                stopMonitoring(keepLiveActivity: true)
                logger.log("⏸️ Monitoring paused due to AirPods disconnection", category: "CONNECTION")

                // Send notification
                sendAirPodsDisconnectedNotification()
            }

            // Start timer to end Live Activity after 60s if not reconnected
            if #available(iOS 16.1, *), currentActivity != nil {
                startDisconnectionTimer()
            }
        } else {
            // AirPods reconnected
            logger.log("🎧 AirPods reconnected", category: "CONNECTION")
            cancelDisconnectionTimer()

            // Only nudge when a disconnect is what stopped the session.
            if pausedByDisconnect && !isMonitoring {
                sendAirPodsReconnectedNotification()
                logger.log("🔔 Reminded to restart tracking", category: "CONNECTION")
            }
            pausedByDisconnect = false
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

        // Create DispatchSourceTimer for reliable background execution.
        // Grace period comes from the current mode — Active waits much longer so
        // transient movement while walking doesn't fire a notification.
        badPostureStartedAt = Date()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + effectiveParameters.graceDuration)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            // Check if still in bad posture
            if self.postureStatus != .good {
                self.logger.log("⚠️ Bad posture sustained for \(self.effectiveParameters.graceDuration)s - triggering notification", category: "ALERT")

                // Send notification if enabled
                if self.isNotificationEnabled {
                    self.sendBadPostureNotification()
                }

                self.lastAlertFiredAt = Date()
                self.sessionTracker.incrementAlertCount()
            }
        }
        timer.resume()
        badPostureTimer = timer
    }

    private func cancelBadPostureTimer() {
        badPostureTimer?.cancel()
        badPostureTimer = nil
        badPostureStartedAt = nil
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

        // Observe toggle monitoring from Live Activity using Darwin notifications
        let notificationName = "cz.peachdev.postureplus.toggleMonitoring" as CFString
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let monitor = Unmanaged<PostureMonitor>.fromOpaque(observer).takeUnretainedValue()

                DispatchQueue.main.async {
                    monitor.handleToggleMonitoringFromLiveActivity()
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )

        logger.log("Lifecycle observers set up (including Darwin notifications)", category: "LIFECYCLE")
    }

    private func removeLifecycleObservers() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Remove Darwin notification observer
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            CFNotificationName("cz.peachdev.postureplus.toggleMonitoring" as CFString),
            nil
        )

        logger.log("Lifecycle observers removed", category: "LIFECYCLE")
    }

    private func handleToggleMonitoringFromLiveActivity() {
        logger.log("🔄 Toggle monitoring requested from Live Activity", category: "LIFECYCLE")

        if isMonitoring {
            // Stop monitoring but keep Live Activity alive
            stopMonitoring(keepLiveActivity: true)
        } else {
            // Start monitoring and update Live Activity
            startMonitoring()
            if #available(iOS 16.1, *) {
                updateLiveActivityState()
            }
        }
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

                self.evaluatePosture(currentPitch: motion.attitude.pitch,
                                     currentRoll: motion.attitude.roll)
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

        // Start or update Live Activity
        if #available(iOS 16.1, *) {
            if currentActivity != nil {
                // Update existing Live Activity
                updateLiveActivityState()
            } else {
                // Create new Live Activity
                startLiveActivity()
            }
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

            self.handlePostureTransition(previousStatus: previousStatus)
        }

        pausedByDisconnect = false

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
