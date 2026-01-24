//
//  AppRoot.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct AppRoot: View {

    var body: some View {
        TabView {
            homeTab
            calendarTab
            moreTab
        }
    }

    @ViewBuilder private var homeTab: some View {
        NavigationView {
            HomeScreen()
        }.tab(
            symbol: .figureStand,
            title: "Overview"
        )
    }

    @ViewBuilder private var calendarTab: some View {
        NavigationView {
            CalendarScreen()
        }.tab(
            symbol: .calendar,
            title: "Calendar"
        )
    }

    @ViewBuilder private var moreTab: some View {
        NavigationView {
            MoreScreen()
        }.tab(
            symbol: .ellipsis,
            title: "More"
        )
    }
}
//
//  OnboardingView.swift
//  PostureDetector
//
//  Onboarding tutorial and permission requests
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @State private var notificationPermissionGranted = false
    @State private var isRequestingPermission = false

    private let totalPages = 4

    var body: some View {
        ZStack {
            // Clean white background
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    IllustrationPage(
                        illustration: "figure.stand",
                        illustrationColor: .blue,
                        title: "Welcome to\nPosture Detector",
                        description: "Your personal AI-powered posture coach that helps you maintain perfect alignment"
                    )
                    .tag(0)

                    IllustrationPage(
                        illustration: "airpodspro",
                        illustrationColor: .purple,
                        title: "Just Wear\nYour AirPods",
                        description: "Connect your AirPods Pro or Max and let the motion sensors do the work"
                    )
                    .tag(1)

                    IllustrationPage(
                        illustration: "bell.badge.fill",
                        illustrationColor: .green,
                        title: "Get Gentle\nReminders",
                        description: "Receive subtle alerts when you slouch, helping you build better habits"
                    )
                    .tag(2)

                    PermissionsPage(
                        notificationPermissionGranted: $notificationPermissionGranted
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Bottom section with indicators and button
                VStack(spacing: 24) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.black : Color.gray.opacity(0.3))
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    // Navigation buttons
                    VStack(spacing: 12) {
                        if currentPage < totalPages - 1 {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
                            }) {
                                Text("Continue")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                            }

                            Button(action: {
                                completeOnboarding()
                            }) {
                                Text("Skip")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            // Last page buttons
                            Button(action: requestNotificationPermission) {
                                HStack {
                                    if isRequestingPermission {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text(notificationPermissionGranted ? "Get Started" : "Enable Notifications")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(14)
                            }
                            .disabled(isRequestingPermission)

                            if !notificationPermissionGranted {
                                Button(action: {
                                    completeOnboarding()
                                }) {
                                    Text("Skip for Now")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 50)
            }
        }
    }

    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
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
                    // Small delay before completing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        completeOnboarding()
                    }
                }
            }
        }
    }
}

// MARK: - Illustration Page

struct IllustrationPage: View {
    let illustration: String
    let illustrationColor: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Large illustration area (takes 60% of screen)
            ZStack {
                // Decorative circles
                Circle()
                    .fill(illustrationColor.opacity(0.08))
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.width * 0.8)

                Circle()
                    .fill(illustrationColor.opacity(0.12))
                    .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.width * 0.6)

                // Main illustration
                Image(systemName: illustration)
                    .font(.system(size: UIScreen.main.bounds.width * 0.35, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [illustrationColor, illustrationColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Spacer()

            // Text content
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(description)
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Permissions Page

struct PermissionsPage: View {
    @Binding var notificationPermissionGranted: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.width * 0.8)

                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.width * 0.6)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: UIScreen.main.bounds.width * 0.35, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Spacer()

            // Text content
            VStack(spacing: 16) {
                Text("Stay on Track")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text("Get gentle reminders when your posture needs attention")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

