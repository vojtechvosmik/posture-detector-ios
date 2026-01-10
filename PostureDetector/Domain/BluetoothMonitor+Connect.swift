//
//  BluetoothMonitor+Connect.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import Foundation
import AVFoundation
import Combine
import CoreMotion
import AudioToolbox

extension BluetoothMonitor {

    // Force connect by playing a short beep sound
    func forceConnect() {
        print("[BluetoothMonitor] Force connecting to AirPods by playing audio...")

        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Override to route audio to Bluetooth (AirPods)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .allowBluetoothA2DP])
            try audioSession.overrideOutputAudioPort(.none) // Don't force speaker
            try audioSession.setActive(true)

            // Small delay to let the audio route switch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.playConnectionTone()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.playConnectionTone()
            }
        } catch {
            print("[BluetoothMonitor] Failed to setup audio session: \(error)")
        }
    }

    private func playConnectionTone() {
        // Get the path to connected.mp3
        guard let soundURL = Bundle.main.url(forResource: "connected", withExtension: "mp3") else {
            print("[BluetoothMonitor] Failed to find connected.mp3")
            return
        }

        do {
            // Create audio player
            let audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer.prepareToPlay()
            audioPlayer.play()

            print("[BluetoothMonitor] Playing connected.mp3 to force AirPods switch...")

            // Recheck connection after playback (estimated duration)
            DispatchQueue.main.asyncAfter(deadline: .now() + audioPlayer.duration + 0.5) { [weak self] in
                self?.checkConnection()
            }
        } catch {
            print("[BluetoothMonitor] Failed to play connected.mp3: \(error)")
        }
    }
}
