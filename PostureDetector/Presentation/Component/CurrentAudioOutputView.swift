//
//  CurrentAudioOutputView.swift
//  PostureDetector
//
//  Shows the current audio output device
//

import SwiftUI
import AVFoundation

struct CurrentAudioOutputView: View {
    @State private var currentOutput: String = "iPhone"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: outputIcon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))

            Text("\(currentOutput)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            updateCurrentOutput()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
            updateCurrentOutput()
        }
    }

    private var outputIcon: String {
        let output = currentOutput.lowercased()

        if output.contains("airpods") {
            return "airpodspro"
        } else if output.contains("bluetooth") || output.contains("beats") {
            return "headphones"
        } else if output.contains("speaker") {
            return "speaker.wave.2.fill"
        } else {
            return "iphone"
        }
    }

    private func updateCurrentOutput() {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute

        if let output = currentRoute.outputs.first {
            currentOutput = output.portName
        } else {
            currentOutput = "iPhone"
        }
    }
}
