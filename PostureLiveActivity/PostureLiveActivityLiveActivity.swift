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
                // Expanded UI for Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 26))
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startTime, style: .timer)
                        .font(.body)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Monitoring Active")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Posture detection is running")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            } compactLeading: {
                Image(systemName: "figure.stand")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text(context.state.startTime, style: .timer)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(.blue)
            } minimal: {
                Image(systemName: "figure.stand")
                    .foregroundColor(.blue)
            }
            .keylineTint(.blue)
            .contentMargins(.all, 8, for: .expanded)
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
