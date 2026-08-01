//
//  ExerciseScreen.swift
//  PostureDetector
//
//  Guided neck & posture exercises, in the spirit of Apple Watch "Breathe".
//  The user picks a short session and is coached through it by a live, glowing
//  visual that mirrors their head position and gently guides them to reach and
//  hold each target — or to breathe with an expanding orb.
//
//  Everything the feature needs lives in this one file: the exercise catalogue,
//  the session engine, the immersive session view and its interactive guide.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Model

/// A single coached movement inside an exercise.
enum ExerciseStep {
    /// Reach the head to a target orientation (radians of deviation from the
    /// calibrated neutral) and hold it there for `hold` seconds.
    case reach(instruction: String, pitch: Double, roll: Double, hold: Double)
    /// A paced breathing block: `cycles` slow in/out breaths while sitting tall.
    case breathe(cycles: Int, inhale: Double, exhale: Double)

    /// Rough wall-clock cost, used to estimate session length. Reach steps add a
    /// couple of seconds for the movement itself on top of the hold.
    var duration: Double {
        switch self {
        case let .reach(_, _, _, hold): return hold + 2.5
        case let .breathe(cycles, inhale, exhale): return Double(cycles) * (inhale + exhale)
        }
    }
}

extension ExerciseStep {
    static func center(_ instruction: String = "Ease back to centre", hold: Double = 3) -> ExerciseStep {
        .reach(instruction: instruction, pitch: 0, roll: 0, hold: hold)
    }
    static func tiltLeft(hold: Double = 10) -> ExerciseStep {
        .reach(instruction: "Tilt your left ear toward your shoulder", pitch: 0, roll: -0.34, hold: hold)
    }
    static func tiltRight(hold: Double = 10) -> ExerciseStep {
        .reach(instruction: "Tilt your right ear toward your shoulder", pitch: 0, roll: 0.34, hold: hold)
    }
    static func chinDown(hold: Double = 10) -> ExerciseStep {
        .reach(instruction: "Lower your chin gently toward your chest", pitch: 0.34, roll: 0, hold: hold)
    }
    static func lookUp(hold: Double = 8) -> ExerciseStep {
        .reach(instruction: "Lift your gaze slowly toward the ceiling", pitch: -0.30, roll: 0, hold: hold)
    }
}

struct NeckExercise: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let category: String
    let tint: Color
    /// Asset name of the card photo — swap for any stock photo, keep the name.
    let photo: String
    let steps: [ExerciseStep]

    var totalDuration: Double { steps.reduce(0) { $0 + $1.duration } }
    var moveCount: Int { steps.count }

    var durationText: String {
        let secs = Int(totalDuration.rounded())
        if secs < 60 { return "\(secs)s" }
        return "\(Int(ceil(Double(secs) / 60))) min"
    }
}

extension NeckExercise {
    static let all: [NeckExercise] = [
        NeckExercise(
            id: "reset",
            title: "Posture Reset",
            subtitle: "Breathe deep and roll through gentle moves to lengthen your spine and sit tall.",
            icon: "lungs.fill",
            category: "Breath & move",
            tint: Aura.accent,
            photo: "exPhotoReset",
            steps: [
                .center("Settle in — sit tall", hold: 3),
                .breathe(cycles: 2, inhale: 4, exhale: 6),
                .chinDown(hold: 6), .center(),
                .breathe(cycles: 2, inhale: 4, exhale: 6),
                .lookUp(hold: 6), .center("Ease back to centre"),
                .breathe(cycles: 2, inhale: 4, exhale: 6)
            ]
        ),
        NeckExercise(
            id: "release",
            title: "Neck Release",
            subtitle: "Gentle guided tilts through every direction to loosen a stiff neck.",
            icon: "arrow.triangle.2.circlepath",
            category: "Mobility",
            tint: Aura.violet,
            photo: "exPhotoRelease",
            steps: [
                .center("Settle into a tall, easy posture", hold: 3),
                .tiltLeft(), .center(),
                .tiltRight(), .center(),
                .chinDown(), .center(),
                .lookUp(), .center("Slowly return to centre")
            ]
        ),
        NeckExercise(
            id: "melt",
            title: "Tension Melt",
            subtitle: "Longer, deeper holds to release the tension that builds through the day.",
            icon: "drop.fill",
            category: "Deep release",
            tint: Aura.green,
            photo: "exPhotoMelt",
            steps: [
                .center("Breathe out and settle", hold: 3),
                .tiltLeft(hold: 16), .center(),
                .tiltRight(hold: 16), .center(),
                .chinDown(hold: 16), .center("Slowly return to centre")
            ]
        )
    ]
}

