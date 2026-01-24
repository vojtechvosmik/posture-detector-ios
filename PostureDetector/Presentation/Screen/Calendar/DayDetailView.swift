//
//  DayDetailView.swift
//  PostureDetector
//
//  Detailed view for a specific day's posture data
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
            ScrollView {
                if let history = history, history.totalMonitoredSeconds > 0 {
                    VStack(spacing: 20) {
                        // Score card
                        scoreCard(history: history)

                        // Time breakdown
                        timeBreakdownCard(history: history)

                        // Stats grid
                        statsGrid(history: history)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 60)

                        Text("No Data")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)

                        Text("You didn't monitor your posture on this day")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle(dateString)
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

    @ViewBuilder
    private func scoreCard(history: PostureHistory) -> some View {
        let score = history.score
        let scoreColor: Color = score >= 80 ? .green : score >= 60 ? .orange : .red

        VStack(spacing: 16) {
            Text("\(score)")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(scoreColor)

            Text("Posture Score")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.gray)

            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [scoreColor, scoreColor.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private func timeBreakdownCard(history: PostureHistory) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Time Breakdown")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                TimeBreakdownRow(
                    label: "Good Posture",
                    duration: formatDuration(history.goodPostureSeconds),
                    percentage: Int((history.goodPostureSeconds / history.totalMonitoredSeconds) * 100),
                    color: .green
                )

                TimeBreakdownRow(
                    label: "Bad Posture",
                    duration: formatDuration(history.badPostureSeconds),
                    percentage: Int((history.badPostureSeconds / history.totalMonitoredSeconds) * 100),
                    color: .red
                )

                Divider()

                HStack {
                    Text("Total Monitored")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)

                    Spacer()

                    Text(formatDuration(history.totalMonitoredSeconds))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private func statsGrid(history: PostureHistory) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(history.alertCount)",
                    label: "Alerts",
                    color: .orange
                )

                StatCard(
                    icon: "clock.fill",
                    value: formatDuration(history.totalMonitoredSeconds),
                    label: "Monitored",
                    color: .blue
                )
            }

            HStack(spacing: 12) {
                StatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(Int((history.goodPostureSeconds / history.totalMonitoredSeconds) * 100))%",
                    label: "Good Time",
                    color: .green
                )

                StatCard(
                    icon: "xmark.circle.fill",
                    value: "\(Int((history.badPostureSeconds / history.totalMonitoredSeconds) * 100))%",
                    label: "Bad Time",
                    color: .red
                )
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}

struct TimeBreakdownRow: View {
    let label: String
    let duration: String
    let percentage: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(duration)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text("(\(percentage)%)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (CGFloat(percentage) / 100.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
