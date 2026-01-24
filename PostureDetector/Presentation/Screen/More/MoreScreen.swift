//
//  MoreScreen.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct MoreScreen: View {
    @StateObject private var dataStore = PostureDataStore()
    @State private var showingHowToUse = false
    @State private var showingSupported = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Insights Section
                insightsSection

                // Help & Info Section
                helpSection

                // Legal Section
                legalSection

                // App Info
                appInfoSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingHowToUse) {
            HowToUseView()
        }
        .sheet(isPresented: $showingSupported) {
            SupportedDevicesView()
        }
        .sheet(isPresented: $showingTerms) {
            TermsOfUseView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Insights Section

    @ViewBuilder
    private var insightsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Insights", icon: "chart.bar.fill")

            VStack(spacing: 8) {
                InsightRow(
                    icon: "calendar",
                    title: "Total Days Tracked",
                    value: "\(dataStore.allHistory.filter { $0.totalMonitoredSeconds > 0 }.count)"
                )

                InsightRow(
                    icon: "clock.fill",
                    title: "Total Monitoring Time",
                    value: formatTotalTime()
                )

                InsightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Average Score",
                    value: "\(calculateAverageScore())"
                )

                InsightRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Total Alerts",
                    value: "\(dataStore.allHistory.reduce(0) { $0 + $1.alertCount })"
                )
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Help Section

    @ViewBuilder
    private var helpSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Help & Info", icon: "questionmark.circle.fill")

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "book.fill",
                    title: "How to Use",
                    iconColor: .blue
                ) {
                    showingHowToUse = true
                }

                Divider()
                    .padding(.leading, 52)

                SettingsRow(
                    icon: "airpodspro",
                    title: "Supported Devices",
                    iconColor: .purple
                ) {
                    showingSupported = true
                }

                Divider()
                    .padding(.leading, 52)

                SettingsRow(
                    icon: "envelope.fill",
                    title: "Contact Support",
                    iconColor: .green
                ) {
                    if let url = URL(string: "mailto:support@posturedetector.app") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Legal Section

    @ViewBuilder
    private var legalSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Legal", icon: "doc.text.fill")

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "doc.plaintext.fill",
                    title: "Terms of Use",
                    iconColor: .orange
                ) {
                    showingTerms = true
                }

                Divider()
                    .padding(.leading, 52)

                SettingsRow(
                    icon: "lock.shield.fill",
                    title: "Privacy Policy",
                    iconColor: .red
                ) {
                    showingPrivacy = true
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - App Info

    @ViewBuilder
    private var appInfoSection: some View {
        VStack(spacing: 8) {
            Text("Posture Detector")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Text("Version 1.0.0")
                .font(.system(size: 13))
                .foregroundColor(.gray)

            Text("Made with ❤️ for better posture")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Helper Methods

    private func formatTotalTime() -> String {
        let totalSeconds = dataStore.allHistory.reduce(0) { $0 + $1.totalMonitoredSeconds }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func calculateAverageScore() -> Int {
        let validHistory = dataStore.allHistory.filter { $0.totalMonitoredSeconds > 0 }
        guard !validHistory.isEmpty else { return 0 }
        let total = validHistory.reduce(0) { $0 + $1.score }
        return total / validHistory.count
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            /*Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)*/

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
//
//  HowToUseView.swift
//  PostureDetector
//
//  How to use the app guide
//

import SwiftUI

struct HowToUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to Posture Detector")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Your personal posture monitoring companion")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 8)

                    // Steps
                    StepCard(
                        number: 1,
                        title: "Connect Your AirPods",
                        description: "Connect your AirPods Pro or AirPods Max to your iPhone. Make sure they're properly fitted in your ears."
                    )

                    StepCard(
                        number: 2,
                        title: "Start Monitoring",
                        description: "Tap the play button to start monitoring. The app will track your head position and alert you when you slouch."
                    )

                    StepCard(
                        number: 3,
                        title: "Maintain Good Posture",
                        description: "Keep your head level and aligned. The white dot in the visualizer should stay centered for perfect posture."
                    )

                    StepCard(
                        number: 4,
                        title: "Respond to Alerts",
                        description: "When you receive an alert (sound or notification), adjust your posture. The alert will disappear once you fix your position."
                    )

                    StepCard(
                        number: 5,
                        title: "Track Your Progress",
                        description: "Check the Calendar tab to see your daily scores and monitor your posture improvement over time."
                    )

                    // Tips Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Best Results")
                            .font(.headline)
                            .padding(.top, 8)

                        TipRow(icon: "checkmark.circle.fill", text: "Wear AirPods consistently during work")
                        TipRow(icon: "checkmark.circle.fill", text: "Take breaks every 30-60 minutes")
                        TipRow(icon: "checkmark.circle.fill", text: "Adjust your monitor to eye level")
                        TipRow(icon: "checkmark.circle.fill", text: "Use a supportive chair")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StepCard: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}
//
//  SupportedDevicesView.swift
//  PostureDetector
//
//  Supported devices information
//

import SwiftUI

struct SupportedDevicesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supported Devices")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Posture Detector uses motion sensors in AirPods to track your head position")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 8)

                    // Supported Devices
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Compatible AirPods")
                            .font(.headline)

                        DeviceCard(
                            name: "AirPods Pro (1st generation)",
                            supported: true,
                            notes: "Full support with head tracking"
                        )

                        DeviceCard(
                            name: "AirPods Pro (2nd generation)",
                            supported: true,
                            notes: "Full support with enhanced tracking"
                        )

                        DeviceCard(
                            name: "AirPods Max",
                            supported: true,
                            notes: "Full support with head tracking"
                        )

                        DeviceCard(
                            name: "AirPods (3rd generation)",
                            supported: true,
                            notes: "Full support with head tracking"
                        )
                    }

                    // Not Supported
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Not Compatible")
                            .font(.headline)
                            .padding(.top, 8)

                        DeviceCard(
                            name: "AirPods (1st & 2nd generation)",
                            supported: false,
                            notes: "No motion sensors available"
                        )

                        DeviceCard(
                            name: "Other Bluetooth Headphones",
                            supported: false,
                            notes: "Requires Apple-specific sensors"
                        )
                    }

                    // Requirements
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Requirements")
                            .font(.headline)
                            .padding(.top, 8)

                        RequirementRow(icon: "iphone", text: "iPhone running iOS 15.0 or later")
                        RequirementRow(icon: "bluetooth", text: "Bluetooth enabled")
                        RequirementRow(icon: "airpodspro", text: "Compatible AirPods connected")
                        RequirementRow(icon: "bell.fill", text: "Notifications enabled (optional)")
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Supported Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DeviceCard: View {
    let name: String
    let supported: Bool
    let notes: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(supported ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct RequirementRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.purple)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}