// MARK: - Session engine

/// Drives a live exercise session: reads head motion, decides whether you're in
/// the target zone, advances through steps, and paces breathing — all published
/// so the view can render a smooth, reactive experience.
final class ExerciseSession: ObservableObject {
    enum Phase: Equatable { case getReady, running, finished }

    /// Head deviation (radians) mapped to the edge of the visual field.
    static let maxDeviation = 0.5
    /// How close (radians) the head must be to the target to count as "in zone".
    static let tolerance = 0.13

    let exercise: NeckExercise
    let motion = OnboardingMotionManager()

    @Published private(set) var phase: Phase = .getReady
    @Published private(set) var readyCount = 3
    @Published private(set) var stepIndex = 0
    @Published private(set) var instruction = "Get ready"
    @Published private(set) var detail = ""
    @Published private(set) var inZone = false
    @Published private(set) var holdProgress: Double = 0        // 0…1 within current hold
    @Published private(set) var breathScale: Double = 0         // 0…1 breathing openness
    @Published private(set) var isBreathing = false
    @Published private(set) var targetOffset: CGPoint = .zero   // −1…1 (x = roll, y = pitch)
    @Published private(set) var headOffset: CGPoint = .zero     // −1…1
    @Published private(set) var connected = true
    @Published private(set) var overallProgress: Double = 0
    @Published private(set) var elapsed: Double = 0             // seconds spent in `running`

    private var timer: Timer?
    private let dt = 1.0 / 30.0
    private var readyElapsed = 0.0
    private var stepElapsed = 0.0
    private var breathElapsed = 0.0
    private var cyclesDone = 0

    private let tap = UIImpactFeedbackGenerator(style: .soft)
    private let success = UINotificationFeedbackGenerator()

    private var steps: [ExerciseStep] { exercise.steps }

    init(exercise: NeckExercise) { self.exercise = exercise }

    var stepCountText: String { "\(min(stepIndex + 1, steps.count)) of \(steps.count)" }

    // MARK: Control

    func start() {
        motion.start()
        tap.prepare(); success.prepare()
        phase = .getReady
        readyElapsed = 0; readyCount = 3
        stepIndex = 0; elapsed = 0
        resetStepState()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        motion.stop()
    }

    func restart() {
        stop()
        holdProgress = 0; overallProgress = 0; breathScale = 0
        instruction = "Get ready"; detail = ""
        start()
    }

    private func resetStepState() {
        stepElapsed = 0; breathElapsed = 0; cyclesDone = 0
        holdProgress = 0; inZone = false
    }

    // MARK: Tick loop

    private func tick() {
        connected = motion.isConnected
        updateHeadOffset()

        switch phase {
        case .getReady:
            readyElapsed += dt
            readyCount = max(1, 3 - Int(readyElapsed))
            instruction = "Get ready"
            detail = "Sit tall, shoulders relaxed"
            if readyElapsed >= 3 {
                phase = .running
                success.notificationOccurred(.success)
            }
        case .running:
            elapsed += dt
            runStep()
        case .finished:
            break
        }
    }

