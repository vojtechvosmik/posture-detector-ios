//
//  ToggleMonitoringIntent.swift
//  PostureDetector
//
//  App Intent for controlling monitoring from Live Activity
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct ToggleMonitoringIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Monitoring"
    static var description: IntentDescription = IntentDescription("Start or stop posture monitoring")

    func perform() async throws -> some IntentResult {
        // Use Darwin notification (works across process boundaries)
        let notificationName = "cz.peachdev.postureplus.toggleMonitoring" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil,
            nil,
            true
        )

        print("[ToggleMonitoringIntent] Posted Darwin notification")
        return .result()
    }
}

// Notification name
extension Notification.Name {
    static let toggleMonitoringFromLiveActivity = Notification.Name("toggleMonitoringFromLiveActivity")
}
