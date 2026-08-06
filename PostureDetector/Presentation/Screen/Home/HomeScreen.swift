//
//  HomeScreen.swift
//  PostureDetector
//
//  A friendly, consumer-style home: the live posture hero, today's score, a
//  weekly trend, a compact controls card and a daily tip. Adaptive light / dark
//  "aurora" language throughout.
//

import SwiftUI

struct HomeScreen: View {
    @StateObject private var postureMonitor = PostureMonitor()
    @StateObject private var bluetoothMonitor: BluetoothMonitor
    @ObservedObject private var dataStore = PostureDataStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme
    @State private var isFullscreen = false
    @State private var activeExercise: NeckExercise?
    @State private var showingCoach = false

    init() {
        let monitor = PostureMonitor()
        _postureMonitor = StateObject(wrappedValue: monitor)
        _bluetoothMonitor = StateObject(wrappedValue: BluetoothMonitor(postureMonitor: monitor))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                heroCard
                todayCard
                coachCard
                controlsCard
                weekCard
                exerciseCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 24)
            .fullScreenCover(item: $activeExercise) { exercise in
                ExerciseSessionView(exercise: exercise)
            }
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
            FullscreenVisualizerView(pitch: postureMonitor.pitch, roll: postureMonitor.roll,
                                     postureStatus: postureMonitor.postureStatus, isPresented: $isFullscreen)
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
            Circle()
                .fill(statusTint)
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .opacity(heroGlowOpacity)
                .offset(y: -70)
                .animation(.easeInOut(duration: 0.6), value: postureMonitor.postureStatus)

            if let errorMessage = postureMonitor.errorMessage {
                heroMessage(icon: "exclamationmark.triangle.fill", title: "Something's off", subtitle: errorMessage)
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
                heroScorePill
                Spacer()
                if postureMonitor.isMonitoring {
                    heroIconButton("arrow.up.left.and.arrow.down.right") { isFullscreen = true }
                }
            }
            .padding(.horizontal, 20).padding(.top, 18)

            Spacer(minLength: 4)