    private func updateHeadOffset() {
        let hp = motion.pitch - CalibrationStore.pitch
        let hr = motion.roll - CalibrationStore.roll
        headOffset = CGPoint(x: clampUnit(hr / Self.maxDeviation),
                             y: clampUnit(hp / Self.maxDeviation))
    }

    private func runStep() {
        guard stepIndex < steps.count else { finish(); return }
        stepElapsed += dt

        switch steps[stepIndex] {
        case let .reach(instructionText, pitch, roll, hold):
            isBreathing = false
            targetOffset = CGPoint(x: clampUnit(roll / Self.maxDeviation),
                                   y: clampUnit(pitch / Self.maxDeviation))

            let hp = motion.pitch - CalibrationStore.pitch
            let hr = motion.roll - CalibrationStore.roll
            let distance = hypot(hp - pitch, hr - roll)
            let within = distance < Self.tolerance

            if within && !inZone { tap.impactOccurred(intensity: 0.6) }   // just locked in
            inZone = within

            if within {
                holdProgress = min(1, holdProgress + dt / hold)
                instruction = "Hold"
                detail = "\(Int(ceil((1 - holdProgress) * hold)))s · breathe slowly"
            } else {
                // Decay slowly so a brief wobble doesn't wipe out the whole hold.
                holdProgress = max(0, holdProgress - dt / (hold * 1.4))
                instruction = instructionText
                detail = "Move the dot into the ring"
            }
            if holdProgress >= 1 { completeStep() }

        case let .breathe(cycles, inhale, exhale):
            isBreathing = true
            targetOffset = .zero
            let period = inhale + exhale
            breathElapsed += dt

            if breathElapsed >= period {
                breathElapsed -= period
                cyclesDone += 1
                tap.impactOccurred(intensity: 0.4)
                if cyclesDone >= cycles { completeStep(); return }
            }

            if breathElapsed < inhale {
                breathScale = easeInOut(breathElapsed / inhale)          // 0 → 1
                instruction = "Breathe in"
            } else {
                breathScale = easeInOut(1 - (breathElapsed - inhale) / exhale)  // 1 → 0
                instruction = "Breathe out"
            }
            detail = "Sit tall · cycle \(min(cyclesDone + 1, cycles)) of \(cycles)"
        }

        updateOverallProgress()
    }

    private func completeStep() {
        stepIndex += 1
        resetStepState()
        if stepIndex >= steps.count {
            finish()
        } else {
            success.notificationOccurred(.success)
        }
        updateOverallProgress()
    }

    private func finish() {
        phase = .finished
        overallProgress = 1
        success.notificationOccurred(.success)
        timer?.invalidate(); timer = nil
        motion.stop()
        // Lets the coach compare posture in the hours after a session.
        PostureSampleStore.shared.recordExercise()
    }

    private func updateOverallProgress() {
        guard !steps.isEmpty else { overallProgress = 0; return }
        var frac = 0.0
        if stepIndex < steps.count {
            switch steps[stepIndex] {
            case .reach:
                frac = holdProgress
            case let .breathe(cycles, inhale, exhale):
                let period = inhale + exhale
                frac = (Double(cyclesDone) + min(1, breathElapsed / period)) / Double(cycles)
            }
        }
        overallProgress = min(1, (Double(stepIndex) + frac) / Double(steps.count))
    }

    // MARK: Helpers

    private func clampUnit(_ v: Double) -> Double { min(1, max(-1, v)) }

    private func easeInOut(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return c < 0.5 ? 2 * c * c : 1 - pow(-2 * c + 2, 2) / 2
    }
}

// MARK: - Exercises tab (poster gallery)

