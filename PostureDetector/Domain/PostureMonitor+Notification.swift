//
//  PostureNotifier.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import UserNotifications

extension PostureMonitor {

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func sendBadPostureNotification() {
        // Throttle notifications
        if let lastTime = lastNotificationTime,
           Date().timeIntervalSince(lastTime) < notificationCooldown {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Posture Alert"
        content.body = "Your posture needs attention! Sit up straight."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Immediate notification
        )

        notificationCenter.add(request) { [weak self] error in
            if error == nil {
                self?.lastNotificationTime = Date()
            }
        }
    }
}
