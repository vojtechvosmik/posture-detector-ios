//
//  PostureLiveActivityLiveActivity.swift
//  PostureLiveActivity
//
//  Live Activity Widget for Posture Monitoring
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// PostureAttributes definition for the Live Activity
struct PostureAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isMonitoring: Bool
        var startTime: Date
        var pausedElapsedSeconds: TimeInterval?
    }
}

struct PostureLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PostureAttributes.self) { context in
            // Lock screen/banner UI - Better contrast for readability
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Gradient icon with glow effect
                    HStack(spacing: 16) {
                        ZStack {
                            // Main circle with gradient
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)

                            Image(systemName: "figure.stand")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 2)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Posture Monitor")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(context.state.isMonitoring ? Color.green : Color.orange)
                                    .frame(width: 7, height: 7)

                                Text(context.state.isMonitoring ? "Monitoring" : "Paused")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        // Timer with modern styling
                        VStack(alignment: .trailing, spacing: 4) {
                            if context.state.isMonitoring {
                                // Live timer when monitoring
                                Text(context.state.startTime, style: .timer)
                                    .font(.system(size: 26, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                                    .background(.red)
                                    .frame(alignment: .trailing)
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .minimumScaleFactor(0.6)
                            } else if let elapsed = context.state.pausedElapsedSeconds {
                                // Static elapsed time when paused
                                Text(formatElapsedTime(elapsed))
                                    .font(.system(size: 26, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundColor(.white.opacity(0.8))
                                    .background(.yellow)
                            }

                            Text("elapsed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        // Control button
                        Button(intent: ToggleMonitoringIntent()) {
                            Image(systemName: context.state.isMonitoring ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                // Modern animated progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)

                        // Animated gradient bar
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .activityBackgroundTint(Color.blue.opacity(0.85))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (only shows when user taps the Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.isMonitoring {
                            Text(context.state.startTime, style: .timer)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        } else if let elapsed = context.state.pausedElapsedSeconds {
                            Text(formatElapsedTime(elapsed))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        Text("elapsed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Posture Monitoring")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text(context.state.isMonitoring ? "Watching your posture" : "Paused")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Control button
                        Button(intent: ToggleMonitoringIntent()) {
                            ZStack {
                                Circle()
                                    .fill(context.state.isMonitoring ? Color.orange : Color.green)
                                    .frame(width: 36, height: 36)

                                Image(systemName: context.state.isMonitoring ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            } compactLeading: {
                // Compact mode - small icon on the left
                Image(systemName: "figure.stand")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            } compactTrailing: {
                // Compact mode - timer on the right
                if context.state.isMonitoring {
                    Text(context.state.startTime, style: .timer)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundColor(.blue)
                        .frame(width: 42, alignment: .trailing)
                } else if let elapsed = context.state.pausedElapsedSeconds {
                    Text(formatElapsedTime(elapsed))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundColor(.orange)
                        .frame(width: 42, alignment: .trailing)
                }
            } minimal: {
                // Minimal mode - single icon when space is limited
                Image(systemName: "figure.stand")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
            .keylineTint(.blue)
        }
    }
}

// Preview support
extension PostureAttributes {
    fileprivate static var preview: PostureAttributes {
        PostureAttributes()
    }
}

extension PostureAttributes.ContentState {
    fileprivate static var monitoring: PostureAttributes.ContentState {
        PostureAttributes.ContentState(
            isMonitoring: true,
            startTime: Date()
        )
    }
}

// Helper function to format elapsed time
private func formatElapsedTime(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = Int(seconds) / 60 % 60
    let secs = Int(seconds) % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview("Notification", as: .content, using: PostureAttributes.preview) {
   PostureLiveActivityLiveActivity()
} contentStates: {
    PostureAttributes.ContentState.monitoring
}
