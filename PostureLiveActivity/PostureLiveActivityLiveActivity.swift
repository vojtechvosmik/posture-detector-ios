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
        var isConnected: Bool
    }
}

struct PostureLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PostureAttributes.self) { context in
            // Lock screen/banner UI goes here
            if context.state.isConnected {
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
            } else {
                // Disconnected state
                HStack(spacing: 12) {
                    Image(systemName: "airpodspro.chargingcase.wireless.fill")
                        .font(.title2)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Posture Monitor")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("AirPods Disconnected")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Reconnect AirPods")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("to continue")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .activityBackgroundTint(Color.orange.opacity(0.2))
                .activitySystemActionForegroundColor(.white)
            }

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI for Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: statusIcon(for: context.state.postureStatus))
                                .font(.system(size: 26))
                                .foregroundColor(statusColor(for: context.state.postureStatus))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(shortStatus(for: context.state.postureStatus))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("Status")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.leading, 8)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "airpodspro")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Disconnected")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.leading, 8)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isConnected {
                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 4) {
                                Text("\(Int(context.state.pitch * 180 / .pi))°")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.up.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                Text("\(Int(context.state.roll * 180 / .pi))°")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.left.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.trailing, 8)
                    } else {
                        VStack(alignment: .trailing, spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            Text("Alert")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.trailing, 8)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.isConnected {
                        Text(context.state.postureStatus)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor(for: context.state.postureStatus))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 8)
                    } else {
                        Text("AirPods Disconnected")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 8)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if context.state.isConnected {
                            Text(postureAdvice(for: context.state.postureStatus))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("Reconnect your AirPods to continue monitoring")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } compactLeading: {
                if context.state.isConnected {
                    Image(systemName: compactIcon(for: context.state.postureStatus))
                        .foregroundColor(statusColor(for: context.state.postureStatus))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "airpodspro")
                        .foregroundColor(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            } compactTrailing: {
                if context.state.isConnected {
                    HStack(spacing: 2) {
                        Text("\(Int(abs(context.state.pitch * 180 / .pi)))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .contentTransition(.numericText())
                        Text("°")
                            .font(.caption2)
                    }
                    .foregroundColor(statusColor(for: context.state.postureStatus))
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } minimal: {
                if context.state.isConnected {
                    Image(systemName: compactIcon(for: context.state.postureStatus))
                        .foregroundColor(statusColor(for: context.state.postureStatus))
                        .transition(.scale)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .transition(.scale)
                }
            }
            .keylineTint(context.state.isConnected ? statusColor(for: context.state.postureStatus) : .orange)
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
            timestamp: Date(),
            isConnected: true
        )
    }

    fileprivate static var badPosture: PostureAttributes.ContentState {
        PostureAttributes.ContentState(
            postureStatus: "Leaning Forward",
            pitch: 0.45,
            roll: 0.1,
            timestamp: Date(),
            isConnected: true
        )
    }

    fileprivate static var disconnected: PostureAttributes.ContentState {
        PostureAttributes.ContentState(
            postureStatus: "Unknown",
            pitch: 0.0,
            roll: 0.0,
            timestamp: Date(),
            isConnected: false
        )
    }
}

#Preview("Notification", as: .content, using: PostureAttributes.preview) {
   PostureLiveActivityLiveActivity()
} contentStates: {
    PostureAttributes.ContentState.goodPosture
    PostureAttributes.ContentState.badPosture
    PostureAttributes.ContentState.disconnected
}
