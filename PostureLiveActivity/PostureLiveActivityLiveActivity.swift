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
            // Lock screen/banner UI
            HStack(spacing: 12) {
                // Monitoring icon
                Image(systemName: "figure.stand")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Posture Monitor")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Monitoring Active")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.startTime, style: .timer)
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .activityBackgroundTint(Color.blue.opacity(0.15))
            .activitySystemActionForegroundColor(.blue)

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
