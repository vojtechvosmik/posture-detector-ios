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
                .foregroundColor(.white)

            HStack(spacing: 20) {
                MetricItem(
                    label: "Pitch",
                    value: pitch,
                    icon: "arrow.up.and.down"
                )

                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 40)

                MetricItem(
                    label: "Roll",
                    value: roll,
                    icon: "arrow.left.and.right"
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(15)
    }
}

private struct MetricItem: View {
    let label: String
    let value: Double
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            Text(String(format: "%.2f°", value * 180 / .pi))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}
