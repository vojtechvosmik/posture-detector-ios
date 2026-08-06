//
//  WalkSignals.swift
//  PostureDetector
//
//  Four independent ways to answer "is this person walking right now", running
//  side by side so they can be compared against reality rather than trusted.
//
//    1. Activity classifier  — CMMotionActivityManager. Cheap and contextual,
//       but batched: it can lag half a minute and needs Motion & Fitness.
//    2. Pedometer            — CMPedometer live step updates. Faster, still
//       needs Motion & Fitness, and only counts when the phone is carried.
//    3. Phone motion         — raw accelerometer through CMMotionManager. No
//       permission at all, reacts within a second or two, but only works when
//       the phone is on the body.
//    4. Head motion          — the AirPods themselves. Works with the phone
//       face down on a desk, which is exactly the case the other three miss.
//
//  3 and 4 share one detector: walking is a periodic vertical bob somewhere
//  around 1.2–3 Hz with enough amplitude to stand out from fidgeting. We
//  high-pass the acceleration magnitude (subtract a slow moving average),
//  measure its RMS, and count zero crossings to get a cadence.
//

import Foundation
import Combine
import CoreMotion

// MARK: - Cadence detector

/// Shared maths for the two raw-acceleration sources.
final class CadenceDetector {

    /// Seconds of history used for every estimate.
    private let window: TimeInterval = 3.0
    /// Below this the movement is fidgeting rather than stepping.
    private let amplitudeThreshold: Double
    /// Human walking cadence, in steps per second.
    private let cadenceRange: ClosedRange<Double> = 1.2...3.2

    private var samples: [(time: Date, value: Double)] = []
    private var baseline: Double = 0

    private(set) var rms: Double = 0
    private(set) var cadence: Double = 0
    private(set) var isWalking = false
    private(set) var sampleRate: Double = 0

    init(amplitudeThreshold: Double) {
        self.amplitudeThreshold = amplitudeThreshold
    }

    func reset() {
        samples.removeAll()
        baseline = 0
        rms = 0
        cadence = 0
        isWalking = false
        sampleRate = 0
    }

    /// Feeds one acceleration sample (in g, gravity already excluded).
    func add(x: Double, y: Double, z: Double, at time: Date = Date()) {
        let magnitude = sqrt(x * x + y * y + z * z)

        // Slow moving average acts as the high-pass: what's left is the bob.
        baseline = baseline == 0 ? magnitude : baseline * 0.95 + magnitude * 0.05
        samples.append((time, magnitude - baseline))

        let cutoff = time.addingTimeInterval(-window)
        samples.removeAll { $0.time < cutoff }
        guard samples.count > 12,
              let first = samples.first?.time,
              let last = samples.last?.time,
              last.timeIntervalSince(first) > 1 else { return }

        let span = last.timeIntervalSince(first)
        sampleRate = Double(samples.count) / span

        // Amplitude
        let squared = samples.reduce(0.0) { $0 + $1.value * $1.value }
        rms = sqrt(squared / Double(samples.count))

        // Cadence from zero crossings: two crossings per step cycle.
        var crossings = 0
        for index in 1..<samples.count {
            let previous = samples[index - 1].value
            let current = samples[index].value
            if (previous < 0 && current >= 0) || (previous > 0 && current <= 0) {
                crossings += 1
            }
        }
        cadence = Double(crossings) / 2 / span

        isWalking = rms >= amplitudeThreshold && cadenceRange.contains(cadence)
    }
}

// MARK: - Signals

/// One detector's public state.
struct WalkSignal {
    var name: String
    var detail: String
    var available: Bool = false
    var authorized: Bool = true
    var isWalking = false
    var readout: String = "—"
    var lastChange: Date?
}

/// Runs all four detectors at once. Nothing here writes to the app's data —
/// it exists so the approaches can be judged against what you are actually doing.
final class WalkSignals: ObservableObject {

    @Published private(set) var classifier = WalkSignal(
        name: "Activity classifier",
        detail: "CMMotionActivityManager · batched, needs Motion & Fitness")
    @Published private(set) var pedometer = WalkSignal(
        name: "Pedometer",
        detail: "CMPedometer · live steps, phone must be carried")
    @Published private(set) var phone = WalkSignal(
        name: "Phone motion",
        detail: "CMMotionManager · no permission, phone must be on you")
    @Published private(set) var head = WalkSignal(
        name: "Head motion (AirPods)",
        detail: "CMHeadphoneMotionManager · works with the phone on a desk")

    /// True when any detector currently sees walking.
    var anyWalking: Bool {
        classifier.isWalking || pedometer.isWalking || phone.isWalking || head.isWalking
    }

