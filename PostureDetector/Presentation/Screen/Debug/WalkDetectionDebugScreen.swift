//
//  WalkDetectionDebugScreen.swift
//  PostureDetector
//
//  Four detectors, side by side, updating live — so "is walk detection
//  working" becomes a question you can answer by looking rather than guessing.
//
//  Each card lights up on its own, which is the point: if the phone is on a
//  desk, only the AirPods detector should fire; if Motion & Fitness is off, the
//  top two go dark while the bottom two carry on.
//

import SwiftUI
import CoreMotion

struct WalkDetectionDebugScreen: View {
    @StateObject private var signals = WalkSignals()
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                verdict
                detectors
                permissions
                notes
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(AuraBackground())
        .navigationTitle("Walk detection")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { signals.start() }
        .onDisappear { signals.stop() }
        .onReceive(ticker) { now = $0 }
    }

    // MARK: - Verdict

    private var verdict: some View {
        HStack(spacing: 14) {
            Image(systemName: signals.anyWalking ? "figure.walk" : "figure.stand")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(signals.anyWalking ? Aura.green : .secondary)
                .frame(width: 54, height: 54)
                .background((signals.anyWalking ? Aura.green : Color.secondary).opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(signals.anyWalking ? "Moving" : "Still")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
                Text("\(activeCount) of 4 detectors firing")
                    .font(.system(size: 12.5)).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .auraCard(padding: 0, cornerRadius: 20)
    }

    private var activeCount: Int {
        [signals.classifier, signals.pedometer, signals.phone, signals.head]
            .filter { $0.isWalking }.count
    }

    // MARK: - Detectors

    private var detectors: some View {
        section("DETECTORS") {
            VStack(spacing: 10) {
                card(signals.classifier, index: 1)
                card(signals.pedometer, index: 2)
                card(signals.phone, index: 3)
                card(signals.head, index: 4)
            }
        }
    }

    private func card(_ signal: WalkSignal, index: Int) -> some View {
        let live = signal.available && signal.authorized
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(signal.isWalking ? Aura.green : Color.secondary.opacity(0.5), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(signal.name)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text(signal.detail)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)

                Text(signal.isWalking ? "WALKING" : (live ? "still" : "off"))
                    .font(.system(size: 10, weight: .heavy)).tracking(0.6)
                    .foregroundColor(signal.isWalking ? .white : .secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(signal.isWalking ? Aura.green : Aura.softFill, in: Capsule())
            }

            HStack {
                Text(live ? signal.readout : unavailableReason(signal))
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer(minLength: 8)
                if let change = signal.lastChange {
                    Text("\(Int(now.timeIntervalSince(change)))s ago")
                        .font(.system(size: 11)).foregroundColor(.secondary.opacity(0.8))
                        .monospacedDigit()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .auraCard(padding: 0, cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(signal.isWalking ? Aura.green.opacity(0.55) : .clear, lineWidth: 1.5)
        )
    }

    private func unavailableReason(_ signal: WalkSignal) -> String {
        if !signal.available { return "not available on this device" }
        if !signal.authorized { return "Motion & Fitness not granted" }
        return "—"
    }

    // MARK: - Permissions

    private var permissions: some View {
        section("PERMISSION") {
            VStack(spacing: 0) {
                HStack {
                    Text("Motion & Fitness").font(.system(size: 14)).foregroundColor(.secondary)
                    Spacer()
                    Text(authorizationText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isAuthorized ? .primary : Aura.coral)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)

                if !isAuthorized {
                    divider
                    Button {
                        openSettings()
                    } label: {
                        HStack {
                            Text("Open Settings").font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Aura.accent)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 12, weight: .bold)).foregroundColor(Aura.accent)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .auraCard(padding: 0, cornerRadius: 16)
        }
    }

    private var isAuthorized: Bool { CMMotionActivityManager.authorizationStatus() == .authorized }

    private var authorizationText: String {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:    return "authorized"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "not determined"
        @unknown default:    return "unknown"
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Notes

    private var notes: some View {
        section("HOW TO READ THIS") {
            VStack(alignment: .leading, spacing: 9) {
                note("1 and 2 need Motion & Fitness and only see the phone. With it on a desk they will stay quiet no matter how much you walk.")
                note("3 reads the raw accelerometer — no permission needed, but the phone has to be in a pocket or hand.")
                note("4 reads the AirPods. It is the only one that works while the phone stays on the desk, and it reacts in a couple of seconds.")
                note("Walking is a bob of roughly 1.2–3 steps per second. The readout shows amplitude in g and the measured cadence.")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .auraCard(padding: 0, cornerRadius: 16)
        }
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.secondary.opacity(0.4)).frame(width: 4, height: 4).padding(.top, 6)
            Text(text)
                .font(.system(size: 12.5)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private var divider: some View {
        Rectangle().fill(Aura.hairline).frame(height: 1).padding(.leading, 14)
    }
}
