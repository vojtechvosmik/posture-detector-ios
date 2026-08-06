//
//  CoachPanel.swift
//  PostureDetector
//
//  The coach's UI. One colour language — score colours for data, a signed
//  arrow for direction — and one row shape reused everywhere.
//
//    CoachPanel       — calendar entry point: headline, the day's shape, top tip
//    CoachDetailSheet — summary, tips for you, your insights
//    CoachMiniCard    — the quiet home-screen one-liner
//

import SwiftUI

// MARK: - Shared atoms

/// Green up / red down for a signed change; violet when there is nothing to sign.
private func coachTint(for delta: Int?) -> Color {
    guard let delta = delta else { return Aura.violet }
    return delta >= 0 ? Aura.green : Aura.coral
}

private struct CoachByline: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [Aura.violet, Aura.accent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("AI COACH")
                .font(.system(size: 10, weight: .heavy)).tracking(1.3)
                .foregroundColor(.secondary)
        }
    }
}

/// The one piece of directional colour: an arrow and its value.
private struct CoachDelta: View {
    let delta: Int
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: compact ? 15 : 26, weight: .heavy))
            Text("\(delta >= 0 ? "+" : "−")\(abs(delta))")
                .font(.system(size: compact ? 11 : 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(coachTint(for: delta))
    }
}

/// A signed change as a small chip, for rows that need a number on the right.
private struct CoachDeltaChip: View {
    let delta: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 8, weight: .heavy))
            Text("\(abs(delta))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(coachTint(for: delta))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(coachTint(for: delta).opacity(0.13), in: Capsule())
    }
}

private struct CoachSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .heavy)).tracking(1.2)
            .foregroundColor(.secondary)
    }
}

/// The shape of a typical day: one bar per tracked clock hour, coloured the
/// same way the calendar rings are, so the two read as one language.
private struct CoachHourShape: View {
    let hours: [HourStat]
    var height: CGFloat = 38
    var showsLabels: Bool = true

    private var span: [Int] {
        guard let first = hours.map({ $0.hour }).min(),
              let last = hours.map({ $0.hour }).max() else { return [] }
        return Array(first...last)
    }

    private var weakest: Int? { hours.min(by: { $0.score < $1.score })?.hour }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(span, id: \.self) { hour in
                    let stat = hours.first { $0.hour == hour }
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(stat.map { Aura.scoreColor($0.score).opacity(hour == weakest ? 1 : 0.75) }
                              ?? Aura.softFill)
                        .frame(height: max(4, height * CGFloat(stat?.score ?? 8) / 100))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height, alignment: .bottom)

            if showsLabels, let first = span.first, let last = span.last {
                HStack {
                    Text(String(format: "%02d:00", first))
                    Spacer()
                    if let weakest = weakest {
                        Text("weakest \(String(format: "%02d:00", weakest))")
                            .foregroundColor(Aura.coral)
                    }
                    Spacer()
                    Text(String(format: "%02d:00", last))
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            }
        }
    }
}

