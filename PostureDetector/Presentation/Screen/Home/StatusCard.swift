//
//  StatusCard.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct StatusCard: View {
    let isConnected: Bool
    let postureStatus: PostureStatus

    var body: some View {
        VStack(spacing: 15) {
            VStack(spacing: 10) {
                Image(systemName: postureIcon)
                    .font(.system(size: 50))
                    .foregroundColor(.white)

                Text(postureStatus.description)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(postureAdvice)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 10)

            Divider()
                .background(Color.white.opacity(1.8))

            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                Text(isConnected ? "AirPods Connected" : "Waiting for AirPods..")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
        .padding(25)
    }

    private var postureIcon: String {
        switch postureStatus {
        case .good:
            return "checkmark.circle.fill"
        case .forwardLean:
            return "arrow.down.circle.fill"
        case .sidewaysLean:
            return "arrow.left.and.right.circle.fill"
        case .poorPosture:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private var postureAdvice: String {
        switch postureStatus {
        case .good:
            return "Keep it up! Your posture looks great."
        case .forwardLean:
            return "Try to sit up straighter and bring your head back."
        case .sidewaysLean:
            return "Center your head - you're leaning to the side."
        case .poorPosture:
            return "Adjust your position - multiple posture issues detected."
        case .unknown:
            return "Keep your head centered and level for good posture."
        }
    }
}
