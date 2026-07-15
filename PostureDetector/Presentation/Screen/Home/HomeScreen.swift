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
    @Environment(\.scenePhase) private var scenePhase
    @State private var isFullscreen = false

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
                modeCard
                volumeCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Postura")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            postureMonitor.setDataStore(dataStore)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                postureMonitor.endLiveActivityIfNotMonitoring()
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            FullscreenVisualizerView(
                pitch: postureMonitor.pitch,
                roll: postureMonitor.roll,
                postureStatus: postureMonitor.postureStatus,
                isPresented: $isFullscreen
            )
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
                .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5))
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
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                    .padding(16)
                }
                .overlay(alignment: .bottomLeading) {
                    CurrentAudioOutputView().padding(16)
                }
                .overlay(alignment: .topTrailing) {
                    if postureMonitor.isMonitoring {
                        Button(action: {
                            isFullscreen = true
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .padding(16)
                    }
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
            .animation(.easeInOut(duration: 0.6), value: postureMonitor.postureStatus)
            .opacity(postureMonitor.isMonitoring ? 1 : 0.5)
        )
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.4))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder private var metricsCard: some View {
        MetricsView(
            pitch: postureMonitor.pitch,
            roll: postureMonitor.roll
        )
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder private var settingsCard: some View {
        HStack(spacing: 12) {
            GridCardToggle(
                title: "Sound",
                icon: "speaker.wave.2.fill",
                isOn: $postureMonitor.isSoundEnabled,
                activeColors: [Color.purple, Color.purple.opacity(0.7)]
            )

            GridCardToggle(
                title: "Notify",
                icon: "bell.fill",
                isOn: $postureMonitor.isNotificationEnabled,
                activeColors: [Color.blue, Color.blue.opacity(0.7)]
            )
        }
    }

    @ViewBuilder private var modeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header — name + one-line description of the selected mode
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)

                Text("Mode")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }

            Text(postureMonitor.effectiveMode.shortDescription)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(postureMonitor.effectiveMode)
                .transition(.opacity)

            // Mode selector — pick what you're doing, not an abstract number
            HStack(spacing: 8) {
                ForEach(PostureMode.allCases) { m in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            postureMonitor.mode = m
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: m.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(m.displayName)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(postureMonitor.mode == m ? .white : .blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            postureMonitor.mode == m ?
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)]),
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Auto-relax while walking
            Toggle(isOn: $postureMonitor.autoRelaxOnWalking) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-relax while walking")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(postureMonitor.autoWalkActive
                         ? "You're moving — detection relaxed"
                         : "Eases detection when you're on the move")
                        .font(.system(size: 12))
                        .foregroundColor(postureMonitor.autoWalkActive ? .blue : .gray)
                }
            }
            .tint(.blue)

            // Custom-only controls, revealed on demand
            if postureMonitor.mode == .custom {
                Divider()
                customControls
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: postureMonitor.mode)
        .animation(.easeInOut(duration: 0.2), value: postureMonitor.autoWalkActive)
    }

    @ViewBuilder private var customControls: some View {
        let sensitivityPercent = Int(round((0.5 - postureMonitor.customThreshold) / 0.35 * 100))

        VStack(alignment: .leading, spacing: 18) {
            // Sensitivity (higher = stricter = smaller threshold)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensitivity")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(sensitivityPercent)%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.blue)
                }

                Slider(
                    value: Binding(
                        get: { 0.5 - postureMonitor.customThreshold },
                        set: { postureMonitor.customThreshold = 0.5 - $0 }
                    ),
                    in: 0.0...0.35
                )
                .tint(.blue)

                HStack {
                    Text("Relaxed").font(.system(size: 11)).foregroundColor(.gray)
                    Spacer()
                    Text("Strict").font(.system(size: 11)).foregroundColor(.gray)
                }
            }

            // Alert delay
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Alert delay")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(Int(postureMonitor.customAlertDelay))s")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.orange)
                }

                HStack(spacing: 8) {
                    ForEach([1, 5, 10, 15, 30, 60], id: \.self) { seconds in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                postureMonitor.customAlertDelay = TimeInterval(seconds)
                            }
                        }) {
                            Text("\(seconds)s")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(postureMonitor.customAlertDelay == TimeInterval(seconds) ? .white : .orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    postureMonitor.customAlertDelay == TimeInterval(seconds) ?
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.7)]),
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)]),
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                )
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder private var volumeCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.purple)

                        Text("Alert Volume")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    Text("Volume of the beep alert sound")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)
                }

                Spacer()

                Text("\(Int(postureMonitor.beepVolume * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.purple)
            }

            HStack(spacing: 12) {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { volume in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            postureMonitor.beepVolume = Float(volume)
                        }
                    }) {
                        Text("\(Int(volume * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(postureMonitor.beepVolume == Float(volume) ? .white : .purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                postureMonitor.beepVolume == Float(volume) ?
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.7)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
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

            HStack(spacing: 12) {
                ScoreStatItem(
                    icon: "clock.fill",
                    value: dataStore.todayHistory.totalMonitoredDuration,
                    label: "Total Time",
                    color: .blue
                )

                Divider()
                    .frame(height: 40)

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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
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
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FullscreenVisualizerView: View {
    let pitch: Double
    let roll: Double
    let postureStatus: PostureStatus
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: postureStatus.backgroundColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: postureStatus)

            // Visualizer
            PostureVisualizer(
                pitch: pitch,
                roll: roll,
                postureStatus: postureStatus
            )
            .padding(40)

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding(30)
                }
                Spacer()
            }
        }
    }
}

