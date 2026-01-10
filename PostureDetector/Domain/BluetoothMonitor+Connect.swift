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
        } catch {
            print("[BluetoothMonitor] Failed to setup audio session: \(error)")
        }
    }

    private func playConnectionTone() {
        // Create audio engine
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()

        // Create a short beep (440 Hz tone, 0.2 seconds)
        let sampleRate = 44100.0
        let duration = 0.2
        let frequency = 440.0
        let frameCount = UInt32(sampleRate * duration)

        // Use stereo format to match the mixer
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("[BluetoothMonitor] Failed to create audio buffer")
            return
        }

        buffer.frameLength = frameCount

        // Generate sine wave for beep in both channels
        if let data = buffer.floatChannelData {
            let amplitude: Float = 0.3
            for frame in 0..<Int(frameCount) {
                let value = Float(sin(2.0 * Double.pi * frequency * Double(frame) / sampleRate)) * amplitude
                data[0][frame] = value  // Left channel
                data[1][frame] = value  // Right channel
            }
        }

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()

            playerNode.scheduleBuffer(buffer) {
                print("[BluetoothMonitor] Connection tone playback completed")
                audioEngine.stop()

                // Recheck connection after playback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.checkConnection()
                }
            }

            playerNode.play()
            print("[BluetoothMonitor] Playing connection tone to force AirPods switch...")

        } catch {
            print("[BluetoothMonitor] Failed to play connection tone: \(error)")
        }
    }
}
