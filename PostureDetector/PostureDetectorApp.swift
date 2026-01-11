//
//  PostureDetectorApp.swift
//  PostureDetector
//
//  AirPods-based posture detection app
//

import SwiftUI

@main
struct PostureDetectorApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                AppRoot()
            } else {
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
            }
        }
    }
}
