//
//  OnboardingView.swift
//  PostureDetector
//
//  Immersive, premium onboarding: welcome → choose mode → connect AirPods
//  (live) → calibrate the upright posture → enable notifications.
//
//  Visual language: a full-bleed living "aurora" gradient on a deep base, large
//  confident white type, glowing hero orbs with depth, frosted-glass controls,
//  and a single bright gradient CTA anchored at the bottom. Green appears only
//  as a semantic "success" for connected / aligned / calibrated states.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool

    @StateObject private var motion = OnboardingMotionManager()

    @State private var step: Step = .welcome
    @State private var selectedMode: PostureMode = .desk
    @State private var notificationGranted = false
    @State private var isRequestingPermission = false
    @State private var appeared = false

    // Connect
    @State private var didStartMotion = false

    // Calibrate
    @State private var isCalibrated = false
    @State private var readyToConfirm = false   // aligned & stable (hysteresis-gated)

    // Notifications
    @State private var notificationAsked = false

    // MARK: Theme
    private let accent = Color(red: 0.36, green: 0.52, blue: 1.0)
    private let violet = Color(red: 0.58, green: 0.40, blue: 0.98)
    private let success = Color(red: 0.22, green: 0.80, blue: 0.55)
    private let warning = Color(red: 1.0, green: 0.52, blue: 0.32)

    private var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    enum Step: Int, CaseIterable {
        case welcome, reality, mode, connect, calibrate, notifications
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                topBar

                stepScaffold {
                    Group {
                        switch step {
                        case .welcome:       welcomeStep
                        case .reality:       realityStep
                        case .mode:          modeStep
                        case .connect:       connectStep
                        case .calibrate:     calibrateStep
                        case .notifications: notificationsStep
                        }
                    }
                    .transition(.opacity)
                    .id(step)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appeared = true } }
        .onChange(of: step) { handleStepChange($0) }
        .onChange(of: motion.pitch) { _ in updateReadiness() }
        .onChange(of: motion.roll) { _ in updateReadiness() }
        .onChange(of: motion.isConnected) { _ in updateReadiness() }
        .onDisappear { motion.stop() }
    }

    /// Centres a step's content when it fits, scrolls when it doesn't.
    private func stepScaffold<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let built = content()
        return GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                built.frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }

    // MARK: - Top bar (progress + back)

    private var topBar: some View {
        // One thin row near the top: a small back chevron on the left, the
        // progress bar filling the middle, and an equal invisible slot on the
        // right so the progress stays perfectly centred and never shifts.
        HStack(spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.10), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome)

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.white : Color.white.opacity(0.22))
                        .frame(height: 5)
                        .animation(.easeInOut(duration: 0.4), value: step)
                }
            }

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 36)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            GlowOrb(systemName: "figure.stand", tint: violet, size: 140)
                .appearIn(0)

            Spacer(minLength: 34)

            VStack(spacing: 16) {
                titleText("Better posture,\neffortlessly.")
                    .appearIn(0.1)
                subtitleText("Postura turns your AirPods into a real-time posture coach — a gentle nudge whenever you slouch.")
                    .appearIn(0.16)

                HStack(spacing: 6) {
                    trustChip("lock.fill", "Private")
                    trustChip("person.crop.circle.badge.xmark", "No account")
                    trustChip("airpodspro", "AirPods")
                }
                .padding(.top, 4)
                .appearIn(0.24)
            }
            .padding(.horizontal, 36)

            Spacer(minLength: 20)
        }
    }

    // MARK: - Reality check (why this matters)

    private var realityStep: some View {
        VStack(spacing: 0) {
            stepHeader("Slouching is\nhurting you",
                       subtitle: "The damage builds silently — most people only notice once the pain has already set in.")

            Spacer(minLength: 22)

            VStack(spacing: 14) {
                slouchHero.appearIn(0.12)

                HStack(alignment: .top, spacing: 10) {
                    factTile("8 in 10", "adults get neck or back pain").appearIn(0.22)
                    factTile("−30%", "less air in a hunched chest").appearIn(0.28)
                    factTile("1,400 h", "a year spent over a screen").appearIn(0.34)
                }
                .frame(height: 94)

                reliefBanner.appearIn(0.42)
            }
            .padding(.horizontal, 36)

            Spacer(minLength: 18)
        }
    }

    /// The hero of the reality check: a hunched-over-the-phone photo carrying the
    /// single most visceral number, in the same tinted-photo language as Exercises.
    private var slouchHero: some View {
        ZStack(alignment: .bottomLeading) {
            photoBackdrop("obPhotoSlouch", tint: warning, shade: 0.42)

            ZStack {
                ForEach(0..<3) { i in
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.2)
                        .frame(width: 82 + CGFloat(i) * 54, height: 82 + CGFloat(i) * 54)
                }
            }
            .offset(x: 112, y: -72)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.forward").font(.system(size: 10, weight: .bold))
                    Text("HEAD TILTED 60°").font(.system(size: 11, weight: .bold)).tracking(0.6)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.22), in: Capsule())

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("27").font(.system(size: 46, weight: .bold))
                    Text("kg").font(.system(size: 20, weight: .semibold)).opacity(0.85)
                }
                .foregroundColor(.white)

                Text("of extra load on your neck every time you glance down at your phone.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 214)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: warning.opacity(0.3), radius: 18, y: 10)
    }

    /// Closes the step on hope — a bright, open-chest photo under the success tint.
    private var reliefBanner: some View {
        ZStack(alignment: .leading) {
            photoBackdrop("obPhotoRelief", tint: success, shade: 0.30, strength: 0.92)
            LinearGradient(colors: [Color.black.opacity(0.28), .clear],
                           startPoint: .leading, endPoint: .trailing)

            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("It's reversible")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Postura catches the slouch before it becomes a habit.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: success.opacity(0.25), radius: 14, y: 8)
    }

    /// A stock photo pushed far back: tinted hard, then shaded, so it reads as
    /// texture and mood rather than as a picture competing with the type.
    private func photoBackdrop(_ name: String, tint: Color, shade: Double, strength: Double = 0.8) -> some View {
        ZStack {
            Image(name).resizable().scaledToFill()
            LinearGradient(colors: [tint.opacity(strength), tint.opacity(strength - 0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [Color.white.opacity(0.05), Color.black.opacity(shade)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private func factTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(warning.opacity(0.16), lineWidth: 1))
    }

    // MARK: - Mode

    private var modeStep: some View {
        VStack(spacing: 0) {
            stepHeader("How will you use\nPostura?",
                       subtitle: "Pick where you'll wear it most — change it anytime.")
            Spacer(minLength: 18)

            VStack(spacing: 12) {
                ForEach(Array(PostureMode.presets.enumerated()), id: \.element) { i, m in
                    modeCardRow(m).appearIn(0.12 + Double(i) * 0.07)
                }
            }
            .padding(.horizontal, 36)

            HStack(spacing: 8) {
                Image(systemName: "figure.walk").font(.system(size: 13, weight: .semibold))
                Text("On the move, Postura eases off automatically.")
                    .font(.system(size: 13))
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.top, 18)
            .padding(.horizontal, 36)
            .appearIn(0.34)

            Spacer(minLength: 18)
        }
    }

    private func modeCardRow(_ m: PostureMode) -> some View {
        let selected = selectedMode == m
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { selectedMode = m }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(selected ? AnyShapeStyle(accentGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .frame(width: 46, height: 46)
                    Image(systemName: m.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(selected ? .white : .white.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(m.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text(m.shortDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? .white : .white.opacity(0.25))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.14 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Color.white.opacity(0.55) : Color.white.opacity(0.10),
                            lineWidth: selected ? 1.5 : 1)
            )
            .shadow(color: selected ? violet.opacity(0.4) : .clear, radius: 16, y: 6)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Connect

    private var connectStep: some View {
        VStack(spacing: 0) {
            stepHeader("Connect your AirPods",
                       subtitle: motion.isConnected
                        ? "Nicely done — they're streaming motion data."
                        : "Pop them in and pick them as the audio output.")
            Spacer()

            GlowOrb(systemName: motion.isConnected ? "checkmark" : "airpodspro",
                    tint: motion.isConnected ? success : accent, size: 132)
                .appearIn(0.1)

            Spacer()

            if motion.isConnected {
                glassPill(icon: "checkmark.circle.fill", text: "AirPods connected", tint: success)
                    .padding(.horizontal, 36)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: { motion.forceConnect() }) {
                    Text("Not connecting? Tap to nudge them over")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.horizontal, 36)
                .transition(.opacity)
            }

            Spacer().frame(height: 24)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: motion.isConnected)
    }

    // MARK: - Calibrate

    private var calibrateStep: some View {
        VStack(spacing: 0) {
            stepHeader("Set your upright posture", subtitle: calibrateSubtitle)

            if !isCalibrated {
                Text("Sit tall  ·  Shoulders relaxed  ·  Eyes forward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                    .padding(.horizontal, 36)
                    .appearIn(0.1)
                    .transition(.opacity)
            }

            Spacer()

            CalibrationTarget(pitch: motion.pitch, roll: motion.roll,
                              isReady: readyToConfirm, isConnected: motion.isConnected,
                              isCalibrated: isCalibrated, accent: accent, success: success)

            Spacer()

            calibrateHint
                .padding(.horizontal, 36)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isCalibrated)
                .animation(.easeInOut(duration: 0.25), value: readyToConfirm)
                .animation(.easeInOut(duration: 0.25), value: motion.isConnected)

            Spacer().frame(height: 24)
        }
    }

    private var calibrateSubtitle: String {
        if isCalibrated { return "Saved — this is your upright baseline." }
        if !motion.isConnected { return "Connect your AirPods to calibrate." }
        if readyToConfirm { return "Perfect — hold it there and confirm below." }
        return "Sit how you want to hold yourself all day, then centre the dot."
    }

    @ViewBuilder private var calibrateHint: some View {
        if isCalibrated {
            glassPill(icon: "checkmark.circle.fill", text: "Calibration saved", tint: success)
                .transition(.scale.combined(with: .opacity))
        } else if !motion.isConnected {
            glassPill(icon: "airpods.chargingcase", text: "Connect your AirPods first", tint: .white.opacity(0.7))
        } else if readyToConfirm {
            glassPill(icon: "checkmark.circle.fill", text: "You're aligned — hold still", tint: success)
                .transition(.scale.combined(with: .opacity))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "info.circle").font(.system(size: 15))
                Text("We'll remember this exact position as your perfect posture.")
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(.white.opacity(0.65))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Notifications

    private var notificationsStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            GlowOrb(systemName: notificationGranted ? "checkmark" : "bell.badge",
                    tint: notificationGranted ? success : accent, size: 132)
                .appearIn(0)

            Spacer(minLength: 30)

            VStack(spacing: 14) {
                titleText(notificationGranted ? "You're all set!" : "Stay on track")
                    .appearIn(0.1)
                subtitleText(notificationGranted
                    ? "Notifications are on. You'll be nudged the moment your posture slips."
                    : "Allow notifications so we can gently remind you when you slouch.")
                    .appearIn(0.16)
            }
            .padding(.horizontal, 36)

            if !notificationGranted {
                VStack(spacing: 12) {
                    benefitRow("bell", "Posture alerts", "A reminder when bad posture persists")
                        .appearIn(0.24)
                    benefitRow("wifi.slash", "Disconnect alerts", "Know the moment your AirPods drop")
                        .appearIn(0.3)
                }
                .padding(.horizontal, 36)
                .padding(.top, 30)
            }

            Spacer(minLength: 20)
        }
    }

    private func benefitRow(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text(desc).font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Bottom bar (one primary CTA, optional subtle skip)

    private struct CTA {
        var title: String
        var enabled: Bool = true
        var tint: Color? = nil
        var routePicker: Bool = false
        var action: () -> Void
    }

    private var bottomBar: some View {
        let cta = primaryCTA
        return VStack(spacing: 14) {
            primaryButton(cta)
            if let skip = secondarySkip {
                Button(action: skip.action) {
                    Text(skip.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.25), value: cta.enabled)
        .animation(.easeInOut(duration: 0.25), value: cta.title)
        .animation(.easeInOut(duration: 0.2), value: secondarySkip?.title)
    }

    private func primaryButton(_ cta: CTA) -> some View {
        let fill: AnyShapeStyle = {
            if !cta.enabled { return AnyShapeStyle(Color.white.opacity(0.14)) }
            if let tint = cta.tint {
                return AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.8)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            return AnyShapeStyle(accentGradient)
        }()
        let glow = cta.enabled ? (cta.tint ?? violet).opacity(0.5) : .clear

        return ZStack {
            Button(action: cta.action) {
                Text(cta.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(cta.enabled ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: glow, radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressableStyle())
            .disabled(!cta.enabled)

            if cta.routePicker {
                RoutePickerView(tint: .white, activeTint: .white)
                    .frame(height: 56)
                    .opacity(0.02)
            }
        }
    }

    private var primaryCTA: CTA {
        switch step {
        case .welcome:
            return CTA(title: "Get Started") { next() }
        case .reality:
            return CTA(title: "Fix my posture") { next() }
        case .mode:
            return CTA(title: "Continue") { next() }
        case .connect:
            if motion.isConnected { return CTA(title: "Continue") { next() } }
            return CTA(title: "Choose AirPods", routePicker: true) { }
        case .calibrate:
            if isCalibrated { return CTA(title: "Continue") { next() } }
            if readyToConfirm { return CTA(title: "Set my posture", tint: success) { confirmCalibration() } }
            let label = motion.isConnected ? "Straighten up to confirm" : "Set my posture"
            return CTA(title: label, enabled: false) { }
        case .notifications:
            if notificationGranted || notificationAsked { return CTA(title: "Finish Setup") { next() } }
            return CTA(title: "Enable Notifications", enabled: !isRequestingPermission) { requestNotificationPermission() }
        }
    }

    private var secondarySkip: (title: String, action: () -> Void)? {
        switch step {
        case .connect:   return motion.isConnected ? nil : ("I'll connect later", { next() })
        case .calibrate: return isCalibrated ? nil : ("Skip for now", { next() })
        case .notifications: return (notificationGranted || notificationAsked) ? nil : ("Not now", { next() })
        default: return nil
        }
    }

    // MARK: - Navigation

    private func next() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let nextStep = Step(rawValue: step.rawValue + 1) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { step = nextStep }
        } else {
            complete()
        }
    }

    private func back() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { step = prev }
        }
    }

    private func handleStepChange(_ newStep: Step) {
        if newStep == .connect && !didStartMotion {
            didStartMotion = true
            motion.start()
        }
        updateReadiness()
    }

    // MARK: - Calibration flow

    private func updateReadiness() {
        guard step == .calibrate, motion.isConnected, !isCalibrated else {
            if readyToConfirm { withAnimation(.easeOut(duration: 0.25)) { readyToConfirm = false } }
            return
        }
        let magnitude = max(abs(motion.pitch), abs(motion.roll))
        if !readyToConfirm && magnitude < 0.10 {
            withAnimation(.easeOut(duration: 0.25)) { readyToConfirm = true }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if readyToConfirm && magnitude > 0.18 {
            withAnimation(.easeOut(duration: 0.25)) { readyToConfirm = false }
        }
    }

    private func confirmCalibration() {
        motion.captureCalibration()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            isCalibrated = true
            readyToConfirm = false
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        guard !notificationGranted else { return }
        isRequestingPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                isRequestingPermission = false
                withAnimation { notificationGranted = granted; notificationAsked = true }
            }
        }
    }

    // MARK: - Completion

    private func complete() {
        UserDefaults.standard.set(selectedMode.rawValue, forKey: "postureMode")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        motion.stop()
        withAnimation { isOnboardingComplete = true }
    }

    // MARK: - Reusable bits

    private func stepHeader(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            titleText(title).appearIn(0)
            subtitleText(subtitle).id(subtitle).transition(.opacity).appearIn(0.06)
        }
        .padding(.horizontal, 36)
        .padding(.top, 20)
    }

    private func titleText(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 34, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func subtitleText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.68))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func trustChip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private func glassPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(tint)
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16).padding(.horizontal, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Aurora background

/// A living, full-bleed gradient mesh: a deep base with slowly drifting blurred
/// colour blobs. Gives the whole flow a premium, immersive feel.
private struct AuroraBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.09),
                         Color(red: 0.07, green: 0.06, blue: 0.16)],
                startPoint: .top, endPoint: .bottom
            )
            blob(Color(red: 0.24, green: 0.44, blue: 1.0), 400, x: animate ? -110 : -70, y: animate ? -280 : -340)
            blob(Color(red: 0.56, green: 0.32, blue: 0.96), 440, x: animate ? 150 : 110, y: animate ? -120 : -60)
            blob(Color(red: 0.86, green: 0.32, blue: 0.68), 360, x: animate ? -120 : -70, y: animate ? 300 : 360)
            blob(Color(red: 0.20, green: 0.68, blue: 0.95), 320, x: animate ? 140 : 100, y: animate ? 320 : 270)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { animate = true }
        }
    }

    private func blob(_ color: Color, _ size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 95)
            .opacity(0.5)
            .offset(x: x, y: y)
    }
}

