//
//  PostureLiveActivityLiveActivity.swift
//  PostureLiveActivity
//
//  Live Activity Widget for Posture Monitoring
//

import ActivityKit
import WidgetKit
import SwiftUI

// PostureAttributes definition for the Live Activity
struct PostureAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isMonitoring: Bool
        var startTime: Date
    }
}

struct PostureLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PostureAttributes.self) { context in
            // Lock screen/banner UI - Better contrast for readability
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Gradient icon with glow effect
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
                                .fill(Color.green)
                                .frame(width: 7, height: 7)

                            Text("Actively Monitoring")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    Spacer()

                    // Timer with modern styling - using relative time
                    VStack(spacing: 4) {
                        Text(context.state.startTime, style: .timer)
                            .font(.system(size: 26, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.white)

                        Text("elapsed")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
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
                        Text(context.state.startTime, style: .timer)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
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

                            Text("Watching your posture")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
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
                Text(context.state.startTime, style: .timer)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(.blue)
                    .frame(width: 42)
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

#Preview("Notification", as: .content, using: PostureAttributes.preview) {
   PostureLiveActivityLiveActivity()
} contentStates: {
    PostureAttributes.ContentState.monitoring
}