    private let activityManager = CMMotionActivityManager()
    private let pedometerManager = CMPedometer()
    private let motionManager = CMMotionManager()
    private let headphoneManager = CMHeadphoneMotionManager()

    // Raw acceleration is noisier at the hip than at the head, hence the split.
    private let phoneDetector = CadenceDetector(amplitudeThreshold: 0.06)
    private let headDetector = CadenceDetector(amplitudeThreshold: 0.035)

    private var lastSteps = 0
    private var stepIdleTimer: Timer?
    private var running = false

    // MARK: Lifecycle

    func start() {
        guard !running else { return }
        running = true

        startClassifier()
        startPedometer()
        startPhoneMotion()
        startHeadMotion()
    }

    func stop() {
        guard running else { return }
        running = false

        activityManager.stopActivityUpdates()
        pedometerManager.stopUpdates()
        motionManager.stopAccelerometerUpdates()
        headphoneManager.stopDeviceMotionUpdates()
        stepIdleTimer?.invalidate()
        stepIdleTimer = nil
        phoneDetector.reset()
        headDetector.reset()
    }

    deinit { stop() }

    // MARK: 1 — Activity classifier

    private func startClassifier() {
        classifier.available = CMMotionActivityManager.isActivityAvailable()
        classifier.authorized = CMMotionActivityManager.authorizationStatus() == .authorized
        guard classifier.available else { return }

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            let walking = activity.walking || activity.running
            let label: String
            if activity.walking { label = "walking" }
            else if activity.running { label = "running" }
            else if activity.cycling { label = "cycling" }
            else if activity.automotive { label = "vehicle" }
            else if activity.stationary { label = "stationary" }
            else { label = "unknown" }

            self.classifier.authorized = CMMotionActivityManager.authorizationStatus() == .authorized
            self.update(&self.classifier, walking: walking,
                        readout: "\(label) · \(Self.confidence(activity.confidence))")
        }
    }

    // MARK: 2 — Pedometer

    private func startPedometer() {
        pedometer.available = CMPedometer.isStepCountingAvailable()
        pedometer.authorized = CMPedometer.authorizationStatus() == .authorized
        guard pedometer.available else { return }

        pedometerManager.startUpdates(from: Date()) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            DispatchQueue.main.async {
                let steps = data.numberOfSteps.intValue
                let cadence = data.currentCadence?.doubleValue ?? 0
                let gainedSteps = steps > self.lastSteps
                self.lastSteps = steps
                self.pedometer.authorized = CMPedometer.authorizationStatus() == .authorized

                if gainedSteps {
                    self.update(&self.pedometer, walking: true,
                                readout: cadence > 0
                                    ? String(format: "%d steps · %.1f/s", steps, cadence)
                                    : "\(steps) steps")
                    // No callback arrives when you stop, so time it out.
                    self.stepIdleTimer?.invalidate()
                    self.stepIdleTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        self.update(&self.pedometer, walking: false, readout: "\(self.lastSteps) steps · idle")
                    }
                }
            }
        }
    }

    // MARK: 3 — Phone motion

    private func startPhoneMotion() {
        phone.available = motionManager.isAccelerometerAvailable
        guard phone.available else { return }

        motionManager.accelerometerUpdateInterval = 1.0 / 50.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            // Raw accelerometer includes gravity; the detector's high-pass removes it.
            self.phoneDetector.add(x: data.acceleration.x,
                                   y: data.acceleration.y,
                                   z: data.acceleration.z)
            self.update(&self.phone,
                        walking: self.phoneDetector.isWalking,
                        readout: String(format: "%.3f g · %.1f Hz",
                                        self.phoneDetector.rms, self.phoneDetector.cadence))
        }
    }

    // MARK: 4 — Head motion

    private func startHeadMotion() {
        head.available = headphoneManager.isDeviceMotionAvailable
        guard head.available else { return }

        headphoneManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            let acceleration = motion.userAcceleration
            self.headDetector.add(x: acceleration.x, y: acceleration.y, z: acceleration.z)
            self.update(&self.head,
                        walking: self.headDetector.isWalking,
                        readout: String(format: "%.3f g · %.1f Hz",
                                        self.headDetector.rms, self.headDetector.cadence))
        }
    }

    // MARK: Helpers

    private func update(_ signal: inout WalkSignal, walking: Bool, readout: String) {
        if signal.isWalking != walking { signal.lastChange = Date() }
        signal.isWalking = walking
        signal.readout = readout
    }

    private static func confidence(_ confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low:    return "low"
        case .medium: return "medium"
        case .high:   return "high"
        @unknown default: return "—"
        }
    }
}
