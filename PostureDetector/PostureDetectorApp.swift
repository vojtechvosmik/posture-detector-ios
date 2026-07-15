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
    @AppStorage("hasSeenInitialPaywall") private var hasSeenInitialPaywall = false
    @StateObject private var subscriptions = SubscriptionManager.shared
    @State private var showPaywall = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    AppRoot()
                        .fullScreenCover(isPresented: $showPaywall) {
                            PaywallView(delayClose: true)
                        }
                        .onAppear(perform: maybePresentPaywall)
                } else {
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                }
            }
            .environmentObject(subscriptions)
            .onChange(of: hasCompletedOnboarding) { done in
                if done { maybePresentPaywall() }
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

    /// The classic "finish setup, then the offer lands" moment.
    private func maybePresentPaywall() {
        guard hasCompletedOnboarding, !subscriptions.isPro, !hasSeenInitialPaywall else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            hasSeenInitialPaywall = true
            showPaywall = true
        }
    }
}
