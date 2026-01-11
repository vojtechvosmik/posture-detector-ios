//
//  PostureMonitor+ActivityKit.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import Foundation
import CoreMotion
import Combine
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct PostureAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var postureStatus: String
        public var pitch: Double
        public var roll: Double
        public var timestamp: Date
        public var isConnected: Bool

        public init(postureStatus: String, pitch: Double, roll: Double, timestamp: Date, isConnected: Bool) {
            self.postureStatus = postureStatus
            self.pitch = pitch
            self.roll = roll
            self.timestamp = timestamp
            self.isConnected = isConnected
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
            postureStatus: postureStatus.description,
            pitch: pitch,
            roll: roll,
            timestamp: Date(),
            isConnected: isConnected
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

            // Live Activities require a Widget Extension to show UI
            // For now, just log that the activity data is being updated
            if let activityError = error as? ActivityAuthorizationError {
                print("   Authorization error: \(activityError)")
            }
        }
    }

    @available(iOS 16.1, *)
    func updateLiveActivity() {
        guard let activity = currentActivity as? Activity<PostureAttributes> else {
            print("⚠️ No current activity to update")
            return
        }

        let updatedState = PostureAttributes.ContentState(
            postureStatus: postureStatus.description,
            pitch: pitch,
            roll: roll,
            timestamp: Date(),
            isConnected: isConnected
        )

        Task {
            if #available(iOS 16.2, *) {
                // Set stale date to 1 second from now for maximum responsiveness
                // Note: iOS may still apply system-level throttling
                let staleDate = Date().addingTimeInterval(1)
                let relevanceScore: Double = self.postureStatus == .good ? 0.5 : 1.0

                let content = ActivityContent(
                    state: updatedState,
                    staleDate: staleDate,
                    relevanceScore: relevanceScore
                )

                await activity.update(content)
            } else {
                // Fallback for iOS 16.1
                await activity.update(using: updatedState)
            }
            print("✅ Live Activity updated: \(postureStatus.description), pitch: \(Int(pitch * 180 / .pi))°")
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
