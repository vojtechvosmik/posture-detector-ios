//
//  MetricsView.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct MetricsView: View {
    let pitch: Double
    let roll: Double

    var body: some View {
        VStack(spacing: 12) {
            Text("Live Metrics")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            HStack(spacing: 20) {
                MetricItem(
                    label: "Pitch",
                    value: pitch,
                    icon: "arrow.up.and.down"
                )

                Divider()
                    .frame(height: 40)

                MetricItem(
                    label: "Roll",
                    value: roll,
                    icon: "arrow.left.and.right"
                )
            }
        }
        .padding()
    }
}

private struct MetricItem: View {
    let label: String
    let value: Double
    let icon: String

    // Convert radians to degrees
    private var degrees: Double {
        value * 180 / .pi
    }

    // Normalize to 0-1 range (assuming max tilt is ±45 degrees)
    private var normalizedValue: Double {
        let maxDegrees: Double = 45.0
        return min(abs(degrees) / maxDegrees, 1.0)
    }

    private var meterColor: Color {
        if abs(degrees) > 20 {
            return .red
        } else if abs(degrees) > 10 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            // Meter bar
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        // Fill based on value
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [meterColor, meterColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * normalizedValue, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: normalizedValue)
                    }
                }
                .frame(width: 80, height: 8)

                // Value text
                if #available(iOS 16.0, *) {
                    Text(String(format: "%.1f°", degrees))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                } else {
                    Text(String(format: "%.1f°", degrees))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
