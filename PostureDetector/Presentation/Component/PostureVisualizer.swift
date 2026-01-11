//
//  PostureVisualizer.swift
//  PostureDetector
//
//  Visual representation of user's posture
//

import SwiftUI

struct PostureVisualizer: View {
    let pitch: Double
    let roll: Double
    let postureStatus: PostureStatus
    @State private var rotation: Double = 0
    @State private var pulse: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Animated background grid
                ForEach(0..<5) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [statusColor.opacity(0.1), statusColor.opacity(0.3), statusColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: size * (0.3 + Double(i) * 0.15), height: size * (0.3 + Double(i) * 0.15))
                        .rotationEffect(.degrees(rotation + Double(i) * 20))
                }

                // Main holographic sphere
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                statusColor.opacity(0.3 - Double(i) * 0.1),
                                lineWidth: 2
                            )
                            .frame(
                                width: size * (0.5 + Double(i) * 0.1),
                                height: size * (0.5 + Double(i) * 0.1)
                            )
                            .scaleEffect(pulse ? 1.1 : 1.0)
                    }

                    // Core sphere with scan lines
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        statusColor.opacity(0.8),
                                        statusColor.opacity(0.4),
                                        statusColor.opacity(0.1)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: size * 0.25
                                )
                            )
                            .frame(width: size * 0.5, height: size * 0.5)
                            .overlay(
                                Circle()
                                    .stroke(statusColor, lineWidth: 3)
                            )

                        // Scan lines effect
                        ForEach(0..<8) { i in
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: size * 0.5, height: 2)
                                .offset(y: -size * 0.25 + CGFloat(i) * size * 0.5 / 8)
                        }

                        // Posture indicator dot - moves based on pitch and roll
                        Circle()
                            .fill(Color.white)
                            .frame(width: size * 0.08, height: size * 0.08)
                            .shadow(color: .white, radius: 10)
                            .offset(
                                x: roll * size * 0.15,
                                y: -pitch * size * 0.15
                            )
                    }
                    .clipShape(Circle())
                }
                .rotation3DEffect(
                    .radians(pitch * 1.2),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.5
                )
                .rotation3DEffect(.radians(roll * 0.8), axis: (x: 0, y: 1, z: 0))
                .shadow(color: statusColor.opacity(0.6), radius: 30)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pitch)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: roll)

                // Floating particles
                ForEach(0..<12) { i in
                    Circle()
                        .fill(statusColor)
                        .frame(width: 4, height: 4)
                        .offset(
                            x: cos(Double(i) * .pi / 6 + rotation * 0.02) * size * 0.4,
                            y: sin(Double(i) * .pi / 6 + rotation * 0.02) * size * 0.4
                        )
                        .opacity(0.6)
                        .blur(radius: 1)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    private var statusColor: Color {
        switch postureStatus {
        case .good: return .white
        case .forwardLean, .sidewaysLean, .poorPosture: return .white
        case .unknown: return .white
        }
    }
}

struct PostureVisualizer_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PostureVisualizer(pitch: 0.3, roll: 0.1, postureStatus: .forwardLean)
                .frame(height: 400)
                .background(Color.black.opacity(0.8))
        }
    }
}
