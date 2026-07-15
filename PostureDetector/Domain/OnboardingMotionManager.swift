//
//  OnboardingMotionManager.swift
//  PostureDetector
//
//  A lightweight, self-contained headphone-motion controller used during
//  onboarding. Unlike the full PostureMonitor it does not touch Live
//  Activities, background audio or notifications — it only answers two
//  questions: "are the AirPods connected?" and "where is the head right now?".
//

import Foundation
import CoreMotion
import Combine
import AVFoundation

final class OnboardingMotionManager: NSObject, ObservableObject {

    enum ConnectionState: Equatable {
        case searching          // Looking for compatible AirPods
        case connected          // AirPods connected & streaming motion
    }

    @Published private(set) var state: ConnectionState = .searching
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0

    var isConnected: Bool { state == .connected }

    private let motionManager = CMHeadphoneMotionManager()
    private var routeObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private var lastSampleTime: Date?

    #if targetEnvironment(simulator)
    private var mockTimer: Timer?
    private var mockPhase: Double = 0
    #endif

    // MARK: - Lifecycle

    func start() {
        #if targetEnvironment(simulator)
        startMockUpdates()
        #else
        setupAudioSession()
        observeRouteChanges()
        beginMotionUpdates()

        // Poll periodically so we notice drop-outs even without a route change.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.evaluateConnection()
        }
        evaluateConnection()
        #endif
    }

    func stop() {
        #if targetEnvironment(simulator)
        mockTimer?.invalidate()
        mockTimer = nil
        #else
        motionManager.stopDeviceMotionUpdates()
        pollTimer?.invalidate()
        pollTimer = nil
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        routeObserver = nil
        #endif
    }

    deinit { stop() }

    // MARK: - Calibration helper

    /// Captures the current head orientation as the neutral baseline.
    func captureCalibration() {
        CalibrationStore.save(pitch: pitch, roll: roll)
    }

    /// True when the head is roughly upright & still — a good moment to capture.
    var isHoldingStill: Bool {
        abs(pitch) < 0.12 && abs(roll) < 0.12
    }

    // MARK: - Real device

    #if !targetEnvironment(simulator)
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[OnboardingMotionManager] Audio session error: \(error)")
        }
    }

    private func observeRouteChanges() {
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateConnection()
        }
    }

    private func beginMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.lastSampleTime = Date()
            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
            if self.state != .connected {
                self.state = .connected
            }
        }
    }

    private func evaluateConnection() {
        if motionManager.isDeviceMotionAvailable {
            beginMotionUpdates()
            // Consider connected only once fresh data has actually arrived.
            if let last = lastSampleTime, Date().timeIntervalSince(last) < 3.0 {
                if state != .connected { state = .connected }
            }
        } else {
            motionManager.stopDeviceMotionUpdates()
            lastSampleTime = nil
            if state != .searching { state = .searching }
        }
    }

    /// Nudges the audio route toward AirPods by briefly playing a short tone,
    /// which often pulls AirPods away from another device onto this iPhone.
    private var forceConnectPlayer: AVAudioPlayer?
    func forceConnect() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.allowBluetoothHFP, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("[OnboardingMotionManager] forceConnect session error: \(error)")
        }

        guard let url = Bundle.main.url(forResource: "connected", withExtension: "mp3") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.play()
                self?.forceConnectPlayer = player
            } catch {
                print("[OnboardingMotionManager] forceConnect play error: \(error)")
            }
            self?.evaluateConnection()
        }
    }
    #else
    func forceConnect() { /* no-op in simulator */ }
    #endif

    // MARK: - Simulator

    #if targetEnvironment(simulator)
    private func startMockUpdates() {
        // Pretend AirPods connect a beat after we start looking.
        state = .searching
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.state = .connected
        }

        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.mockPhase += 0.1
            // Gentle idle sway so the live visual feels alive.
            self.pitch = sin(self.mockPhase * 0.6) * 0.06
            self.roll = cos(self.mockPhase * 0.4) * 0.05
        }
    }
    #endif
}
