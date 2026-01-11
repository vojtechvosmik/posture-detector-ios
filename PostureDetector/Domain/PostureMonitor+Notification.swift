//
//  PostureNotifier.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import UserNotifications

extension PostureMonitor {

    // Notification identifier for bad posture alerts
    private static let badPostureNotificationID = "bad-posture-alert"

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func sendBadPostureNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Posture Alert"
        content.body = "Your posture needs attention! Sit up straight."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.badPostureNotificationID,
            content: content,
            trigger: nil  // Immediate notification
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("[PostureMonitor] Failed to send notification: \(error)")
            }
        }
    }

    func removePostureNotifications() {
        // Remove delivered notifications from notification center
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [Self.badPostureNotificationID])

        // Remove pending notifications
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.badPostureNotificationID])
    }
}
