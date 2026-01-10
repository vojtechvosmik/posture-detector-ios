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
        var postureStatus: String
        var pitch: Double
        var roll: Double
        var timestamp: Date
    }
}

struct PostureLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PostureAttributes.self) { context in
            // Lock screen/banner UI goes here
            HStack(spacing: 12) {
                // Status icon
                Image(systemName: statusIcon(for: context.state.postureStatus))
                    .font(.title2)
                    .foregroundColor(statusColor(for: context.state.postureStatus))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Posture Monitor")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(context.state.postureStatus)
                        .font(.headline)
                        .foregroundColor(statusColor(for: context.state.postureStatus))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Pitch: \(Int(context.state.pitch * 180 / .pi))°")
                        .font(.caption2)
                    Text("Roll: \(Int(context.state.roll * 180 / .pi))°")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .activityBackgroundTint(backgroundColor(for: context.state.postureStatus))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI for Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: statusIcon(for: context.state.postureStatus))
                            .font(.title)
                            .foregroundColor(statusColor(for: context.state.postureStatus))
                        Text(shortStatus(for: context.state.postureStatus))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.and.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(Int(context.state.pitch * 180 / .pi))°")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(Int(context.state.roll * 180 / .pi))°")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    // Empty center region
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Posture")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(context.state.postureStatus)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(statusColor(for: context.state.postureStatus))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(postureAdvice(for: context.state.postureStatus))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: compactIcon(for: context.state.postureStatus))
                    .foregroundColor(statusColor(for: context.state.postureStatus))
                    .transition(.scale.combined(with: .opacity))
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text("\(Int(abs(context.state.pitch * 180 / .pi)))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                    Text("°")
                        .font(.caption2)
                }
                .foregroundColor(statusColor(for: context.state.postureStatus))
            } minimal: {
                Image(systemName: compactIcon(for: context.state.postureStatus))
                    .foregroundColor(statusColor(for: context.state.postureStatus))
                    .transition(.scale)
            }
            .keylineTint(statusColor(for: context.state.postureStatus))
            .contentMargins(.all, 8, for: .expanded)
        }
    }

    // Helper functions
    private func statusIcon(for status: String) -> String {
        switch status {
        case "Good Posture ✓":
            return "checkmark.circle.fill"
        case "Leaning Forward":
            return "arrow.down.circle.fill"
        case "Leaning Sideways":
            return "arrow.left.and.right.circle.fill"
        case "Poor Posture":
            return "exclamationmark.triangle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    private func compactIcon(for status: String) -> String {
        switch status {
        case "Good Posture ✓":
            return "checkmark"
        case "Leaning Forward":
            return "arrow.down"
        case "Leaning Sideways":
            return "arrow.left.and.right"
        default:
            return "exclamationmark"
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Good Posture ✓":
            return .green
        default:
            return .red
        }
    }

    private func backgroundColor(for status: String) -> Color {
        switch status {
        case "Good Posture ✓":
            return Color.green.opacity(0.2)
        default:
            return Color.red.opacity(0.2)
        }
    }

    private func shortStatus(for status: String) -> String {
        switch status {
        case "Good Posture ✓":
            return "Good"
        case "Leaning Forward":
            return "Forward"
        case "Leaning Sideways":
            return "Sideways"
        case "Poor Posture":
            return "Poor"
        default:
            return "Unknown"
        }
    }

    private func postureAdvice(for status: String) -> String {
        switch status {
        case "Good Posture ✓":
            return "Keep it up!"
        case "Leaning Forward":
            return "Sit up straighter"
        case "Leaning Sideways":
            return "Center your head"
        case "Poor Posture":
            return "Adjust position"
        default:
            return "Monitoring..."
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
    fileprivate static var goodPosture: PostureAttributes.ContentState {
        PostureAttributes.ContentState(
            postureStatus: "Good Posture ✓",
            pitch: 0.05,
            roll: 0.02,
            timestamp: Date()
        )
    }

    fileprivate static var badPosture: PostureAttributes.ContentState {
        PostureAttributes.ContentState(
            postureStatus: "Leaning Forward",
            pitch: 0.45,
            roll: 0.1,
            timestamp: Date()
        )
    }
}

#Preview("Notification", as: .content, using: PostureAttributes.preview) {
   PostureLiveActivityLiveActivity()
} contentStates: {
    PostureAttributes.ContentState.goodPosture
    PostureAttributes.ContentState.badPosture
}