// MARK: - Glow orb

/// A large glowing hero orb: an outer aura, breathing rings, a glossy gradient
/// core and a white glyph. Used across welcome / connect / notifications.
private struct GlowOrb: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 132
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: 70)
                .opacity(0.45)

            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.white.opacity(0.12 - Double(i) * 0.03), lineWidth: 1)
                    .frame(width: size + 40 + CGFloat(i) * 44, height: size + 40 + CGFloat(i) * 44)
                    .scaleEffect(breathe ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: breathe)
            }

            Circle()
                .fill(LinearGradient(colors: [tint, tint.opacity(0.68)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: tint.opacity(0.6), radius: 30, x: 0, y: 12)

            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(.white)
                .transition(.scale.combined(with: .opacity))
                .id(systemName)
        }
        .onAppear { breathe = true }
    }
}

// MARK: - Calibration target (dark)

/// "Bring the dot to the centre." The dot follows live head tilt; the centre
/// bullseye and a breathing ring glow green once aligned & steady.
private struct CalibrationTarget: View {
    let pitch: Double
    let roll: Double
    let isReady: Bool
    let isConnected: Bool
    let isCalibrated: Bool
    let accent: Color
    let success: Color

    @State private var breathe = false

    private var activeColor: Color {
        if isCalibrated || isReady { return success }
        return isConnected ? .white : .white.opacity(0.35)
    }

