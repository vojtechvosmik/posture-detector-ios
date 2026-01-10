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

    @State private var animateIcon = false
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 24) {
            // Icon and status section
            VStack(spacing: 16) {
                ZStack {
                    // Background circle with glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    statusColor.opacity(0.4),
                                    statusColor.opacity(0.15),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(animateIcon ? 1.6 : 0.7)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animateIcon)

                    // Icon
                    Image(systemName: iconName)
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(connectionState == .connectedAndActive ? 1.05 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: connectionState)
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text(titleText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    if let deviceName = deviceName, connectionState == .connectedAndActive {
                        Text(deviceName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Text(messageText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Action buttons (only show when not connected)
            if connectionState != .connectedAndActive {
                VStack(spacing: 10) {
                    // AirPlay Route Picker Button
                    ZStack {
                        HStack(spacing: 12) {
                            Image(systemName: "airpodspro")
                                .font(.system(size: 18))

                            Text("Choose AirPods")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.trailing, 8)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        .contentShape(Rectangle())
                        .allowsHitTesting(false)
                        .disabled(true)

                        RoutePickerView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .opacity(0.1)
                    }

                    // Force connect button
                    Button(action: handleForceConnect) {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.system(size: 18))
                                .transition(.opacity.combined(with: .scale))

                            Text(isConnecting ? "Connecting..." : "Force Connect")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()

                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .foregroundStyle(.white.opacity(isConnecting ? 0.7 : 0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(isConnecting ? 0.08 : 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: isConnecting)
                    }
                    .buttonStyle(.plain)
                    .disabled(isConnecting)
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(28)
        .onAppear {
            animateIcon = true
        }
    }

    private var iconName: String {
        switch connectionState {
        case .disconnected, .connectedElsewhere:
            return "airpodspro"
        case .connectedAndActive:
            return "checkmark.circle.fill"
        }
    }

    private var titleText: String {
        switch connectionState {
        case .disconnected, .connectedElsewhere:
            return "Connect your AirPods"
        case .connectedAndActive:
            return "Connected"
        }
    }

    private var messageText: String {
        switch connectionState {
        case .connectedElsewhere, .disconnected:
            return "Use the buttons below to connect and focus your AirPods."
        case .connectedAndActive:
            return "Your posture monitoring is active"
        }
    }

    private var statusColor: Color {
        switch connectionState {
        case .disconnected, .connectedElsewhere:
            return .blue
        case .connectedAndActive:
            return .green
        }
    }

    private func handleForceConnect() {
        isConnecting = true
        onForceConnect()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isConnecting = false
        }
    }
}