struct ExerciseScreen: View {
    @State private var active: NeckExercise?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                intro
                ForEach(NeckExercise.all) { exercise in
                    Button { active = exercise } label: { poster(exercise) }
                        .buttonStyle(ExercisePressStyle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .background(AuraBackground())
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $active) { exercise in
            ExerciseSessionView(exercise: exercise)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Take a moment\nfor your neck")
                .font(.system(size: 30, weight: .bold)).foregroundColor(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Guided sessions that coach your head live — pop in your AirPods and follow the glow.")
                .font(.system(size: 15)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    /// A bold, poster-style card per exercise: a tinted stock photo under
    /// signature concentric rings and the session copy.
    private func poster(_ exercise: NeckExercise) -> some View {
        ZStack {
            posterBackground(exercise)

            posterRings
            Circle().fill(Color.white).frame(width: 130, height: 130).blur(radius: 55).opacity(0.18)
                .offset(x: 130, y: -64)
            Image(systemName: exercise.icon)
                .font(.system(size: 122, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.10))
                .rotationEffect(.degrees(-12))
                .offset(x: 104, y: 46)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(exercise.category.uppercased())
                        .font(.system(size: 11, weight: .heavy)).tracking(1.0).foregroundColor(.white)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Color.white.opacity(0.22), in: Capsule())
                    Spacer()
                }
                Spacer(minLength: 0)
                Text(exercise.title)
                    .font(.system(size: 27, weight: .heavy)).foregroundColor(.white)
                Text(exercise.subtitle)
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
                HStack(spacing: 16) {
                    meta("clock.fill", exercise.durationText)
                    meta("repeat", "\(exercise.moveCount) moves")
                    Spacer()
                    ZStack {
                        Circle().fill(Color.white).frame(width: 46, height: 46)
                            .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                        Image(systemName: "play.fill").font(.system(size: 17, weight: .bold))
                            .foregroundColor(exercise.tint).offset(x: 1)
                    }
                }
                .padding(.top, 14)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 236)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: exercise.tint.opacity(0.35), radius: 16, y: 8)
    }

    /// The card's background: the stock photo under a tint + depth overlay.
    private func posterBackground(_ exercise: NeckExercise) -> some View {
        ZStack {
            Image(exercise.photo).resizable().scaledToFill()
            LinearGradient(colors: [exercise.tint.opacity(0.82), exercise.tint.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [Color.white.opacity(0.06), Color.black.opacity(0.32)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private func meta(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.92))
    }

    private var posterRings: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle().stroke(Color.white.opacity(0.16), lineWidth: 1.5)
                    .frame(width: 92 + CGFloat(i) * 62, height: 92 + CGFloat(i) * 62)
            }
        }
        .offset(x: 118, y: -72)
    }
}

/// Gentle press-scale for the poster cards.
struct ExercisePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A compact version of the poster card — same tinted-photo language as the
/// Exercises gallery — for the home-screen "Move break" carousel.
struct ExerciseMiniCard: View {
    let exercise: NeckExercise

    var body: some View {
        ZStack {
            Image(exercise.photo).resizable().scaledToFill()
                .frame(width: 178, height: 190).clipped()
            LinearGradient(colors: [exercise.tint.opacity(0.82), exercise.tint.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [Color.white.opacity(0.06), Color.black.opacity(0.42)],
                           startPoint: .top, endPoint: .bottom)

            ZStack {
                ForEach(0..<3) { i in
                    Circle().stroke(Color.white.opacity(0.14), lineWidth: 1.2)
                        .frame(width: 58 + CGFloat(i) * 42, height: 58 + CGFloat(i) * 42)
                }
            }
            .offset(x: 64, y: -58)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(exercise.category.uppercased())
                        .font(.system(size: 9, weight: .heavy)).tracking(0.6).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.22), in: Capsule())
                    Spacer()
                }
                Spacer(minLength: 0)
                Text(exercise.title)
                    .font(.system(size: 17, weight: .heavy)).foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill").font(.system(size: 10, weight: .semibold))
                        Text(exercise.durationText).font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.92))
                    Spacer()
                    ZStack {
                        Circle().fill(Color.white).frame(width: 34, height: 34)
                            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 2)
                        Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                            .foregroundColor(exercise.tint).offset(x: 1)
                    }
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
        .frame(width: 178, height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: exercise.tint.opacity(0.3), radius: 12, y: 6)
    }
}