/// Progress while the intraday data is still building. Only days with a
/// session count toward it, so weekends are never required.
private struct CoachDeepProgress: View {
    let progress: DeepReadiness
    /// Drops the explanation — the home card has no room for it.
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                CoachSectionLabel(text: "DEEP ANALYSIS")
                Spacer()
                Text("\(progress.days) / \(progress.target) days")
                    .font(.system(size: 10.5, weight: .bold)).foregroundColor(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Aura.softFill)
                    Capsule()
                        .fill(LinearGradient(colors: [Aura.violet, Aura.accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * progress.fraction))
                }
            }
            .frame(height: 6)

            if !compact {
                Text("Patterns in time of day, context and fatigue unlock after \(progress.target) tracked days — \(progress.remaining) to go. Only days with a session count, so weekends are optional.")
                    .font(.system(size: 11.5)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Calendar entry point

struct CoachPanel: View {
    let report: CoachReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CoachByline()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.45))
            }

            HStack(alignment: .top, spacing: 14) {
                if let delta = report.headline.delta {
                    CoachDelta(delta: delta).frame(width: 44).padding(.top, 2)
                } else {
                    Image(systemName: report.headline.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(coachTint(for: nil))
                        .frame(width: 44)
                        .padding(.top, 3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(report.headline.title)
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(report.headline.summary)
                        .font(.system(size: 13.5)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !report.hourProfile.isEmpty {
                Rectangle().fill(Aura.hairline).frame(height: 1)
                VStack(alignment: .leading, spacing: 7) {
                    CoachSectionLabel(text: "YOUR TYPICAL DAY")
                    CoachHourShape(hours: report.hourProfile)
                }
            }

            if let tip = report.tips.first {
                Rectangle().fill(Aura.hairline).frame(height: 1)
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Aura.violet)
                        .frame(width: 24, height: 24)
                        .background(Aura.violet.opacity(0.13),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tip.title)
                            .font(.system(size: 13.5, weight: .semibold)).foregroundColor(.primary)
                        Text(tip.note)
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }

            if let progress = report.deepProgress {
                Rectangle().fill(Aura.hairline).frame(height: 1)
                CoachDeepProgress(progress: progress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .auraCard(padding: 17, cornerRadius: 22)
        // Same corner bracket as the home card, sized to this card's radius.
        .overlay(alignment: .topLeading) {
            CoachCornerAccent(radius: 22, arm: 44)
                .stroke(
                    LinearGradient(colors: [Aura.violet.opacity(0.85), Aura.accent.opacity(0)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Detail sheet

struct CoachDetailSheet: View {
    let report: CoachReport
    @Environment(\.dismiss) private var dismiss

    private var tint: Color { coachTint(for: report.headline.delta) }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    summary
                    if !report.hourProfile.isEmpty { dayShape }
                    if !report.tips.isEmpty { tips }
                    if !report.signals.isEmpty { insights }
                    if let progress = report.deepProgress {
                        CoachDeepProgress(progress: progress)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .auraCard(padding: 0, cornerRadius: 18)
                    }
                }
                .padding(.bottom, 36)
            }
            .background(AuraBackground())
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Aura.accent)
                }
            }
        }
    }

    /// A tinted band so the top of the sheet carries weight instead of text.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(report.headline.category.displayName.uppercased())
                    .font(.system(size: 9.5, weight: .heavy)).tracking(1.1)
                    .foregroundColor(tint)
                Spacer()
                if let delta = report.headline.delta {
                    CoachDelta(delta: delta)
                }
            }

            Text(report.headline.title)
                .font(.system(size: 26, weight: .bold)).foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(report.headline.summary)
                .font(.system(size: 15)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                ForEach(Array(report.metrics.enumerated()), id: \.element.id) { index, metric in
                    if index > 0 {
                        Rectangle().fill(Aura.hairline).frame(width: 1, height: 20)
                    }
                    VStack(spacing: 2) {
                        Text(metric.value)
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                            .monospacedDigit()
                        Text(metric.label.uppercased())
                            .font(.system(size: 8, weight: .heavy)).tracking(0.3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [tint.opacity(0.13), tint.opacity(0.03)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(alignment: .bottom) { Rectangle().fill(Aura.hairline).frame(height: 1) }
    }

    /// The reasoning, set as a pull quote rather than another card of text.
    private var summary: some View {
        HStack(alignment: .top, spacing: 14) {
            Capsule().fill(tint.opacity(0.5)).frame(width: 3)
            Text(report.headline.detail)
                .font(.system(size: 15.5)).foregroundColor(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }

    private var dayShape: some View {
        section("YOUR TYPICAL DAY") {
            CoachHourShape(hours: report.hourProfile, height: 60)
                .padding(16)
                .frame(maxWidth: .infinity)
                .auraCard(padding: 0, cornerRadius: 18)
        }
    }

    private var tips: some View {
        section("TIPS FOR YOU") {
            VStack(spacing: 8) {
                ForEach(Array(report.tips.enumerated()), id: \.element.id) { index, tip in
                    HStack(spacing: 13) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(tint, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title)
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                            Text(tip.note)
                                .font(.system(size: 12.5)).foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)

                        Image(systemName: tip.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .auraCard(padding: 0, cornerRadius: 16)
                }
            }
        }
    }

    private var insights: some View {
        section("YOUR INSIGHTS") {
            VStack(spacing: 8) {
                ForEach(report.signals) { signal in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 9) {
                            Image(systemName: signal.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(signal.title)
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            if let delta = signal.delta {
                                CoachDeltaChip(delta: delta)
                            }
                        }
                        Text(signal.summary)
                            .font(.system(size: 12.5)).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .auraCard(padding: 0, cornerRadius: 16)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CoachSectionLabel(text: title)
            content()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Home screen card

/// Same skeleton as the other home cards — `auraCard` shell, copy on the left,
/// the value on the right — but keeps the coach's own byline, because that is
/// what marks it as the one card that talks rather than measures.
struct CoachMiniCard: View {
    let insight: PostureInsight
    /// Set while the deep analysis is still collecting days.
    var progress: DeepReadiness?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                CoachByline()
                Text(insight.title)
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.summary)
                    .font(.system(size: 13)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            // The value sits on the right, the way the score does on Today.
            if let delta = insight.delta {
                VStack(spacing: 0) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 20, weight: .heavy))
                    Text("\(delta >= 0 ? "+" : "−")\(abs(delta))")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundColor(coachTint(for: delta))
            } else {
                Image(systemName: insight.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(coachTint(for: nil))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary.opacity(0.4))
        }

            if let progress = progress {
                Rectangle().fill(Aura.hairline).frame(height: 1)
                CoachDeepProgress(progress: progress, compact: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .auraCard()
        // Just the one corner: a short gradient bracket that fades out into the
        // normal card edge, next to the sparkle.
        .overlay(alignment: .topLeading) {
            CoachCornerAccent(radius: 24, arm: 44)
                .stroke(
                    LinearGradient(colors: [Aura.violet.opacity(0.85), Aura.accent.opacity(0)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
                .allowsHitTesting(false)
        }
    }
}

/// The top-left corner of the card, drawn as a short bracket: down the arc and
/// a little way along each edge, so it can be stroked on its own.
private struct CoachCornerAccent: Shape {
    var radius: CGFloat
    var arm: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 0.9
        var path = Path()
        path.move(to: CGPoint(x: radius + arm, y: inset))
        path.addLine(to: CGPoint(x: radius, y: inset))
        path.addArc(center: CGPoint(x: radius, y: radius),
                    radius: radius - inset,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(180),
                    clockwise: true)
        path.addLine(to: CGPoint(x: inset, y: radius + arm))
        return path
    }
}
