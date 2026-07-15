//
//  SubscriptionManager.swift
//  PostureDetector
//
//  MOCKED subscription layer. Everything here simulates StoreKit without any
//  real purchase — swap the bodies of `purchase`/`restore` for StoreKit 2
//  calls when wiring the real thing. The rest of the app only talks to
//  `isPro` and the published state, so the UI won't need to change.
//

import Foundation
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Plans

    struct Plan: Identifiable, Equatable {
        let id: String
        let title: String
        let price: String
        let period: String
        let subtitle: String?
        let perWeek: String?
        let badge: String?
        let hasFreeTrial: Bool

        static let weekly = Plan(
            id: "posture.pro.weekly",
            title: "Weekly",
            price: "$4.99",
            period: "week",
            subtitle: nil,
            perWeek: nil,
            badge: nil,
            hasFreeTrial: false
        )

        static let yearly = Plan(
            id: "posture.pro.yearly",
            title: "Yearly",
            price: "$39.99",
            period: "year",
            subtitle: "7-day free trial, then $39.99/year",
            perWeek: "$0.77 / week",
            badge: "SAVE 84%",
            hasFreeTrial: true
        )

        static let all: [Plan] = [.yearly, .weekly]
    }

    // MARK: - State

    @Published private(set) var isPro: Bool
    @Published private(set) var isPurchasing = false
    @Published var lastError: String?

    private let proKey = "isProSubscriber"

    private init() {
        self.isPro = UserDefaults.standard.bool(forKey: proKey)
    }

    // MARK: - Mocked StoreKit

    /// Simulates a purchase with a short network-style delay, then unlocks Pro.
    func purchase(_ plan: Plan) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        lastError = nil

        // Simulate the App Store purchase sheet round-trip.
        try? await Task.sleep(nanoseconds: 1_600_000_000)

        setPro(true)
        isPurchasing = false
        return true
    }

    /// Simulates "Restore Purchases".
    func restore() async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        lastError = nil

        try? await Task.sleep(nanoseconds: 900_000_000)
        isPurchasing = false

        if isPro {
            return true
        } else {
            lastError = "No previous purchases found."
            return false
        }
    }

    // MARK: - Debug / helpers

    func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: proKey)
    }
}
