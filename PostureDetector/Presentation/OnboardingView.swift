//
//  OnboardingView.swift
//  PostureDetector
//
//  Card-based onboarding experience
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @State private var notificationPermissionGranted = false
    @State private var isRequestingPermission = false

    private let pages: [OnboardingPage] = [
        .welcome,
        .airpods,
        .notifications,
        .audio,
        .liveActivity,
        .permissions
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid gradient background
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Cards
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingCard(page: pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    // Bottom bar
                    HStack {
                        // Page dots
                        HStack(spacing: 6) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Circle()
                                    .fill(currentPage == index ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Spacer()

                        // Button
                        if currentPage < pages.count - 1 {
                            Button(action: {
                                withAnimation {
                                    currentPage += 1
                                }
                            }) {
                                Text("Next")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(20)
                            }
                        } else {
                            Button(action: requestNotificationPermission) {
                                Text(notificationPermissionGranted ? "Start" : "Continue")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(20)
                            }
                            .disabled(isRequestingPermission)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .background(Color.black.opacity(0.1))
                }
            }
        }
    }

    private func requestNotificationPermission() {
        guard !notificationPermissionGranted else {
            completeOnboarding()
            return
        }

        isRequestingPermission = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                isRequestingPermission = false
                notificationPermissionGranted = granted
                if granted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        completeOnboarding()
                    }
                }
            }
        }
    }

    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Onboarding Card

struct OnboardingCard: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.white)
                .padding(.bottom, 20)

            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Subtitle
            Text(page.subtitle)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Features
            VStack(spacing: 16) {
                ForEach(page.features, id: \.title) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text(feature.description)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 40)
                }
            }
            .padding(.top, 20)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Models

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let features: [OnboardingFeature]

    static let welcome = OnboardingPage(
        icon: "figure.stand",
        title: "Posture Monitor",
        subtitle: "Track and improve your posture using AirPods",
        features: [
            OnboardingFeature(icon: "checkmark.circle", title: "Real-time tracking", description: "Monitor posture continuously"),
            OnboardingFeature(icon: "chart.bar", title: "Progress stats", description: "See your improvement over time"),
            OnboardingFeature(icon: "lock.shield", title: "Private & secure", description: "All data stays on your device")
        ]
    )

    static let airpods = OnboardingPage(
        icon: "airpodspro",
        title: "AirPods Required",
        subtitle: "Works with AirPods Pro or AirPods Max",
        features: [
            OnboardingFeature(icon: "sensor", title: "Motion sensors", description: "Uses built-in head tracking"),
            OnboardingFeature(icon: "battery.100", title: "Battery efficient", description: "Minimal impact on battery life"),
            OnboardingFeature(icon: "bolt.circle", title: "Instant detection", description: "Real-time posture analysis")
        ]
    )

    static let notifications = OnboardingPage(
        icon: "bell.badge",
        title: "Smart Alerts",
        subtitle: "Get notified about poor posture",
        features: [
            OnboardingFeature(icon: "timer", title: "5-second delay", description: "Prevents false alerts"),
            OnboardingFeature(icon: "bell", title: "Gentle reminders", description: "Non-intrusive notifications"),
            OnboardingFeature(icon: "gearshape", title: "Customizable", description: "Turn on/off anytime")
        ]
    )

    static let audio = OnboardingPage(
        icon: "speaker.wave.2",
        title: "Audio Feedback",
        subtitle: "Hear alerts for bad posture",
        features: [
            OnboardingFeature(icon: "waveform", title: "Background audio", description: "Keeps monitoring active"),
            OnboardingFeature(icon: "speaker.badge.exclamationmark", title: "Alert beeps", description: "Sound when posture is bad"),
            OnboardingFeature(icon: "speaker.slash", title: "Optional", description: "Can be disabled")
        ]
    )

    static let liveActivity = OnboardingPage(
        icon: "iphone.and.arrow.forward",
        title: "Lock Screen",
        subtitle: "Control from your lock screen",
        features: [
            OnboardingFeature(icon: "stopwatch", title: "Live timer", description: "Track monitoring time"),
            OnboardingFeature(icon: "pause.circle", title: "Quick controls", description: "Pause/resume easily"),
            OnboardingFeature(icon: "app.badge", title: "Dynamic Island", description: "iPhone 14 Pro+ support")
        ]
    )

    static let permissions = OnboardingPage(
        icon: "checkmark.shield",
        title: "Almost Done",
        subtitle: "Enable notifications to stay on track",
        features: [
            OnboardingFeature(icon: "bell", title: "Posture alerts", description: "Get notified of poor posture"),
            OnboardingFeature(icon: "wifi.slash", title: "Disconnect alerts", description: "Know when AirPods disconnect"),
            OnboardingFeature(icon: "hand.raised", title: "Your choice", description: "Can be changed anytime")
        ]
    )
}

struct OnboardingFeature {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
