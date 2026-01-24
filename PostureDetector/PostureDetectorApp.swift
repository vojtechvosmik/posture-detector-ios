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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                AppRoot()
            } else {
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                print("App moved to background - monitoring should continue")
            case .active:
                print("App became active")
            case .inactive:
                print("App became inactive")
            @unknown default:
                break
            }
        }
    }
}
