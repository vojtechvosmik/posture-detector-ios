//
//  HomeScreen.swift
//  PostureDetector
//
//  Cohesive "aurora" home that adapts to light & dark: a living gradient
//  backdrop, a glowing posture-radar hero, and frosted glass cards.
//

import SwiftUI

struct HomeScreen: View {
    @StateObject private var postureMonitor = PostureMonitor()
    @StateObject private var bluetoothMonitor: BluetoothMonitor
    @ObservedObject private var dataStore = PostureDataStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme
    @State private var isFullscreen = false

    init() {
        let monitor = PostureMonitor()
        _postureMonitor = StateObject(wrappedValue: monitor)
        _bluetoothMonitor = StateObject(wrappedValue: BluetoothMonitor(postureMonitor: monitor))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                heroCard
                scoreCard
                togglesRow
                modeCard
                volumeCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(AuraBackground())
        .navigationTitle("Postura")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { postureMonitor.setDataStore(dataStore) }
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

    // MARK: - Hero

    private var statusTint: Color {
        switch postureMonitor.postureStatus {
        case .good: return Aura.green
        case .forwardLean, .sidewaysLean, .poorPosture: return Aura.coral
        case .unknown: return Aura.accent
        }
    }

    @ViewBuilder private var heroCard: some View {
        ZStack {
            // Soft status-tinted glow behind the radar
            Circle()
                .fill(statusTint)
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .opacity(heroGlowOpacity)
                .offset(y: -70)
                .animation(.easeInOut(duration: 0.6), value: postureMonitor.postureStatus)

            if let errorMessage = postureMonitor.errorMessage {
                heroMessage(icon: "exclamationmark.triangle.fill",
                            title: "Something's off", subtitle: errorMessage)
            } else if !postureMonitor.isConnected {
                connectState
            } else {
                liveState
            }
        }
        .frame(height: 380)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Aura.cardStroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.22 : 0.08), radius: 16, x: 0, y: 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: postureMonitor.isConnected)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: postureMonitor.errorMessage)
    }

    private var heroGlowOpacity: Double {
        let base = scheme == .dark ? 0.30 : 0.20
        return postureMonitor.isMonitoring ? base : base * 0.4
    }

    private var liveState: some View {
        VStack(spacing: 0) {
            HStack {
                scoreBadge
                Spacer()
                if postureMonitor.isMonitoring {
                    heroIconButton("arrow.up.left.and.arrow.down.right") { isFullscreen = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            Spacer(minLength: 4)

            PostureVisualizer(pitch: postureMonitor.pitch,
                              roll: postureMonitor.roll,
                              postureStatus: postureMonitor.postureStatus)
                .frame(height: 188)
                .opacity(postureMonitor.isMonitoring ? 1 : 0.5)
                .blur(radius: postureMonitor.isMonitoring ? 0 : 2)

            Spacer(minLength: 4)

            VStack(spacing: 4) {
                Text(statusHeadline).font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
                Text(statusSubtitle).font(.system(size: 14)).foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .animation(.easeInOut(duration: 0.3), value: postureMonitor.postureStatus)
            .animation(.easeInOut(duration: 0.3), value: postureMonitor.isMonitoring)

            Spacer(minLength: 8)

            playStopButton.padding(.bottom, 20)
        }
    }

    private var scoreBadge: some View {
        let score = dataStore.todayHistory.score
        return HStack(spacing: 7) {
            Circle().fill(Aura.scoreColor(score)).frame(width: 7, height: 7)
            Text("Today").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
            Text("\(score)").font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Aura.softFill, in: Capsule())
        .overlay(Capsule().stroke(Aura.cardStroke, lineWidth: 1))
    }

    private var playStopButton: some View {
        let on = postureMonitor.isMonitoring
        return Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if on { postureMonitor.stopMonitoring() } else { postureMonitor.startMonitoring() }
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            HStack(spacing: 10) {
                Image(systemName: on ? "stop.fill" : "play.fill").font(.system(size: 16, weight: .bold))
                Text(on ? "Stop" : "Start").font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(width: 156, height: 54)
            .background(
                LinearGradient(colors: on
                               ? [Color(red: 1.0, green: 0.42, blue: 0.42), Color(red: 0.90, green: 0.26, blue: 0.36)]
                               : [Color(red: 0.20, green: 0.78, blue: 0.52), Color(red: 0.13, green: 0.64, blue: 0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .shadow(color: (on ? Color.red : Color.green).opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func heroIconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 38, height: 38)
                .background(Aura.softFill, in: Circle())
                .overlay(Circle().stroke(Aura.cardStroke, lineWidth: 1))
        }
    }

    private func heroMessage(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44)).foregroundColor(statusTint)
            Text(title).font(.system(size: 20, weight: .bold)).foregroundColor(.primary)
            Text(subtitle).font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }

    private var connectState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Aura.accent).frame(width: 96, height: 96).blur(radius: 30).opacity(0.4)
                Image(systemName: "airpodspro").font(.system(size: 46)).foregroundColor(.primary)
            }
            Text("Connect your AirPods").font(.system(size: 20, weight: .bold)).foregroundColor(.primary)
            Text("Pop them in and pick them as the audio output.")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 34)
            Button(action: { bluetoothMonitor.forceConnect() }) {
                Text("Not connecting? Tap to nudge them over")
                    .font(.system(size: 13, weight: .medium)).foregroundColor(Aura.accent)
            }
            .padding(.top, 4)
        }
    }

    private var statusHeadline: String {
        guard postureMonitor.isMonitoring else { return "Ready when you are" }
        switch postureMonitor.postureStatus {
        case .good: return "Good posture"
        case .forwardLean: return "Sit up straight"
        case .sidewaysLean: return "Level your head"
        case .poorPosture: return "Fix your posture"
        case .unknown: return "Reading…"
        }
    }

    private var statusSubtitle: String {
        guard postureMonitor.isMonitoring else { return "Tap start to begin tracking" }
        switch postureMonitor.postureStatus {
        case .good: return "Keep it up — you're aligned"
        case .forwardLean: return "You're leaning forward"
        case .sidewaysLean: return "You're tilting to one side"
        case .poorPosture: return "Head forward and tilted"
        case .unknown: return "Getting a signal from your AirPods"
        }
    }

    // MARK: - Score

    private var scoreCard: some View {
        let score = dataStore.todayHistory.score
        let scoreColor = Aura.scoreColor(score)

        return VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Posture Score").font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                    Text("Today's performance").font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(score)").font(.system(size: 36, weight: .bold)).foregroundColor(scoreColor)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: score)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Aura.softFill).frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(colors: [scoreColor, scoreColor.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(12, geo.size.width * CGFloat(score) / 100.0), height: 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: score)
                }
            }
            .frame(height: 12)

            HStack(spacing: 10) {
                statItem("clock.fill", dataStore.todayHistory.totalMonitoredDuration, "Total", Aura.accent)
                statDivider
                statItem("checkmark.circle.fill", dataStore.todayHistory.goodPostureDuration, "Good", Aura.green)
                statDivider
                statItem("exclamationmark.triangle.fill", "\(dataStore.todayHistory.alertCount)", "Alerts", Aura.orange)
                statDivider
                statItem(scoreImprovementIcon, dataStore.scoreImprovementPercentage, "vs Yest.", scoreImprovementColor)
            }
        }
        .auraCard()
    }

    private var statDivider: some View {
        Rectangle().fill(Aura.hairline).frame(width: 1, height: 38)
    }

    private func statItem(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(color)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var scoreImprovementIcon: String {
        if dataStore.scoreImprovement > 0 { return "chart.line.uptrend.xyaxis" }
        if dataStore.scoreImprovement < 0 { return "chart.line.downtrend.xyaxis" }
        return "chart.line.flattrend.xyaxis"
    }

    private var scoreImprovementColor: Color {
        if dataStore.scoreImprovement > 0 { return Aura.green }
        if dataStore.scoreImprovement < 0 { return Aura.coral }
        return Aura.accent
    }

    // MARK: - Quick toggles

    private var togglesRow: some View {
        HStack(spacing: 16) {
            glassToggle(title: "Sound", icon: "speaker.wave.2.fill",
                        isOn: $postureMonitor.isSoundEnabled, tint: Aura.purple)
            glassToggle(title: "Notify", icon: "bell.fill",
                        isOn: $postureMonitor.isNotificationEnabled, tint: Aura.accent)
        }
    }

    private func glassToggle(title: String, icon: String, isOn: Binding<Bool>, tint: Color) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { isOn.wrappedValue.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isOn.wrappedValue
                              ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Aura.softFill))
                        .frame(width: 60, height: 60)
                        .shadow(color: isOn.wrappedValue ? tint.opacity(0.4) : .clear, radius: 12)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(isOn.wrappedValue ? .white : .secondary)
                }
                VStack(spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    HStack(spacing: 6) {
                        Circle().fill(isOn.wrappedValue ? tint : Color.secondary).frame(width: 6, height: 6)
                        Text(isOn.wrappedValue ? "ON" : "OFF")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isOn.wrappedValue ? tint : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .auraCard(padding: 0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 16, weight: .semibold)).foregroundColor(Aura.accent)
                Text("Mode").font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                Spacer()
            }

            Text(postureMonitor.effectiveMode.shortDescription)
                .font(.system(size: 13)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(postureMonitor.effectiveMode)
                .transition(.opacity)

            HStack(spacing: 8) {
                ForEach(PostureMode.allCases) { m in
                    let selected = postureMonitor.mode == m
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { postureMonitor.mode = m }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: m.icon).font(.system(size: 18, weight: .semibold))
                            Text(m.displayName).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(selected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selected
                            ? AnyShapeStyle(LinearGradient(colors: [Aura.accent, Aura.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Aura.softFill),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle(isOn: $postureMonitor.autoRelaxOnWalking) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-relax while walking").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text(postureMonitor.autoWalkActive ? "You're moving — detection relaxed"
                                                       : "Eases detection when you're on the move")
                        .font(.system(size: 12))
                        .foregroundColor(postureMonitor.autoWalkActive ? Aura.accent : .secondary)
                }
            }
            .tint(Aura.accent)

            if postureMonitor.mode == .custom {
                Divider().overlay(Aura.hairline)
                customControls.transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .auraCard()
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: postureMonitor.mode)
        .animation(.easeInOut(duration: 0.2), value: postureMonitor.autoWalkActive)
    }

    private var customControls: some View {
        let sensitivityPercent = Int(round((0.5 - postureMonitor.customThreshold) / 0.35 * 100))

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensitivity").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Spacer()
                    Text("\(sensitivityPercent)%").font(.system(size: 15, weight: .bold)).foregroundColor(Aura.accent)
                }
                Slider(
                    value: Binding(
                        get: { 0.5 - postureMonitor.customThreshold },
                        set: { postureMonitor.customThreshold = 0.5 - $0 }
                    ),
                    in: 0.0...0.35
                )
                .tint(Aura.accent)
                HStack {
                    Text("Relaxed").font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    Text("Strict").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Alert delay").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Spacer()
                    Text("\(Int(postureMonitor.customAlertDelay))s").font(.system(size: 15, weight: .bold)).foregroundColor(Aura.orange)
                }
                HStack(spacing: 8) {
                    ForEach([1, 5, 10, 15, 30, 60], id: \.self) { seconds in
                        let sel = postureMonitor.customAlertDelay == TimeInterval(seconds)
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                postureMonitor.customAlertDelay = TimeInterval(seconds)
                            }
                        }) {
                            Text("\(seconds)s")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(sel ? .white : Aura.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    sel
                                    ? AnyShapeStyle(LinearGradient(colors: [Aura.orange, Aura.orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(Aura.softFill),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Volume

    private var volumeCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.3.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(Aura.purple)
                        Text("Alert Volume").font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                    }
                    Text("Volume of the beep alert sound").font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(postureMonitor.beepVolume * 100))%")
                    .font(.system(size: 24, weight: .bold)).foregroundColor(Aura.purple)
            }

            HStack(spacing: 10) {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { volume in
                    let sel = postureMonitor.beepVolume == Float(volume)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            postureMonitor.beepVolume = Float(volume)
                        }
                    }) {
                        Text("\(Int(volume * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(sel ? .white : Aura.purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                sel
                                ? AnyShapeStyle(LinearGradient(colors: [Aura.purple, Aura.purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Aura.softFill),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .auraCard()
    }
}

// MARK: - Fullscreen visualizer

struct FullscreenVisualizerView: View {
    let pitch: Double
    let roll: Double
    let postureStatus: PostureStatus
    @Binding var isPresented: Bool

    private var tint: Color {
        switch postureStatus {
        case .good: return Aura.green
        case .forwardLean, .sidewaysLean, .poorPosture: return Aura.coral
        case .unknown: return Aura.accent
        }
    }

    var body: some View {
        ZStack {
            AuraBackground()
            Circle()
                .fill(tint)
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .opacity(0.35)
                .animation(.easeInOut(duration: 0.6), value: postureStatus)

            PostureVisualizer(pitch: pitch, roll: roll, postureStatus: postureStatus)
                .padding(40)

            VStack {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Aura.softFill, in: Circle())
                            .overlay(Circle().stroke(Aura.cardStroke, lineWidth: 1))
                    }
                    .padding(24)
                }
                Spacer()
            }
        }
    }
}
