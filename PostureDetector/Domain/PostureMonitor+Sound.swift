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
        // Get the path to connected.mp3 (or create a separate bad posture sound)
        guard let soundURL = Bundle.main.url(forResource: "connected", withExtension: "mp3") else {
            print("[PostureMonitor] Failed to find sound file")
            return
        }

        do {
            // Create audio player
            let audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer.prepareToPlay()
            audioPlayer.play()

            print("[PostureMonitor] Playing bad posture sound")
        } catch {
            print("[PostureMonitor] Failed to play sound: \(error)")
        }
    }
}