    private var dotOffset: CGSize {
        let limit: CGFloat = 96
        let x = min(max(CGFloat(roll) * 240, -limit), limit)
        let y = min(max(CGFloat(-pitch) * 240, -limit), limit)
        return CGSize(width: x, height: y)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(activeColor)
                .frame(width: 250, height: 250)
                .opacity((isReady || isCalibrated) ? 0.22 : 0)
                .blur(radius: 40)
                .animation(.easeInOut(duration: 0.45), value: isReady)
                .animation(.easeInOut(duration: 0.45), value: isCalibrated)

            Circle().stroke(Color.white.opacity(0.15), lineWidth: 2).frame(width: 240, height: 240)

            Circle()
                .stroke(activeColor.opacity(0.6), lineWidth: 2)
                .frame(width: 240, height: 240)
                .scaleEffect(breathe ? 1.05 : 0.99)
                .opacity(isReady && !isCalibrated ? 1 : 0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathe)

            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 240)
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 240, height: 1)

            Circle().fill(activeColor.opacity(isReady ? 0.18 : 0.06)).frame(width: 96, height: 96)
            Circle()
                .stroke(activeColor.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: isReady ? [] : [4, 5]))
                .frame(width: 96, height: 96)
                .animation(.easeInOut(duration: 0.25), value: isReady)

            if isCalibrated {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 76))
                    .foregroundColor(success)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .fill(activeColor)
                    .frame(width: 30, height: 30)
                    .shadow(color: activeColor.opacity(0.7), radius: isReady ? 16 : 6)
                    .offset(dotOffset)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dotOffset)
            }
        }
        .frame(height: 264)
        .onAppear { breathe = true }
    }
}

// MARK: - Interaction & motion helpers

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Staggered fade-and-rise reveal; re-fires when a step reappears (`.id(step)`).
private struct AppearIn: ViewModifier {
    let delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear { withAnimation(.easeOut(duration: 0.5).delay(delay)) { shown = true } }
    }
}

private extension View {
    func appearIn(_ delay: Double = 0) -> some View { modifier(AppearIn(delay: delay)) }
}

// MARK: - Feature Row (used elsewhere in the app)

struct FeatureRow: View {
    let icon: String
    var tint: Color = .blue
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                Text(description).font(.system(size: 14)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isComplete = false
        var body: some View { OnboardingView(isOnboardingComplete: $isComplete) }
    }
    return PreviewWrapper()
}
