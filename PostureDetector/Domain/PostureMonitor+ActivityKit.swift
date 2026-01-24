//
//  PostureMonitor+ActivityKit.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import Foundation
import CoreMotion
import Combine
import UIKit
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct PostureAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var isMonitoring: Bool
        public var startTime: Date

        public init(isMonitoring: Bool, startTime: Date) {
            self.isMonitoring = isMonitoring
            self.startTime = startTime
        }
    }

    public init() {}
}
#endif

extension PostureMonitor {

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    func startLiveActivity() {
        print("Attempting to start Live Activity...")

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("❌ Live Activities are not enabled in system settings")
            DispatchQueue.main.async {
                self.errorMessage = "Enable Live Activities in Settings > PostureDetector"
            }
            return
        }

        let initialState = PostureAttributes.ContentState(
            isMonitoring: true,
            startTime: Date()
        )

        let attributes = PostureAttributes()

        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            currentActivity = activity
            print("✅ Live Activity started successfully: \(activity.id)")
        } catch {
            print("❌ Error starting Live Activity: \(error)")
            print("   Error details: \(error.localizedDescription)")

            if let activityError = error as? ActivityAuthorizationError {
                print("   Authorization error: \(activityError)")
            }
        }
    }

    @available(iOS 16.1, *)
    func endLiveActivity() {
        guard let activity = currentActivity as? Activity<PostureAttributes> else { return }

        Task {
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
    #endif
}