// MARK: - Session view (immersive, guided)

struct ExerciseSessionView: View {
    let exercise: NeckExercise
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: ExerciseSession

    init(exercise: NeckExercise) {
        self.exercise = exercise
        _session = StateObject(wrappedValue: ExerciseSession(exercise: exercise))
    }

    var body: some View {
        ZStack {
            AuraBackground()
            if session.phase == .finished {
                completion
            } else {
                running
            }
        }
        .onAppear { session.start() }
        .onDisappear { session.stop() }
    }

    // MARK: Running

    private var running: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 8)
            instructionBlock
            ExerciseGuideView(session: session, tint: exercise.tint)
                .frame(height: 360)
                .padding(.vertical, 6)
            Spacer(minLength: 8)
            if !session.connected { connectHint }
            progressBar
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 30)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                    .frame(width: 38, height: 38)
                    .background(Aura.softFill, in: Circle())
                    .overlay(Circle().stroke(Aura.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text(exercise.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                if session.phase == .running {
                    Text("Step \(session.stepCountText)")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
    }

    private var instructionBlock: some View {
        VStack(spacing: 8) {
            Text(session.instruction)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .id(session.instruction)
                .transition(.opacity.combined(with: .move(edge: .top)))
            Text(session.detail)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .animation(.easeInOut(duration: 0.3), value: session.instruction)
        .frame(minHeight: 84)
        .padding(.horizontal, 8)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Aura.softFill).frame(height: 6)
                Capsule()
                    .fill(LinearGradient(colors: [exercise.tint, exercise.tint.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geo.size.width * session.overallProgress), height: 6)
            }
        }
        .frame(height: 6)
        .animation(.linear(duration: 0.2), value: session.overallProgress)
    }

    private var connectHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "airpodspro").font(.system(size: 14))
            Text("Connect your AirPods to track your head")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.bottom, 12)
    }

    // MARK: Completion

    private var completion: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(exercise.tint).frame(width: 130, height: 130).blur(radius: 40).opacity(0.4)
                Circle()
                    .fill(LinearGradient(colors: [Aura.green, exercise.tint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: Aura.green.opacity(0.4), radius: 16, y: 6)
                Image(systemName: "checkmark").font(.system(size: 42, weight: .bold)).foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("Nicely done").font(.system(size: 30, weight: .bold)).foregroundColor(.primary)
                Text("You finished \(exercise.title)").font(.system(size: 16)).foregroundColor(.secondary)
            }

            HStack(spacing: 44) {
                completionStat(timeText(session.elapsed), "time")
                completionStat("\(exercise.moveCount)", "moves")
            }
            .padding(.top, 4)

            Spacer()

            VStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(LinearGradient(colors: [exercise.tint, exercise.tint.opacity(0.8)], startPoint: .leading, endPoint: .trailing), in: Capsule())
                        .shadow(color: exercise.tint.opacity(0.4), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                Button { session.restart() } label: {
                    Text("Repeat session").font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 20)
        .padding(.bottom, 34)
    }

    private func completionStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 26, weight: .bold)).foregroundColor(.primary)
            Text(label.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.8).foregroundColor(.secondary)
        }
    }

    private func timeText(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Interactive guide visual

/// The star of the feature: a calm, glowing field where a live dot mirrors the
/// user's head. During reach steps a target ring appears in the direction to
/// move, filling as they hold it; during breathing an orb expands and contracts.
struct ExerciseGuideView: View {
    @ObservedObject var session: ExerciseSession
    let tint: Color

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = s * 0.34
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let head = CGPoint(x: center.x + session.headOffset.x * r, y: center.y + session.headOffset.y * r)
            let target = CGPoint(x: center.x + session.targetOffset.x * r, y: center.y + session.targetOffset.y * r)

            ZStack {
                field(s)

                if session.phase == .getReady {
                    readyBadge
                } else if session.isBreathing {
                    breathingOrb(s: s, center: center)
                } else {
                    if !session.inZone { connector(from: head, to: target) }
                    targetRing(at: target, s: s, r: r)
                    headDot(at: head, s: s)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
    }

    // MARK: Layers

    private func field(_ s: CGFloat) -> some View {
        ZStack {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                    .frame(width: s * 0.24 * CGFloat(i), height: s * 0.24 * CGFloat(i))
            }
            Rectangle().fill(Color.primary.opacity(0.05)).frame(width: s * 0.72, height: 1)
            Rectangle().fill(Color.primary.opacity(0.05)).frame(width: 1, height: s * 0.72)
        }
    }

    private var readyBadge: some View {
        ZStack {
            Circle().fill(tint.opacity(0.12)).frame(width: 120, height: 120)
            Circle().stroke(tint.opacity(0.5), lineWidth: 2).frame(width: 120, height: 120)
                .scaleEffect(pulse ? 1.06 : 1.0)
            Text("\(session.readyCount)")
                .font(.system(size: 52, weight: .bold)).foregroundColor(.primary)
                .id(session.readyCount)
                .transition(.scale.combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: session.readyCount)
    }

    private func breathingOrb(s: CGFloat, center: CGPoint) -> some View {
        let scale = 0.5 + session.breathScale * 0.5   // 0.5 … 1.0
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.45), tint.opacity(0.0)],
                                     center: .center, startRadius: 0, endRadius: s * 0.38))
                .frame(width: s * 0.78, height: s * 0.78)
                .scaleEffect(scale)
            Circle()
                .stroke(tint.opacity(0.85), lineWidth: 2)
                .frame(width: s * 0.78, height: s * 0.78)
                .scaleEffect(scale)
            Circle()
                .fill(tint)
                .frame(width: s * 0.055, height: s * 0.055)
                .shadow(color: tint.opacity(0.8), radius: s * 0.04)
        }
        .position(center)
        .animation(.easeInOut(duration: 0.12), value: session.breathScale)
    }

    private func connector(from: CGPoint, to: CGPoint) -> some View {
        Path { p in
            p.move(to: from)
            p.addLine(to: to)
        }
        .stroke(tint.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: from)
    }

    private func targetRing(at p: CGPoint, s: CGFloat, r: CGFloat) -> some View {
        let d = CGFloat(ExerciseSession.tolerance / ExerciseSession.maxDeviation) * r * 2
        return ZStack {
            Circle().fill(tint.opacity(session.inZone ? 0.16 : 0.05)).frame(width: d, height: d)
            Circle()
                .stroke(tint.opacity(session.inZone ? 0.9 : 0.45),
                        style: StrokeStyle(lineWidth: 2.5, dash: session.inZone ? [] : [4, 6]))
                .frame(width: d, height: d)
            Circle()
                .trim(from: 0, to: session.holdProgress)
                .stroke(LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: d, height: d)
                .rotationEffect(.degrees(-90))
        }
        .scaleEffect(session.inZone && pulse ? 1.06 : 1.0)
        .position(p)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: p)
    }

    private func headDot(at p: CGPoint, s: CGFloat) -> some View {
        let c = session.inZone ? Aura.green : tint
        return ZStack {
            Circle().fill(c).frame(width: s * 0.4, height: s * 0.4).blur(radius: s * 0.13).opacity(0.35)
            Circle().fill(c).frame(width: s * 0.05, height: s * 0.05)
                .shadow(color: c.opacity(0.9), radius: s * 0.04)
            Circle().fill(Color.white.opacity(0.9)).frame(width: s * 0.02, height: s * 0.02)
                .offset(x: -s * 0.008, y: -s * 0.008)
        }
        .position(p)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: p)
        .animation(.easeInOut(duration: 0.3), value: session.inZone)
    }
}
