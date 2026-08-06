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
    private static let airpodsDisconnectedNotificationID = "airpods-disconnected"
    private static let airpodsReconnectedNotificationID = "airpods-reconnected"

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

    /// Fired when the AirPods come back after a disconnect paused a session —
    /// nothing restarts tracking on its own, so this is the reminder to do it.
    func sendAirPodsReconnectedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "AirPods Reconnected"
        content.body = "Tracking is still paused — open Postura to start it again."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.airpodsReconnectedNotificationID,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("[PostureMonitor] Failed to send AirPods reconnection notification: \(error)")
            }
        }
    }

    func sendAirPodsDisconnectedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "AirPods Disconnected"
        content.body = "Your AirPods were disconnected. Monitoring has been paused."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.airpodsDisconnectedNotificationID,
            content: content,
            trigger: nil  // Immediate notification
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("[PostureMonitor] Failed to send AirPods disconnection notification: \(error)")
            }
        }
    }
}
