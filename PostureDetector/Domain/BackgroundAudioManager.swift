//
//  BackgroundAudioManager.swift
//  PostureDetector
//
//  Manages silent audio playback to keep app alive in background
//

import Foundation
import AVFoundation

class BackgroundAudioManager: NSObject, ObservableObject {
    static let shared = BackgroundAudioManager()

    private var goodPosturePlayer: AVAudioPlayer?
    private var beepPlayer: AVAudioPlayer?
    private var beepTimer: Timer?
    private var initialBeepWorkItem: DispatchWorkItem?
    private let logger = DebugLogger.shared

    @Published var currentPostureState: PostureState = .good
    @Published var isSoundEnabled: Bool = true
    @Published var alertDelay: TimeInterval = 5.0

    enum PostureState {
        case good
        case bad
    }

    private override init() {
        super.init()
        setupAudioSession()
        setupAudioSessionObservers()
    }

    deinit {
        stopBeepTimer()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use .playback with .mixWithOthers to allow other audio
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            logger.log("Audio session configured for background playback", category: "AUDIO")
        } catch {
            logger.log("Failed to setup audio session: \(error)", category: "ERROR")
        }
    }

    private func setupAudioSessionObservers() {
        // Observe audio session interruptions (calls, alarms, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // Observe route changes (headphones disconnected, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            logger.log("🔇 Audio session interrupted (call, alarm, etc.)", category: "AUDIO")
        case .ended:
            logger.log("🔊 Audio session interruption ended", category: "AUDIO")
            // Restart audio - continuous tone always plays
            reactivateAudioSession()
            goodPosturePlayer?.play()

            // Restart beep timer if in bad posture
            if currentPostureState == .bad && beepTimer == nil {
                startBeepTimer()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        logger.log("Audio route changed: \(reason.rawValue)", category: "AUDIO")
    }

    func startBackgroundAudio() {
        // Generate continuous audio tone (plays at all times)
        guard let goodAudioURL = generateAudioFile(frequency: 220.0, name: "continuous_tone.m4a") else {
            logger.log("Failed to generate continuous audio file", category: "ERROR")
            return
        }

        // Get beep sound for bad posture alerts
        guard let beepURL = Bundle.main.url(forResource: "beep", withExtension: "mp3") else {
            logger.log("Failed to find beep.mp3", category: "ERROR")
            return
        }

        do {
            // Create continuous tone player (always plays)
            goodPosturePlayer = try AVAudioPlayer(contentsOf: goodAudioURL)
            goodPosturePlayer?.delegate = self
            goodPosturePlayer?.numberOfLoops = -1
            goodPosturePlayer?.volume = 0.01 // DEBUG: Audible for testing
            goodPosturePlayer?.prepareToPlay()

            // Create beep player (layered on top during bad posture)
            beepPlayer = try AVAudioPlayer(contentsOf: beepURL)
            beepPlayer?.delegate = self
            beepPlayer?.numberOfLoops = 0 // Play once per trigger
            beepPlayer?.volume = 1.0 // Default max volume
            beepPlayer?.prepareToPlay()

            // Start continuous tone (never stops)
            let success = goodPosturePlayer?.play() ?? false
            logger.log("Continuous background tone started: \(success)", category: "AUDIO")
        } catch {
            logger.log("Failed to start background audio: \(error)", category: "ERROR")
        }
    }

    func stopBackgroundAudio() {
        goodPosturePlayer?.stop()
        beepPlayer?.stop()
        stopBeepTimer()
        goodPosturePlayer = nil
        beepPlayer = nil
        logger.log("Background audio playback stopped", category: "AUDIO")
    }

    func setPostureState(_ state: PostureState) {
        // Don't switch if already in the correct state
        if currentPostureState == state { return }

        currentPostureState = state

        switch state {
        case .good:
            // Stop beep timer, continuous tone keeps playing
            stopBeepTimer()
            logger.log("🟢 Switched to GOOD posture (continuous tone only)", category: "AUDIO")

        case .bad:
            // Keep continuous tone playing, add beep timer on top if sound enabled
            if isSoundEnabled {
                startBeepTimer()
                logger.log("🔴 Switched to BAD posture (continuous tone + beeps)", category: "AUDIO")
            } else {
                logger.log("🔴 Switched to BAD posture (beeps disabled, continuous tone only)", category: "AUDIO")
            }
        }
    }

    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
        logger.log("Sound alerts \(enabled ? "enabled" : "disabled")", category: "AUDIO")

        // If sound is disabled and we're in bad posture, stop beeping
        if !enabled && currentPostureState == .bad {
            stopBeepTimer()
            logger.log("Stopped beeping due to sound disable", category: "AUDIO")
        }

        // If sound is enabled and we're in bad posture, start beeping
        if enabled && currentPostureState == .bad && beepTimer == nil {
            startBeepTimer()
            logger.log("Started beeping due to sound enable", category: "AUDIO")
        }
    }

    func setAlertDelay(_ delay: TimeInterval) {
        alertDelay = delay
        logger.log("Sound alert delay set to \(delay)s", category: "AUDIO")

        // If we're currently in bad posture and beeping, restart the timer with new delay
        if currentPostureState == .bad && isSoundEnabled {
            startBeepTimer()
            logger.log("Restarted beep timer with new delay", category: "AUDIO")
        }
    }

    func setBeepVolume(_ volume: Float) {
        beepPlayer?.volume = volume
        logger.log("Beep volume set to \(String(format: "%.2f", volume))", category: "AUDIO")
    }

    private func startBeepTimer() {
        stopBeepTimer()

        // Schedule first beep after configured delay
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.beepPlayer?.currentTime = 0
            self.beepPlayer?.play()

            // Then continue beeping every 2 seconds
            self.beepTimer = Timer.scheduledTimer(withTimeInterval: 1.85, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.beepPlayer?.currentTime = 0
                self.beepPlayer?.play()
            }
        }

        initialBeepWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + alertDelay, execute: workItem)

        logger.log("Started beep timer (\(alertDelay)s initial delay, then 2s interval)", category: "AUDIO")
    }

    private func stopBeepTimer() {
        initialBeepWorkItem?.cancel()
        initialBeepWorkItem = nil
        beepTimer?.invalidate()
        beepTimer = nil
    }

    func reactivateAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
            logger.log("Audio session reactivated", category: "AUDIO")
        } catch {
            logger.log("Failed to reactivate audio session: \(error)", category: "ERROR")
        }
    }

    // Generate a 10-second audio file with specified frequency
    private func generateAudioFile(frequency: Double, name: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent(name)

        // If already exists, return it
        if FileManager.default.fileExists(atPath: audioURL.path) {
            return audioURL
        }

        // Create audio by generating PCM samples with a tone
        do {
            // Remove if exists
            try? FileManager.default.removeItem(at: audioURL)

            let sampleRate = 44100.0
            let duration = 10.0 // 10 seconds
            let numSamples = Int(sampleRate * duration)
            let numChannels = 1

            // Create audio format
            let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: AVAudioChannelCount(numChannels),
                interleaved: false
            )!

            // Create audio buffer with a tone at specified frequency
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples))!
            buffer.frameLength = buffer.frameCapacity

            // Generate tone - DEBUG mode (set amplitude to 0 for silent production mode)
            let amplitude: Int16 = 3000 // Low amplitude

            if let channelData = buffer.int16ChannelData {
                let samples = channelData[0]
                for i in 0..<Int(buffer.frameLength) {
                    let time = Double(i) / sampleRate
                    let value = sin(2.0 * .pi * frequency * time)
                    samples[i] = Int16(value * Double(amplitude))
                }
            }

            // Write to file
            let audioFile = try AVAudioFile(
                forWriting: audioURL,
                settings: format.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: false
            )

            try audioFile.write(from: buffer)

            logger.log("Generated audio file: \(name) (\(duration)s, \(Int(frequency))Hz)", category: "AUDIO")
            return audioURL
        } catch {
            logger.log("Error generating audio \(name): \(error)", category: "ERROR")
            return nil
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension BackgroundAudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logger.log("Silent audio finished (should not happen with loop)", category: "AUDIO")
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        logger.log("Silent audio decode error: \(error?.localizedDescription ?? "unknown")", category: "ERROR")
    }
}
