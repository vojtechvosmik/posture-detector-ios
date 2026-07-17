//
//  DayDetailView.swift
//  PostureDetector
//
//  A single day's posture, in the dark "aurora" language: a big score dial and
//  frosted glass breakdowns.
//

import SwiftUI

struct DayDetailView: View {
    let date: Date
    let history: PostureHistory?
    @Environment(\.dismiss) var dismiss

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                if let history = history, history.totalMonitoredSeconds > 0 {
                    VStack(spacing: 16) {
                        scoreCard(history)
                        timeBreakdownCard(history)
                        statsGrid(history)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                } else {
                    noDataState
                }
            }
            .background(CalAurora())
            .navigationTitle(dateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done").font(.system(size: 16, weight: .semibold)).foregroundColor(CalTheme.accent)
                    }
                }
            }
        }
    }

    // MARK: - Score

    private func scoreCard(_ history: PostureHistory) -> some View {
        let score = history.score
        let color = CalTheme.scoreColor(score)

        return VStack(spacing: 18) {
            ZStack {
                Circle().fill(color).frame(width: 160, height: 160).blur(radius: 44).opacity(0.28)

                Circle()
                    .stroke(Aura.softFill, lineWidth: 14)
                    .frame(width: 156, height: 156)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(LinearGradient(colors: [color, color.opacity(0.7)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 156, height: 156)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)").font(.system(size: 52, weight: .bold)).foregroundColor(.primary)
                    Text("SCORE").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        .tracking(1.5)
                }
            }
            Text(scoreLabel(score))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .calCard(0)
    }

    private func scoreLabel(_ score: Int) -> String {
        score >= 80 ? "Excellent posture" : score >= 60 ? "Good posture" : "Needs improvement"
    }

    // MARK: - Time breakdown

    private func timeBreakdownCard(_ history: PostureHistory) -> some View {
        let total = max(history.totalMonitoredSeconds, 1)
        let goodPct = Int((history.goodPostureSeconds / total) * 100)
        let badPct = Int((history.badPostureSeconds / total) * 100)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Time Breakdown").font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)

            breakdownRow("Good posture", formatDuration(history.goodPostureSeconds), goodPct, CalTheme.green)
            breakdownRow("Bad posture", formatDuration(history.badPostureSeconds), badPct, CalTheme.coral)

            Divider().overlay(Aura.hairline)

            HStack {
                Text("Total monitored").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text(formatDuration(history.totalMonitoredSeconds))
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .calCard()
    }

    private func breakdownRow(_ label: String, _ duration: String, _ pct: Int, _ color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(.primary)
                Spacer()
                Text(duration).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                Text("· \(pct)%").font(.system(size: 14)).foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Aura.softFill).frame(height: 8)
                    Capsule().fill(color)
                        .frame(width: max(8, geo.size.width * CGFloat(pct) / 100.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Stats grid

    private func statsGrid(_ history: PostureHistory) -> some View {
        let total = max(history.totalMonitoredSeconds, 1)
        let goodPct = Int((history.goodPostureSeconds / total) * 100)
        let badPct = Int((history.badPostureSeconds / total) * 100)

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard("exclamationmark.triangle.fill", "\(history.alertCount)", "Alerts", CalTheme.orange)
                statCard("clock.fill", formatDuration(history.totalMonitoredSeconds), "Monitored", CalTheme.accent)
            }
            HStack(spacing: 12) {
                statCard("checkmark.circle.fill", "\(goodPct)%", "Good time", CalTheme.green)
                statCard("xmark.circle.fill", "\(badPct)%", "Bad time", CalTheme.coral)
            }
        }
    }

    private func statCard(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(.primary)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .calCard(0)
    }

    // MARK: - Empty

    private var noDataState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(CalTheme.accent).frame(width: 90, height: 90).blur(radius: 30).opacity(0.35)
                Image(systemName: "calendar.badge.clock").font(.system(size: 50)).foregroundColor(.primary)
            }
            .padding(.top, 80)
            Text("No data").font(.system(size: 22, weight: .bold)).foregroundColor(.primary)
            Text("You didn't monitor your posture on this day.")
                .font(.system(size: 15)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }
}
