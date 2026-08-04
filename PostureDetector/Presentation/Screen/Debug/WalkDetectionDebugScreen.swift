//
//  WalkDetectionDebugScreen.swift
//  PostureDetector
//
//  Live view of what iOS thinks you are doing. Core Motion exposes two
//  independent signals and this screen shows both as they arrive:
//
//    • CMMotionActivityManager — the motion coprocessor's classifier. It
//      reports walking / running / automotive / cycling / stationary, each with
//      a confidence, and can report several at once (or none, as "unknown").
//    • CMPedometer — live step counts and cadence, which react faster than the
//      classifier and work with the phone in hand.
//
//  The app combines them for auto-relax while walking; this screen exists to
//  judge how reliable that is in practice, so everything is timestamped and the
//  recent history is kept on screen.
//

import SwiftUI
import CoreMotion

struct WalkDetectionDebugScreen: View {
    @StateObject private var probe = WalkDetectionProbe()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                liveState
                classifier
                pedometer
                permissions
                history
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(AuraBackground())
        .navigationTitle("Walk detection")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { probe.start() }
        .onDisappear { probe.stop() }
    }

    // MARK: - Headline

    private var liveState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: probe.state.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(probe.state.tint)
                    .frame(width: 54, height: 54)
                    .background(probe.state.tint.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(probe.state.title)
                        .font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
                    Text(probe.lastUpdateText)
                        .font(.system(size: 12.5)).foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                metric("Moving", probe.isMoving ? "YES" : "no",
                       tint: probe.isMoving ? Aura.green : .secondary)
                divider
                metric("Confidence", probe.confidenceText, tint: .primary)
                divider
                metric("Updates", "\(probe.updateCount)", tint: .primary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .auraCard(padding: 0, cornerRadius: 20)
    }

    // MARK: - Sections

    private var classifier: some View {
        section("CMMOTIONACTIVITYMANAGER") {
            VStack(spacing: 0) {
                flag("Walking", probe.walking)
                rowDivider
                flag("Running", probe.running)
                rowDivider
                flag("Cycling", probe.cycling)
                rowDivider
                flag("Automotive", probe.automotive)
                rowDivider
                flag("Stationary", probe.stationary)
                rowDivider
                flag("Unknown", probe.unknown)
            }
            .auraCard(padding: 0, cornerRadius: 16)
        }
    }

    private var pedometer: some View {
        section("CMPEDOMETER") {
            VStack(spacing: 0) {
                value("Steps since opened", "\(probe.steps)")
                rowDivider
                value("Cadence", probe.cadenceText)
                rowDivider
                value("Pace", probe.paceText)
                rowDivider
                value("Distance", probe.distanceText)
                rowDivider
                value("Last step", probe.lastStepText)
            }
            .auraCard(padding: 0, cornerRadius: 16)
        }
    }

    private var permissions: some View {
        section("AVAILABILITY") {
            VStack(spacing: 0) {
                value("Authorization", probe.authorizationText)
                rowDivider
                value("Activity available", CMMotionActivityManager.isActivityAvailable() ? "yes" : "no")
                rowDivider
                value("Step counting", CMPedometer.isStepCountingAvailable() ? "yes" : "no")
                rowDivider
                value("Cadence", CMPedometer.isCadenceAvailable() ? "yes" : "no")
                rowDivider
                value("Distance", CMPedometer.isDistanceAvailable() ? "yes" : "no")
            }
            .auraCard(padding: 0, cornerRadius: 16)
        }
    }

    private var history: some View {
        section("RECENT EVENTS") {
            VStack(spacing: 0) {
                if probe.events.isEmpty {
                    Text("Waiting for the first classification…")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(Array(probe.events.enumerated()), id: \.element.id) { index, event in
                        if index > 0 { rowDivider }
                        HStack(spacing: 10) {
                            Text(event.time)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(event.label)
                                .font(.system(size: 13, weight: .medium)).foregroundColor(.primary)
                            Spacer(minLength: 0)
                            Text(event.confidence)
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                }
            }
            .auraCard(padding: 0, cornerRadius: 16)
        }
    }

    // MARK: - Pieces

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 9.5, weight: .heavy)).tracking(1.1)
                .foregroundColor(.secondary)
            content()
        }
    }

    private func metric(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold)).foregroundColor(tint)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .heavy)).tracking(0.4)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func flag(_ label: String, _ on: Bool) -> some View {
        HStack {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(on ? Aura.green : .secondary.opacity(0.4))
            Text(label)
                .font(.system(size: 14, weight: on ? .semibold : .regular))
                .foregroundColor(on ? .primary : .secondary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func value(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var rowDivider: some View {
        Rectangle().fill(Aura.hairline).frame(height: 1).padding(.leading, 14)
    }

    private var divider: some View {
        Rectangle().fill(Aura.hairline).frame(width: 1, height: 26)
    }
}

// MARK: - Probe

/// Owns its own Core Motion subscriptions so the screen works whether or not
/// posture monitoring is running.
final class WalkDetectionProbe: ObservableObject {

    struct Event: Identifiable {
        let id = UUID()
        let time: String
        let label: String
        let confidence: String
    }

    enum State {
        case walking, running, cycling, automotive, stationary, unknown, idle

        var title: String {
            switch self {
            case .walking:    return "Walking"
            case .running:    return "Running"
            case .cycling:    return "Cycling"
            case .automotive: return "In a vehicle"
            case .stationary: return "Stationary"
            case .unknown:    return "Unknown"
            case .idle:       return "Waiting…"
            }
        }

        var icon: String {
            switch self {
            case .walking:    return "figure.walk"
            case .running:    return "figure.run"
            case .cycling:    return "bicycle"
            case .automotive: return "car.fill"
            case .stationary: return "figure.stand"
            case .unknown:    return "questionmark"
            case .idle:       return "hourglass"
            }
        }

        var tint: Color {
            switch self {
            case .walking, .running, .cycling: return Aura.green
            case .automotive:                  return Aura.orange
            case .stationary:                  return Aura.accent
            case .unknown, .idle:              return .secondary
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var walking = false
    @Published private(set) var running = false
    @Published private(set) var cycling = false
    @Published private(set) var automotive = false
    @Published private(set) var stationary = false
    @Published private(set) var unknown = false
    @Published private(set) var confidenceText = "—"
    @Published private(set) var updateCount = 0
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var events: [Event] = []

    @Published private(set) var steps = 0
    @Published private(set) var cadenceText = "—"
    @Published private(set) var paceText = "—"
    @Published private(set) var distanceText = "—"
    @Published private(set) var lastStep: Date?

    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private var ticker: Timer?
    private var running_ = false

    var isMoving: Bool { walking || running || cycling || automotive }

    var lastUpdateText: String {
        guard let last = lastUpdate else { return "No classification yet" }
        let seconds = Int(Date().timeIntervalSince(last))
        return seconds < 2 ? "Updated just now" : "Updated \(seconds)s ago"
    }

    var lastStepText: String {
        guard let last = lastStep else { return "—" }
        return "\(Int(Date().timeIntervalSince(last)))s ago"
    }

    var authorizationText: String {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:    return "authorized"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "not determined"
        @unknown default:    return "unknown"
        }
    }

    func start() {
        guard !running_ else { return }
        running_ = true

        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self = self, let activity = activity else { return }
                self.apply(activity)
            }
        }

        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let self = self, let data = data else { return }
                DispatchQueue.main.async { self.apply(data) }
            }
        }

        // Keeps the "…s ago" labels honest between callbacks.
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func stop() {
        guard running_ else { return }
        running_ = false
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        ticker?.invalidate()
        ticker = nil
    }

    private func apply(_ activity: CMMotionActivity) {
        walking = activity.walking
        running = activity.running
        cycling = activity.cycling
        automotive = activity.automotive
        stationary = activity.stationary
        unknown = activity.unknown

        state = activity.walking ? .walking
            : activity.running ? .running
            : activity.cycling ? .cycling
            : activity.automotive ? .automotive
            : activity.stationary ? .stationary
            : .unknown

        confidenceText = Self.confidence(activity.confidence)
        lastUpdate = activity.startDate
        updateCount += 1

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        events.insert(Event(time: formatter.string(from: activity.startDate),
                            label: state.title,
                            confidence: confidenceText),
                      at: 0)
        if events.count > 20 { events.removeLast(events.count - 20) }
    }

    private func apply(_ data: CMPedometerData) {
        let newSteps = data.numberOfSteps.intValue
        if newSteps > steps { lastStep = Date() }
        steps = newSteps

        if let cadence = data.currentCadence?.doubleValue, cadence > 0 {
            cadenceText = String(format: "%.2f steps/s", cadence)
        } else {
            cadenceText = "—"
        }
        if let pace = data.currentPace?.doubleValue, pace > 0 {
            paceText = String(format: "%.1f s/m", pace)
        } else {
            paceText = "—"
        }
        if let distance = data.distance?.doubleValue {
            distanceText = String(format: "%.0f m", distance)
        } else {
            distanceText = "—"
        }
    }

    private static func confidence(_ confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low:    return "low"
        case .medium: return "medium"
        case .high:   return "high"
        @unknown default: return "—"
        }
    }

    deinit { stop() }
}
