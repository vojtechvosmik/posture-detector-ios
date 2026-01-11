//
//  HomeScreen.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct HomeScreen: View {
    @StateObject private var postureMonitor = PostureMonitor()
    @StateObject private var bluetoothMonitor: BluetoothMonitor
    @StateObject private var dataStore = PostureDataStore()
    @State private var isSoundEnabled = true
    @State private var isNotificationEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let monitor = PostureMonitor()
        _postureMonitor = StateObject(wrappedValue: monitor)
        _bluetoothMonitor = StateObject(wrappedValue: BluetoothMonitor(postureMonitor: monitor))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                statusCard
                scoreMeterCard
                metricsCard
                settingsCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(.gray.opacity(0.05))
        .navigationTitle("Posture Detector")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            postureMonitor.setDataStore(dataStore)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                postureMonitor.endLiveActivityIfNotMonitoring()
            }
        }
    }

    @ViewBuilder private var statusCard: some View {
        ZStack {
            if let errorMessage = postureMonitor.errorMessage {
                ErrorView(message: errorMessage)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .id("error")
            } else if !postureMonitor.isConnected {
                ConnectView(
                    connectionState: bluetoothMonitor.connectionState,
                    deviceName: bluetoothMonitor.connectedDeviceName,
                    onForceConnect: {
                        bluetoothMonitor.forceConnect()
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .id("connect")
            } else {
                PostureVisualizer(
                    pitch: postureMonitor.pitch,
                    roll: postureMonitor.roll,
                    postureStatus: postureMonitor.postureStatus
                )
                .frame(height: 250)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .blur(radius: postureMonitor.isMonitoring ? 0 : 3)
                .overlay(alignment: .bottomTrailing) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            if postureMonitor.isMonitoring {
                                postureMonitor.stopMonitoring()
                            } else {
                                postureMonitor.startMonitoring()
                            }
                        }
                    }) {
                        Image(systemName: postureMonitor.isMonitoring ? "stop.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(postureMonitor.isMonitoring ? .red : .green)
                            .frame(width: 60, height: 60)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                    .padding(16)
                }
                .overlay(alignment: .bottomLeading) {
                    CurrentAudioOutputView().padding(16)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .id("posture")
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: postureMonitor.errorMessage)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: postureMonitor.isConnected)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            LinearGradient(
                gradient: Gradient(
                    colors: postureMonitor.isConnected ? postureMonitor.postureStatus.backgroundColors : PostureStatus.unknown.backgroundColors
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .background(Color.white.opacity(0.4))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder private var metricsCard: some View {
        MetricsView(
            pitch: postureMonitor.pitch,
            roll: postureMonitor.roll
        )
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder private var settingsCard: some View {
        HStack(spacing: 12) {
            GridCardToggle(
                title: "Sound",
                icon: "speaker.wave.2.fill",
                isOn: $isSoundEnabled,
                activeColors: [Color.purple, Color.purple.opacity(0.7)]
            )

            GridCardToggle(
                title: "Notify",
                icon: "bell.fill",
                isOn: $isNotificationEnabled,
                activeColors: [Color.blue, Color.blue.opacity(0.7)]
            )
        }
    }

    @ViewBuilder private var scoreMeterCard: some View {
        let score = dataStore.todayHistory.score
        let scoreColor: Color = score >= 80 ? .green : score >= 60 ? .orange : .red

        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Posture Score")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Today's performance")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)
                }

                Spacer()

                Group {
                    if #available(iOS 16.0, *) {
                        Text("\(score)")
                            .contentTransition(.numericText())
                    } else {
                        Text("\(score)")
                    }
                }
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(scoreColor)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: score)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [scoreColor, scoreColor.opacity(0.7)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (CGFloat(score) / 100.0), height: 16)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: score)
                }
            }
            .frame(height: 16)

            HStack(spacing: 16) {
                ScoreStatItem(
                    icon: "checkmark.circle.fill",
                    value: dataStore.todayHistory.goodPostureDuration,
                    label: "Good Posture",
                    color: .green
                )

                Divider()
                    .frame(height: 40)

                ScoreStatItem(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(dataStore.todayHistory.alertCount)",
                    label: "Alerts",
                    color: .orange
                )

                Divider()
                    .frame(height: 40)

                ScoreStatItem(
                    icon: scoreImprovementIcon,
                    value: dataStore.scoreImprovementPercentage,
                    label: "vs Yesterday",
                    color: scoreImprovementColor
                )
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var scoreImprovementIcon: String {
        if dataStore.scoreImprovement > 0 {
            return "chart.line.uptrend.xyaxis"
        } else if dataStore.scoreImprovement < 0 {
            return "chart.line.downtrend.xyaxis"
        } else {
            return "chart.line.flattrend.xyaxis"
        }
    }

    private var scoreImprovementColor: Color {
        if dataStore.scoreImprovement > 0 {
            return .green
        } else if dataStore.scoreImprovement < 0 {
            return .red
        } else {
            return .blue
        }
    }
}

struct ScoreStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GridCardToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let activeColors: [Color]

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                isOn.toggle()
            }
        }) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: isOn ? activeColors : [Color.gray.opacity(0.2), Color.gray.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: isOn ? activeColors[0].opacity(0.3) : Color.black.opacity(0.05), radius: 10)

                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(isOn ? .white : .gray)
                }

                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(isOn ? activeColors[0] : Color.gray)
                            .frame(width: 6, height: 6)

                        Text(isOn ? "ON" : "OFF")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isOn ? activeColors[0] : .gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

