//
//  PaywallView.swift
//  PostureDetector
//
//  Immersive "PRO" paywall matching the onboarding's aurora language: a living
//  gradient backdrop on a deep base, a glowing hero orb, glass benefit rows and
//  plan cards, and a single bright gradient CTA. The purchase itself is mocked
//  in SubscriptionManager — this view is production-shaped and only needs the
//  manager swapped to real StoreKit later.
//

import SwiftUI

struct PaywallView: View {
    @ObservedObject var subscriptions = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    /// When true the close button only appears after a short delay (the classic
    /// "let the offer land first" pattern). Set false for a fully dismissable
    /// paywall opened from settings.
    var delayClose: Bool = true

    @State private var selectedPlan: SubscriptionManager.Plan = .yearly
    @State private var showClose = false
    @State private var appeared = false

    // Theme (shared with the onboarding aurora)
    private let accent = Color(red: 0.36, green: 0.52, blue: 1.0)
    private let violet = Color(red: 0.58, green: 0.40, blue: 0.98)
    private let success = Color(red: 0.22, green: 0.80, blue: 0.55)

    private var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            PaywallAurora()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    hero
                    benefits
                    planPicker
                }
                .padding(.horizontal, 36)
                .padding(.top, 44)
                .padding(.bottom, 300)
            }

            VStack {
                closeBar
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer()
                purchaseFooter
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: handleAppear)
        .interactiveDismissDisabled(delayClose && !showClose)
    }

    // MARK: - Close bar

    private var closeBar: some View {
        HStack {
            if showClose {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.12), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .transition(.opacity)
            }
            Spacer()
            Button(action: restore) {
                Text("Restore")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 12)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 20) {
            PaywallGlowOrb(systemName: "crown.fill", tint: violet, size: 104)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text("Postura")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("PRO")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(accentGradient, in: Capsule())
                }

                Text("Unlock your full posture potential.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(spacing: 12) {
            benefitRow("infinity", "Unlimited monitoring", "Track your posture all day, every day")
            benefitRow("chart.line.uptrend.xyaxis", "Advanced insights", "Detailed trends, history & daily scores")
            benefitRow("bell.badge.fill", "Smart custom alerts", "Fine-tune sensitivity, delays & sounds")
            benefitRow("bolt.heart.fill", "Priority updates", "New features & posture programs first")
        }
    }

    private func benefitRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentGradient)
                    .frame(width: 44, height: 44)
                    .shadow(color: violet.opacity(0.35), radius: 8, y: 3)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Plans

    private var planPicker: some View {
        VStack(spacing: 12) {
            ForEach(SubscriptionManager.Plan.all) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: SubscriptionManager.Plan) -> some View {
        let selected = selectedPlan == plan
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedPlan = plan }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(selected ? Color.white : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if selected { Circle().fill(Color.white).frame(width: 13, height: 13) }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(success, in: Capsule())
                        }
                    }
                    Text(plan.subtitle ?? "Billed \(plan.price) every \(plan.period)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text(plan.perWeek ?? "/ \(plan.period)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(selected ? 0.14 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? Color.white.opacity(0.55) : Color.white.opacity(0.10),
                        lineWidth: selected ? 1.5 : 1))
            .shadow(color: selected ? violet.opacity(0.4) : .clear, radius: 16, y: 6)
        }
        .buttonStyle(PaywallPressableStyle())
    }

    // MARK: - Footer / CTA

    private var purchaseFooter: some View {
        VStack(spacing: 12) {
            Button(action: purchase) {
                ZStack {
                    if subscriptions.isPurchasing {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: violet.opacity(0.5), radius: 16, y: 8)
            }
            .buttonStyle(PaywallPressableStyle())
            .disabled(subscriptions.isPurchasing)

            Text(reassuranceText)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Text("Terms").underline()
                Text("Privacy").underline()
                Text("Restore").onTapGesture(perform: restore)
            }
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.11).opacity(0),
                         Color(red: 0.05, green: 0.05, blue: 0.11).opacity(0.85),
                         Color(red: 0.05, green: 0.05, blue: 0.11)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        )
    }

    private var ctaTitle: String {
        selectedPlan.hasFreeTrial ? "Start Free Trial" : "Continue"
    }

    private var reassuranceText: String {
        if selectedPlan.hasFreeTrial {
            return "7 days free, then \(selectedPlan.price)/\(selectedPlan.period). Cancel anytime."
        } else {
            return "\(selectedPlan.price)/\(selectedPlan.period). Cancel anytime."
        }
    }

    // MARK: - Actions

    private func handleAppear() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        if delayClose {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation { showClose = true }
            }
        } else {
            showClose = true
        }
    }

    private func purchase() {
        Task {
            let ok = await subscriptions.purchase(selectedPlan)
            if ok { close() }
        }
    }

    private func restore() {
        Task {
            let ok = await subscriptions.restore()
            if ok { close() }
        }
    }

    private func close() {
        dismiss()
    }
}

// MARK: - Aurora backdrop

private struct PaywallAurora: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.09),
                         Color(red: 0.07, green: 0.06, blue: 0.16)],
                startPoint: .top, endPoint: .bottom
            )
            blob(Color(red: 0.24, green: 0.44, blue: 1.0), 400, x: animate ? -110 : -70, y: animate ? -300 : -360)
            blob(Color(red: 0.56, green: 0.32, blue: 0.96), 440, x: animate ? 150 : 110, y: animate ? -150 : -90)
            blob(Color(red: 0.86, green: 0.32, blue: 0.68), 360, x: animate ? -120 : -70, y: animate ? 280 : 340)
            blob(Color(red: 0.20, green: 0.68, blue: 0.95), 320, x: animate ? 140 : 100, y: animate ? 320 : 270)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { animate = true }
        }
    }

    private func blob(_ color: Color, _ size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size).blur(radius: 95).opacity(0.45).offset(x: x, y: y)
    }
}

// MARK: - Glow orb

private struct PaywallGlowOrb: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 104
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle().fill(tint).frame(width: size * 1.7, height: size * 1.7).blur(radius: 60).opacity(0.45)

            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.white.opacity(0.12 - Double(i) * 0.03), lineWidth: 1)
                    .frame(width: size + 40 + CGFloat(i) * 40, height: size + 40 + CGFloat(i) * 40)
                    .scaleEffect(breathe ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: breathe)
            }

            Circle()
                .fill(LinearGradient(colors: [tint, tint.opacity(0.68)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: tint.opacity(0.6), radius: 26, y: 10)

            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundColor(.white)
        }
        .onAppear { breathe = true }
    }
}

private struct PaywallPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    PaywallView(delayClose: false)
}