//
//  TermsOfUseView.swift
//  PostureDetector
//
//  Terms of Use
//

import SwiftUI

struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Use")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 8)

                    Text("Last updated: January 11, 2026")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 16)

                    TermsSection(
                        title: "1. Acceptance of Terms",
                        content: "By using Posture Detector, you agree to these Terms of Use. If you do not agree, please do not use the app."
                    )

                    TermsSection(
                        title: "2. Use of the App",
                        content: "Posture Detector is intended for personal use to help improve posture awareness. The app uses motion data from compatible AirPods to monitor head position."
                    )

                    TermsSection(
                        title: "3. Health Disclaimer",
                        content: "This app is not a medical device and should not be used as a substitute for professional medical advice. If you have any health concerns, consult a healthcare professional."
                    )

                    TermsSection(
                        title: "4. Data Collection",
                        content: "All posture data is stored locally on your device. We do not collect, transmit, or store your personal data on external servers. See our Privacy Policy for more details."
                    )

                    TermsSection(
                        title: "5. Device Requirements",
                        content: "The app requires compatible AirPods with motion tracking capabilities. We are not responsible for functionality issues related to incompatible devices."
                    )

                    TermsSection(
                        title: "6. Limitations of Liability",
                        content: "The app is provided 'as is' without warranties. We are not liable for any direct, indirect, or consequential damages arising from the use of this app."
                    )

                    TermsSection(
                        title: "7. Intellectual Property",
                        content: "All content, features, and functionality are owned by the app developers and protected by copyright and other intellectual property laws."
                    )

                    TermsSection(
                        title: "8. Changes to Terms",
                        content: "We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms."
                    )

                    TermsSection(
                        title: "9. Contact",
                        content: "For questions about these Terms, contact us at support@posturedetector.app"
                    )
                }
                .padding()
            }
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TermsSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
//
//  PrivacyPolicyView.swift
//  PostureDetector
//
//  Privacy Policy
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 8)

                    Text("Last updated: January 11, 2026")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 16)

                    PrivacySection(
                        title: "Our Commitment",
                        content: "Your privacy is important to us. Posture Detector is designed with privacy as a core principle. All your data stays on your device."
                    )

                    PrivacySection(
                        title: "Data We Collect",
                        content: "The app collects motion data from your AirPods (pitch and roll angles) and stores posture history locally on your device. This data never leaves your device."
                    )

                    PrivacySection(
                        title: "Data Storage",
                        content: "All posture history, scores, and statistics are stored locally using iOS's secure data storage (UserDefaults and local files). We do not have access to this data."
                    )

                    PrivacySection(
                        title: "Data Sharing",
                        content: "We do not share, sell, or transmit your data to any third parties. Your posture data remains entirely private and under your control."
                    )

                    PrivacySection(
                        title: "Notifications",
                        content: "If you enable notifications, the app will send local alerts when poor posture is detected. These notifications are generated on your device and do not involve any external services."
                    )

                    PrivacySection(
                        title: "Permissions",
                        content: "The app requires Bluetooth access to connect to AirPods and notification permissions for alerts. These permissions are used solely for the app's core functionality."
                    )

                    PrivacySection(
                        title: "Data Deletion",
                        content: "You can delete all your posture history at any time by deleting the app. All locally stored data will be permanently removed."
                    )

                    PrivacySection(
                        title: "Analytics",
                        content: "We do not collect any analytics, crash reports, or usage statistics. The app operates entirely offline."
                    )

                    PrivacySection(
                        title: "Children's Privacy",
                        content: "The app does not knowingly collect information from children. It is designed for general use without age restrictions."
                    )

                    PrivacySection(
                        title: "Changes to Privacy Policy",
                        content: "We may update this Privacy Policy from time to time. Any changes will be reflected in the app with an updated date."
                    )

                    PrivacySection(
                        title: "Contact Us",
                        content: "If you have questions about this Privacy Policy, contact us at support@posturedetector.app"
                    )

                    // Privacy Highlights
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy Highlights")
                            .font(.headline)
                            .padding(.top, 8)

                        HighlightRow(icon: "lock.fill", text: "No data collection or tracking")
                        HighlightRow(icon: "iphone", text: "All data stored locally on device")
                        HighlightRow(icon: "hand.raised.fill", text: "No third-party sharing")
                        HighlightRow(icon: "network.slash", text: "Works completely offline")
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HighlightRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.green)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}
