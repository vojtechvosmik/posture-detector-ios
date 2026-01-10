//
//  ConnectView.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct ConnectView: View {
    let connectionState: AirPodsConnectionState
    let deviceName: String?
    let onForceConnect: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            VStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 50))
                    .foregroundColor(.white)

                Text(titleText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(messageText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 10)

            Divider()
                .background(Color.white.opacity(1.8))

            if connectionState == .connectedElsewhere {
                // Show force connect button
                Button(action: onForceConnect) {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 16))

                        Text("Connect to This Device")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                }
            } else {
                // Show waiting status
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 12, height: 12)

                    Text("Waiting for AirPods..")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(25)
    }

    private var iconName: String {
        switch connectionState {
        case .disconnected:
            return "questionmark.circle.fill"
        case .connectedElsewhere:
            return "airpodspro"
        case .connectedAndActive:
            return "checkmark.circle.fill"
        }
    }

    private var titleText: String {
        switch connectionState {
        case .disconnected:
            return "Connect your AirPods"
        case .connectedElsewhere:
            return "AirPods Detected"
        case .connectedAndActive:
            return "Connected"
        }
    }

    private var messageText: String {
        switch connectionState {
        case .disconnected:
            return "To get posture tips, please connect your AirPods Pro or AirPods Max."
        case .connectedElsewhere:
            if let name = deviceName {
                return "\(name) are connected to another device. Tap below to connect them to this device."
            }
            return "Your AirPods are connected to another device. Tap below to connect them to this device."
        case .connectedAndActive:
            return "Your AirPods are ready!"
        }
    }
}