            PostureVisualizer(pitch: postureMonitor.pitch, roll: postureMonitor.roll,
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

            Spacer(minLength: 24)

            playStopButton.padding(.bottom, 20)
        }
    }

    private var heroScorePill: some View {
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
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(.secondary)
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

    // MARK: - Today

    private var todayCard: some View {
        let today = dataStore.todayHistory
        let score = today.score
        let scoreColor = Aura.scoreColor(score)

        return VStack(spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Posture Score").font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                    Text("Today's performance").font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(score)").font(.system(size: 38, weight: .bold)).foregroundColor(scoreColor)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: score)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Aura.softFill).frame(height: 14)
                    Capsule()
                        .fill(LinearGradient(colors: [scoreColor, scoreColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(14, geo.size.width * CGFloat(score) / 100.0), height: 14)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: score)
                }
            }
            .frame(height: 14)

            HStack(spacing: 0) {
                todayStat("clock.fill", Aura.accent, today.totalMonitoredDuration, "Total Time")
                statDivider
                todayStat("checkmark.seal.fill", Aura.green, today.goodPostureDuration, "Good Posture")
                statDivider
                todayStat("exclamationmark.triangle.fill", Aura.orange, "\(today.alertCount)", "Alerts")
                statDivider
                todayStat(scoreImprovementIcon, scoreImprovementColor, dataStore.scoreImprovementPercentage, "vs Yesterday")
            }
        }
        .auraCard()
    }

    private func todayStat(_ icon: String, _ color: Color, _ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(color)
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(Aura.hairline).frame(width: 1, height: 38)
    }

    // MARK: - This week

    private var weekCard: some View {
        let week = weekData
        let avg = weekAverage(week)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week").font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                Spacer()
                if avg > 0 {
                    Text("avg \(avg)")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Aura.scoreColor(avg))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Aura.scoreColor(avg).opacity(0.14), in: Capsule())
                }
            }

            HStack(spacing: 4) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, d in
                    dayRing(d)
                }
            }
        }
        .auraCard()
    }

    private func dayRing(_ d: (day: String, score: Int, hasData: Bool, isToday: Bool)) -> some View {
        let c = d.hasData ? Aura.scoreColor(d.score) : Color.secondary
        return VStack(spacing: 9) {
            ZStack {
                Circle().stroke(Aura.softFill, lineWidth: 4).frame(width: 38, height: 38)
                if d.hasData {
                    Circle()
                        .trim(from: 0, to: CGFloat(d.score) / 100.0)
                        .stroke(LinearGradient(colors: [c, c.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(-90))
                }
                Text(d.hasData ? "\(d.score)" : "–")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(d.hasData ? .primary : .secondary)
            }
            .padding(3)
            .overlay(
                Circle().stroke(d.isToday ? Aura.accent.opacity(0.6) : .clear, lineWidth: 1.5)
            )

            Text(d.day)
                .font(.system(size: 11, weight: d.isToday ? .bold : .medium))
                .foregroundColor(d.isToday ? Aura.accent : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Move break (guided exercises)

    /// Mirrors the Exercises tab right on the home screen: a titled section with
    /// an edge-to-edge carousel of the same poster cards. Tapping one starts it.
    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Move break")
                    .font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
                Text("Guided neck & posture sessions")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // The scroll view clips its content, so the cards' coloured glow
            // needs room inside it: the viewport is pushed out past the page
            // margin and the row inset by the same amount, which leaves the
            // cards exactly where they were with the shadow intact.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(NeckExercise.all) { exercise in
                        Button { activeExercise = exercise } label: { ExerciseMiniCard(exercise: exercise) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
            .padding(.horizontal, -16)
            .padding(.bottom, -14)
        }
    }

    // MARK: - Coach (one-glance card; the full report lives in the Calendar tab)

    @ViewBuilder private var coachCard: some View {
        if let report = PostureInsightEngine.report(for: dataStore.allHistory,
                                                     samples: PostureSampleStore.shared.days) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showingCoach = true
            } label: {
                CoachMiniCard(insight: report.headline, progress: report.deepProgress)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingCoach) {
                CoachDetailSheet(report: report)
            }
        }
    }

    // MARK: - Controls (compact, on-home)

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .semibold)).foregroundColor(Aura.accent)
                Text("Mode").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                Spacer()
            }

            Text(postureMonitor.effectiveMode.shortDescription)
                .font(.system(size: 13)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(postureMonitor.effectiveMode)
                .transition(.opacity)

            HStack(spacing: 8) {
                ForEach(PostureMode.allCases) { modeChip($0) }
            }

            Toggle(isOn: $postureMonitor.autoRelaxOnWalking) {
                Text("Auto-relax while walking").font(.system(size: 14, weight: .medium)).foregroundColor(.primary)
            }
            .tint(Aura.accent)

            if postureMonitor.mode == .custom {
                customControls.transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().overlay(Aura.hairline)

            HStack(spacing: 10) {
                togglePill("Sound", "speaker.wave.2.fill", $postureMonitor.isSoundEnabled, Aura.purple)
                togglePill("Notify", "bell.fill", $postureMonitor.isNotificationEnabled, Aura.accent)
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill").font(.system(size: 13)).foregroundColor(.secondary)
                Slider(value: Binding(get: { Double(postureMonitor.beepVolume) },
                                      set: { postureMonitor.beepVolume = Float($0) }), in: 0...1)
                    .tint(Aura.purple)
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
        .auraCard()
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: postureMonitor.mode)
        .animation(.easeInOut(duration: 0.2), value: postureMonitor.autoWalkActive)
    }

    private func modeChip(_ m: PostureMode) -> some View {
        let selected = postureMonitor.mode == m
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { postureMonitor.mode = m }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 5) {
                Image(systemName: m.icon).font(.system(size: 16, weight: .semibold))
                Text(m.displayName).font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(selected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected
                        ? AnyShapeStyle(LinearGradient(colors: [Aura.accent, Aura.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Aura.softFill),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func togglePill(_ title: String, _ icon: String, _ isOn: Binding<Bool>, _ tint: Color) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { isOn.wrappedValue.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle").font(.system(size: 15))
            }
            .foregroundColor(isOn.wrappedValue ? .white : .secondary)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(isOn.wrappedValue
                        ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Aura.softFill),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var customControls: some View {
        let sensitivityPercent = Int(round((0.5 - postureMonitor.customThreshold) / 0.35 * 100))
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensitivity").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                    Spacer()
                    Text("\(sensitivityPercent)%").font(.system(size: 14, weight: .bold)).foregroundColor(Aura.accent)
                }
                Slider(value: Binding(get: { 0.5 - postureMonitor.customThreshold },
                                      set: { postureMonitor.customThreshold = 0.5 - $0 }), in: 0.0...0.35)
                    .tint(Aura.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Alert delay").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                    Spacer()
                    Text("\(Int(postureMonitor.customAlertDelay))s").font(.system(size: 14, weight: .bold)).foregroundColor(Aura.orange)
                }
                HStack(spacing: 8) {
                    ForEach([1, 5, 10, 15, 30, 60], id: \.self) { seconds in
                        let sel = postureMonitor.customAlertDelay == TimeInterval(seconds)
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { postureMonitor.customAlertDelay = TimeInterval(seconds) }
                        }) {
                            Text("\(seconds)s")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(sel ? .white : Aura.orange)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(sel
                                            ? AnyShapeStyle(LinearGradient(colors: [Aura.orange, Aura.orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            : AnyShapeStyle(Aura.softFill),
                                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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

    // MARK: - Derived data

    private var weekData: [(day: String, score: Int, hasData: Bool, isToday: Bool)] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let h = dataStore.getHistory(for: date)
            let weekday = cal.component(.weekday, from: date) - 1
            return (symbols[weekday], h?.score ?? 0, (h?.totalMonitoredSeconds ?? 0) > 0, offset == 0)
        }
    }

    private func weekAverage(_ week: [(day: String, score: Int, hasData: Bool, isToday: Bool)]) -> Int {
        let scored = week.filter { $0.hasData }
        guard !scored.isEmpty else { return 0 }
        return scored.reduce(0) { $0 + $1.score } / scored.count
    }

}

// MARK: - Settings sheet (all configuration lives here)

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
            Circle().fill(tint).frame(width: 360, height: 360).blur(radius: 120).opacity(0.35)
                .animation(.easeInOut(duration: 0.6), value: postureStatus)

            PostureVisualizer(pitch: pitch, roll: roll, postureStatus: postureStatus).padding(40)

            VStack {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).foregroundColor(.primary)
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
