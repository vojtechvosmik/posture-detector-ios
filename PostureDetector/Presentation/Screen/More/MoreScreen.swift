//
//  MoreScreen.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct MoreScreen: View {
    @StateObject private var dataStore = PostureDataStore()
    @ObservedObject private var subscriptions = SubscriptionManager.shared
    @State private var showingHowToUse = false
    @State private var showingSupported = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var showingPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Subscription Section
                subscriptionSection

                // Insights Section
                insightsSection

                // Battery Tip
                batteryTipSection

                // Help & Info Section
                helpSection

                // Legal Section
                legalSection

                #if DEBUG
                // Debug Section
                debugSection
                #endif

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
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView(delayClose: false)
        }
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private var subscriptionSection: some View {
        if subscriptions.isPro {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .blue.opacity(0.6)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Postura PRO")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Your subscription is active. Thank you!")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        } else {
            Button {
                showingPaywall = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .blue.opacity(0.6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 46, height: 46)
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Upgrade to")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            Text("PRO")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.blue, in: Capsule())
                        }
                        Text("Unlimited tracking, insights & custom alerts")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.blue.opacity(0.1), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Battery Tip Section

    @ViewBuilder
    private var batteryTipSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 20))
                .foregroundColor(.yellow)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("Battery Optimization")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Background monitoring uses more battery. Consider monitoring during work hours only.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
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

    // MARK: - Debug Section

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Debug Tools", icon: "hammer.fill")

            VStack(spacing: 0) {
                NavigationLink(destination: PostureDebugScreen()) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 32, height: 32)

                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)
                        }

                        Text("Live Monitor")
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

                Divider()
                    .padding(.leading, 52)

                NavigationLink(destination: DebugLogsScreen()) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 32, height: 32)

                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                        }

                        Text("Debug Logs")
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

                Divider()
                    .padding(.leading, 52)

                SettingsRow(
                    icon: "photo.fill",
                    title: "Fill Sample Data",
                    iconColor: .purple
                ) {
                    dataStore.fillWithSampleData()
                }

                Divider()
                    .padding(.leading, 52)

                SettingsRow(
                    icon: "trash.fill",
                    title: "Clear All Data",
                    iconColor: .red
                ) {
                    dataStore.clearAllData()
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }
    #endif

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
            .contentShape(Rectangle())
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

// MARK: - Live Monitor Debug Screen

/// A self-contained testing sandbox: start monitoring here and watch, in real
/// time, exactly what the engine sees — live posture, the slouch→alert
/// countdown, the current mode & thresholds, and the auto-relax (walking) state.
struct PostureDebugScreen: View {
    @StateObject private var monitor = PostureMonitor()
    @StateObject private var dataStore = PostureDataStore()
    @State private var simulateWalking = false

    private var params: PostureModeParameters { monitor.effectiveParameters }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monitorToggle
                liveCard
                modeCard
                countdownCard
                autoRelaxCard
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Live Monitor")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { monitor.setDataStore(dataStore) }
        .onDisappear {
            if monitor.isMonitoring { monitor.stopMonitoring() }
        }
    }

    // MARK: Start / stop

    private var monitorToggle: some View {
        Button {
            if monitor.isMonitoring {
                monitor.stopMonitoring()
            } else {
                monitor.startMonitoring()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: monitor.isMonitoring ? "stop.fill" : "play.fill")
                Text(monitor.isMonitoring ? "Stop monitoring" : "Start monitoring")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(monitor.isMonitoring ? Color.red : Color.green,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Live posture

    private var liveCard: some View {
        DebugCard(title: "Live posture", icon: "figure.stand", tint: statusColor) {
            HStack(spacing: 18) {
                PostureVisualizer(pitch: monitor.pitch, roll: monitor.roll,
                                  postureStatus: monitor.postureStatus)
                    .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 10) {
                    statusBadge
                    metricRow("Pitch", degrees(monitor.pitch))
                    metricRow("Roll", degrees(monitor.roll))
                }
                Spacer()
            }
        }
    }

    private var statusBadge: some View {
        Text(monitor.postureStatus.description)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(statusColor.opacity(0.14), in: Capsule())
    }

    // MARK: Mode

    private var modeCard: some View {
        DebugCard(title: "Active detection", icon: "slider.horizontal.3", tint: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(monitor.effectiveMode.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    if monitor.autoWalkActive {
                        Text("AUTO")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.orange, in: Capsule())
                    }
                    Spacer()
                }
                metricRow("Pitch threshold", "\(degrees(params.pitchThreshold))")
                metricRow("Roll", params.monitorsRoll ? "\(degrees(params.rollThreshold))" : "off")
                metricRow("Grace before alert", "\(Int(params.graceDuration))s")
                metricRow("Sound delay", "\(Int(params.alertDelay))s")
            }
        }
    }

    // MARK: Slouch → alert countdown

    private var countdownCard: some View {
        DebugCard(title: "Slouch → alert", icon: "timer", tint: .orange) {
            TimelineView(.periodic(from: Date(), by: 0.08)) { context in
                countdownBody(now: context.date)
            }
        }
    }

    @ViewBuilder
    private func countdownBody(now: Date) -> some View {
        if let started = monitor.badPostureStartedAt {
            let elapsed = now.timeIntervalSince(started)
            let total = params.graceDuration
            let remaining = max(0, total - elapsed)
            let progress = total > 0 ? min(1, elapsed / total) : 1

            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.orange.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(remaining > 0 ? Color.orange : Color.red,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(remaining > 0 ? String(format: "%.1f", remaining) : "🔔")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(remaining > 0 ? .orange : .red)
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 4) {
                    Text(remaining > 0 ? "Alert in \(String(format: "%.1f", remaining))s" : "Alert fired")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Bad posture held for \(String(format: "%.1f", elapsed))s")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: monitor.isMonitoring ? "checkmark.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(monitor.isMonitoring ? .green : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.isMonitoring ? "Posture OK" : "Not monitoring")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    if let fired = monitor.lastAlertFiredAt {
                        Text("Last alert \(Int(Date().timeIntervalSince(fired)))s ago")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: Auto-relax (walking)

    private var autoRelaxCard: some View {
        DebugCard(title: "Auto-relax (walking)", icon: "figure.walk", tint: monitor.autoWalkActive ? .orange : .blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(monitor.autoWalkActive ? "Engaged → Active mode" : "Idle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(monitor.autoWalkActive ? .orange : .primary)
                    Spacer()
                    Circle()
                        .fill(monitor.autoWalkActive ? Color.orange : Color(uiColor: .systemGray4))
                        .frame(width: 12, height: 12)
                }
                metricRow("Detected activity", monitor.currentActivityDescription)
                metricRow("Auto-relax setting", monitor.autoRelaxOnWalking ? "on" : "off")

                Divider()

                Toggle(isOn: $simulateWalking) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Simulate walking")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Force the Active override for testing")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.orange)
                .onChange(of: simulateWalking) { on in
                    monitor.debugForceAutoWalk(on)
                }
            }
        }
    }

    // MARK: Helpers

    private var statusColor: Color {
        switch monitor.postureStatus {
        case .good: return .green
        case .unknown: return .gray
        case .forwardLean, .sidewaysLean: return .orange
        case .poorPosture: return .red
        }
    }

    private func degrees(_ radians: Double) -> String {
        "\(Int((radians * 180 / .pi).rounded()))°"
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

private struct DebugCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
