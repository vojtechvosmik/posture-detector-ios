//
//  OnboardingView.swift
//  PostureDetector
//
//  Step-by-step onboarding experience
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentStep = 0
    @State private var selectedActivity: ActivityLevel = .desk
    @State private var selectedSensitivity: PostureMonitor.Sensitivity = .medium
    @State private var notificationPermissionGranted = false
    @State private var isRequestingPermission = false

    init(isOnboardingComplete: Binding<Bool>) {
        self._isOnboardingComplete = isOnboardingComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                welcomeStep
                    .tag(0)
                activitySelectionStep
                    .tag(1)
                sensitivitySelectionStep
                    .tag(2)
                notificationPermissionStep
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom bar
            bottomBar
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Steps

    @ViewBuilder private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 100, weight: .thin))
                    .foregroundColor(.blue)

                Text("Welcome to\nPosture Monitor")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Track and improve your posture using AirPods")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 20) {
                FeatureRow(
                    icon: "airpodspro",
                    title: "Real-time Tracking",
                    description: "Uses AirPods sensors to monitor your head position continuously"
                )

                FeatureRow(
                    icon: "bell.badge",
                    title: "Smart Alerts",
                    description: "Get gentle reminders when your posture needs adjustment"
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track Progress",
                    description: "See your improvement over time with detailed statistics"
                )

                FeatureRow(
                    icon: "lock.shield",
                    title: "Private & Secure",
                    description: "All data stays on your device, no cloud storage"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.vertical, 40)
    }

    @ViewBuilder private var activitySelectionStep: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    ForEach(ActivityLevel.allCases, id: \.self) { activity in
                        Image(systemName: activity.icon)
                            .font(.system(size: 80, weight: .thin))
                            .foregroundColor(.blue)
                            .opacity(selectedActivity == activity ? 1 : 0)
                            .scaleEffect(selectedActivity == activity ? 1 : 0.8)
                    }
                }
                .frame(width: 100, height: 100)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedActivity)

                Text("What's your activity level?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(selectedActivity.description)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .frame(height: 60, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.2), value: selectedActivity)
                    .id(selectedActivity)
                    .transition(.opacity)
            }

            Spacer()

            // Custom draggable slider
            VStack(spacing: 20) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(height: 8)

                        // Active track
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(selectedActivity.rawValue) / CGFloat(ActivityLevel.allCases.count - 1), height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedActivity)

                        // Thumb
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .offset(x: geometry.size.width * CGFloat(selectedActivity.rawValue) / CGFloat(ActivityLevel.allCases.count - 1) - 16)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedActivity)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let position = value.location.x / geometry.size.width
                                        let index = Int((position * CGFloat(ActivityLevel.allCases.count)).rounded())
                                        let clampedIndex = min(max(0, index), ActivityLevel.allCases.count - 1)
                                        let newActivity = ActivityLevel.allCases[clampedIndex]
                                        if newActivity != selectedActivity {
                                            selectedActivity = newActivity
                                        }
                                    }
                            )
                    }
                }
                .frame(height: 32)
                .padding(.horizontal, 32)

                // Labels
                HStack {
                    ForEach(ActivityLevel.allCases, id: \.self) { activity in
                        Text(activity.shortName)
                            .font(.system(size: 13, weight: selectedActivity == activity ? .semibold : .regular))
                            .foregroundColor(selectedActivity == activity ? .blue : .secondary)
                            .frame(maxWidth: .infinity)
                            .animation(.easeInOut(duration: 0.2), value: selectedActivity)
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding(.vertical, 40)
    }

    @ViewBuilder private var sensitivitySelectionStep: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(.blue)

                Text("Detection sensitivity")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("We recommend Medium for most users")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                ForEach(PostureMonitor.Sensitivity.allCases, id: \.rawValue) { level in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSensitivity = level
                        }
                    }) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.displayName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(level.onboardingDescription)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            if selectedSensitivity == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                        }
                        .padding(20)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(selectedSensitivity == level ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.vertical, 40)
    }

    @ViewBuilder private var notificationPermissionStep: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: notificationPermissionGranted ? "checkmark.circle.fill" : "bell.badge")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(notificationPermissionGranted ? .green : .blue)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: notificationPermissionGranted)

                Text(notificationPermissionGranted ? "You're all set!" : "Enable notifications")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(notificationPermissionGranted ? "Notifications are enabled. You'll receive alerts when your posture needs adjustment." : "Get notified when your posture needs adjustment")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            if !notificationPermissionGranted {
                VStack(spacing: 20) {
                    FeatureRow(
                        icon: "bell",
                        title: "Posture alerts",
                        description: "Gentle reminders when bad posture is detected"
                    )

                    FeatureRow(
                        icon: "wifi.slash",
                        title: "Disconnect alerts",
                        description: "Know when your AirPods disconnect"
                    )

                    FeatureRow(
                        icon: "hand.raised",
                        title: "Your choice",
                        description: "Can be changed anytime in settings"
                    )
                }
                .padding(.horizontal, 32)

                Button(action: requestNotificationPermission) {
                    Text("Enable Notifications")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(isRequestingPermission)
                .padding(.horizontal, 32)
                .padding(.top, 20)
            }

            Spacer()
        }
        .padding(.vertical, 40)
    }


    // MARK: - Bottom Bar

    @ViewBuilder private var bottomBar: some View {
        HStack {
            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(currentStep == index ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Button
            Button(action: nextStep) {
                Text(buttonText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(canProceed ? Color.blue : Color.blue.opacity(0.5))
                    .cornerRadius(20)
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Helpers

    private var buttonText: String {
        if currentStep == 3 {
            return notificationPermissionGranted ? "Get Started" : "Skip"
        }
        return "Next"
    }

    private var canProceed: Bool {
        return true
    }

    private func nextStep() {
        if currentStep < 3 {
            withAnimation {
                currentStep += 1
            }
        } else {
            savePreferencesAndComplete()
        }
    }

    private func requestNotificationPermission() {
        guard !notificationPermissionGranted else { return }

        isRequestingPermission = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                isRequestingPermission = false
                notificationPermissionGranted = granted
            }
        }
    }

    private func savePreferencesAndComplete() {
        // Save user preferences
        UserDefaults.standard.set(selectedActivity.rawValue, forKey: "activityLevel")
        UserDefaults.standard.set(selectedSensitivity.rawValue, forKey: "sensitivity")
        UserDefaults.standard.set(selectedActivity.recommendedAlertDelay, forKey: "soundAlertDelay")

        completeOnboarding()
    }

    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Models

enum ActivityLevel: Int, CaseIterable {
    case sedentary = 0
    case desk = 1
    case moderate = 2
    case active = 3

    var icon: String {
        switch self {
        case .sedentary: return "bed.double.fill"
        case .desk: return "desktopcomputer"
        case .moderate: return "figure.walk"
        case .active: return "figure.run"
        }
    }

    var shortName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .desk: return "Desk"
        case .moderate: return "Moderate"
        case .active: return "Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary:
            return "Perfect for those who spend most of the day sitting or lying down"
        case .desk:
            return "Ideal for people who work at a computer or desk"
        case .moderate:
            return "Great for those with a mix of sitting and standing throughout the day"
        case .active:
            return "Best for those who are frequently moving and active"
        }
    }

    var recommendedAlertDelay: TimeInterval {
        switch self {
        case .sedentary: return 1.0   // Very short delay - mostly sitting
        case .desk: return 5.0         // Short delay - desk work
        case .moderate: return 10.0    // Medium delay - some movement
        case .active: return 30.0      // Long delay - frequent movement
        }
    }
}

extension PostureMonitor.Sensitivity {
    var onboardingDescription: String {
        switch self {
        case .low:
            return "For active people - fewer alerts, more freedom"
        case .medium:
            return "Balanced detection - recommended for desk work"
        case .high:
            return "Strict monitoring - maximum posture awareness"
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isComplete = false

        var body: some View {
            OnboardingView(isOnboardingComplete: $isComplete)
        }
    }

    return PreviewWrapper()
}
