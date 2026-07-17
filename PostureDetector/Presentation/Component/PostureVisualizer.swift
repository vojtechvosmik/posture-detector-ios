//
//  PostureVisualizer.swift
//  PostureDetector
//
//  A live "posture radar": a glowing dot — your head — that you keep centred in
//  the target. A tension line shows how far and which way you're off; the centre
//  zone locks green the moment you're aligned. Designed for a dark, glowing hero.
//

import SwiftUI

struct PostureVisualizer: View {
    let pitch: Double
    let roll: Double
    let postureStatus: PostureStatus

    @State private var pulse = false
    @State private var sweep = false

    private var isGood: Bool { postureStatus == .good }

    private var tint: Color {
        switch postureStatus {
        case .good: return Aura.green
        case .forwardLean, .sidewaysLean, .poorPosture: return Aura.coral
        case .unknown: return Aura.accent
        }
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = s * 0.4
            let cRoll = min(max(roll, -0.5), 0.5)
            let cPitch = min(max(pitch, -0.5), 0.5)
            let dx = CGFloat(cRoll / 0.5) * r
            let dy = CGFloat(-cPitch / 0.5) * r
            let dist = min(1, hypot(dx, dy) / r)

            ZStack {
                radarField(s)
                sweepArc(s)
                targetZone(s)
                if dist > 0.12 { tensionLine(s: s, dx: dx, dy: dy) }
                dotGlow(s: s, dx: dx, dy: dy, dist: dist)
                dot(s: s, dx: dx, dy: dy)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 0.45), value: postureStatus)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
                withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) { sweep = true }
            }
        }
    }

    // MARK: - Layers

    private func radarField(_ s: CGFloat) -> some View {
        ZStack {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    .frame(width: s * 0.27 * CGFloat(i), height: s * 0.27 * CGFloat(i))
            }
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: s * 0.82, height: 1)
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: s * 0.82)
        }
    }

    private func sweepArc(_ s: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: 0.14)
            .stroke(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: s * 0.81, height: s * 0.81)
            .rotationEffect(.degrees(sweep ? 360 : 0))
    }

    private func targetZone(_ s: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(isGood ? 0.16 : 0.05))
                .frame(width: s * 0.26, height: s * 0.26)
            Circle()
                .stroke(tint.opacity(isGood ? 0.95 : 0.45),
                        style: StrokeStyle(lineWidth: 2, dash: isGood ? [] : [4, 5]))
                .frame(width: s * 0.26, height: s * 0.26)
                .scaleEffect(isGood && pulse ? 1.08 : 1.0)
        }
    }

    private func tensionLine(s: CGFloat, dx: CGFloat, dy: CGFloat) -> some View {
        Path { p in
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: dx, y: dy))
        }
        .stroke(
            LinearGradient(colors: [tint.opacity(0), tint.opacity(0.8)], startPoint: .top, endPoint: .bottom),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dx)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dy)
    }

    private func dotGlow(s: CGFloat, dx: CGFloat, dy: CGFloat, dist: CGFloat) -> some View {
        Circle()
            .fill(tint)
            .frame(width: s * 0.5, height: s * 0.5)
            .blur(radius: s * 0.16)
            .opacity(0.25 + Double(dist) * 0.35)
            .offset(x: dx, y: dy)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dx)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dy)
    }

    private func dot(s: CGFloat, dx: CGFloat, dy: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: s * 0.12, height: s * 0.12)
                .shadow(color: tint.opacity(0.9), radius: s * 0.05)
            Circle()
                .fill(RadialGradient(colors: [.white, .white.opacity(0.2)], center: .init(x: 0.35, y: 0.35),
                                     startRadius: 0, endRadius: s * 0.06))
                .frame(width: s * 0.05, height: s * 0.05)
        }
        .offset(x: dx, y: dy)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dx)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dy)
    }
}

struct PostureVisualizer_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PostureVisualizer(pitch: 0.01, roll: 0.0, postureStatus: .good)
                .frame(height: 220)
            PostureVisualizer(pitch: 0.32, roll: -0.24, postureStatus: .poorPosture)
                .frame(height: 220)
        }
        .padding(40)
        .background(Color(red: 0.05, green: 0.05, blue: 0.12))
    }
}
