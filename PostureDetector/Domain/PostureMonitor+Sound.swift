//
//  PostureMonitor+Sound.swift
//  PostureDetector
//
//  Sound feedback for bad posture
//

import Foundation
import AVFoundation

extension PostureMonitor {
    func playBadPostureSound() {
        guard isSoundEnabled else { return }

        // Get the path to connected.mp3 (or create a separate bad posture sound)
        guard let soundURL = Bundle.main.url(forResource: "alert", withExtension: "mp3") else {
            print("[PostureMonitor] Failed to find sound file")
            return
        }

        do {
            // DON'T change the audio session category here - keep .playback for background
            // The .playback category with .mixWithOthers already allows playing sounds

            // Create and retain audio player
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            print("[PostureMonitor] Playing bad posture sound")
        } catch {
            print("[PostureMonitor] Failed to play sound: \(error)")
        }
    }
}
