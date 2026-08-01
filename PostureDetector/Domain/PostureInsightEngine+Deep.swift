//
//  PostureInsightEngine+Deep.swift
//  PostureDetector
//
//  The deep half of the coach: rules that read intraday patterns rather than
//  daily totals. These are the things the daily record cannot know — when in
//  the day posture fails, how long it holds inside a session, which context
//  it fails in, which direction it fails in, and how quickly it recovers.
//
//  Every rule here follows the same contract: state the pattern with the
//  user's own numbers, then give a step that is specific enough to act on
//  today and concrete enough to check next week.
//

import Foundation

extension PostureInsightEngine {

    /// Pattern-level insights. Empty until there is enough intraday data —
    /// the analyzer returns nil rather than guessing.
    static func deepInsights(from samples: [PostureDaySamples],
                             now: Date = Date()) -> [PostureInsight] {
        let patterns = PosturePatternAnalyzer.patterns(from: samples, now: now)
        guard patterns.coveredDays >= 5 else { return [] }

        return [
            worstBlockInsight(patterns),
            afternoonDipInsight(patterns),
            bestBlockInsight(patterns),
            decayInsight(patterns),
            contextInsight(patterns),
            leanInsight(patterns),
            episodeInsight(patterns),
            alertResponseInsight(patterns),
            exerciseInsight(patterns)
        ].compactMap { $0 }
    }

    // MARK: - Time of day

    private static func worstBlockInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard let block = p.worstBlock else { return nil }
        let drop = abs(block.comparison.delta)
        let from = clock(block.start)
        let breakTime = clock(block.start, minusMinutes: 15)

        return make("deep.worstBlock", .pattern, .warning, "clock.badge.exclamationmark",
                    "Your \(from) slump costs \(drop) points",
                    "Between \(from) and \(clock(block.end)) you average \(block.comparison.aScore) against \(block.comparison.bScore) the rest of the day — the same dip on \(block.comparison.days) of your tracked days.",
                    "Put a five-minute walk at \(breakTime), before the dip rather than after it, and keep it there for a week. Breaks taken ahead of a known slump work; breaks taken once you already feel it do not.",
                    92, delta: block.comparison.delta)
    }

    private static func afternoonDipInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard p.worstBlock == nil, let dip = p.afternoonDip, dip.isSolid, dip.delta < 0 else { return nil }
        return make("deep.afternoonDip", .pattern, .warning, "sun.max.fill",
                    "Afternoons cost you \(abs(dip.delta)) points",
                    "From 13:00 you average \(dip.aScore), against \(dip.bScore) in the morning — measured on the \(dip.days) days where you tracked both halves.",
                    "Move your most demanding desk work into the morning and put the meetings or admin after lunch. Then add one stand-up break at 13:30, which is where the decline starts rather than where you notice it.",
                    88, delta: dip.delta)
    }

    private static func bestBlockInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard p.worstBlock == nil, p.afternoonDip == nil,
              let best = p.bestBlock, best.score >= 75 else { return nil }
        return make("deep.bestBlock", .pattern, .positive, "sunrise.fill",
                    "You are strongest around \(clock(best.start))",
                    "Between \(clock(best.start)) and \(clock(best.end)) you average \(best.score) — your best stretch of the day by a clear margin.",
                    "Schedule your longest desk block into that window and leave calls or reading for the weaker hours. Working with your own curve is worth more than trying to hold posture against it.",
                    82)
    }

    // MARK: - Session shape

    private static func decayInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard let drop = p.decayDrop else { return nil }
        let timerAt = max(20, drop.holdsMinutes - 10)
        return make("deep.sessionDecay", .duration, .neutral, "hourglass",
                    "Your posture holds for about \(drop.holdsMinutes) minutes",
                    "You average \(drop.early) in the first half hour of a session and \(drop.late) once you pass \(drop.holdsMinutes) minutes. The position is fine; the endurance runs out.",
                    "Set a repeating \(timerAt)-minute timer and stand up for two minutes when it fires — before the drop, not after. Postural muscles recover in about that long, which is why short frequent breaks beat one long one.",
                    90, delta: drop.late - drop.early)
    }

    // MARK: - Context

    private static func contextInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard let gap = p.modeGap else { return nil }
        let weakest = gap.weakest
        let difference = gap.rest.score - weakest.score

        let advice: String
        switch weakest.mode {
        case .desk:
            advice = "That gap is furniture, not willpower. Measure two things today: the top of your screen should sit at eye level, and your feet should rest flat with your knees at about a right angle. Fix those, then compare next week."
        case .relaxed:
            advice = "Relaxed time is usually a sofa or a bed, where the screen ends up far below eye level. Prop the device up so you look forward rather than down, and put something firm behind your lower back."
        case .active:
            advice = "Walking scores drop when you read while moving. Hold the phone higher — closer to chest height than waist height — or wait until you stop to reply."
        case .custom:
            advice = "Your custom thresholds may simply be stricter than your other modes. Compare the numbers you set against the Desk preset before treating this as a posture problem."
        }

        return make("deep.context", .pattern, .warning, weakest.mode.icon,
                    "\(weakest.mode.displayName) is your weak context",
                    "In \(weakest.mode.displayName) mode you average \(weakest.score) across \(Int(weakest.minutes / 60)) hours, while everything else sits at \(gap.rest.score).",
                    advice,
                    93, delta: -difference)
    }

    private static func leanInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard let forwardShare = p.leanForwardShare else { return nil }
        let percent = Int((forwardShare * 100).rounded())

        if percent >= 80 {
            return make("deep.leanForward", .pattern, .neutral, "arrow.down.forward.and.arrow.up.backward",
                        "\(percent)% of it is forward head",
                        "Almost all of your slouched time is the head moving forward and down rather than tilting to one side — a single, specific failure mode.",
                        "This is the one that responds to screen height. Raise the display until the top edge is level with your eyes, which usually means a stand or a couple of books under a laptop, and give it a week before judging.",
                        86)
        }
        if percent <= 55 {
            return make("deep.leanSideways", .pattern, .neutral, "arrow.left.and.right",
                        "\(100 - percent)% of it is side lean",
                        "An unusually large share of your bad time is leaning to one side rather than forward, which points at asymmetry in the setup rather than at screen height.",
                        "Check three things on the side you lean toward: an armrest you rest on, a mouse placed far from the keyboard, and a screen that is not centred in front of you. Side lean is nearly always one of those.",
                        86)
        }
        return nil
    }

    // MARK: - Episodes and recovery

    private static func episodeInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard let episodes = p.episodes else { return nil }
        let perDay = Int(episodes.perDay.rounded())
        let median = Int(episodes.medianMinutes.rounded())

        if episodes.longShare >= 0.5 && episodes.medianMinutes >= 8 {
            return make("deep.episodesLong", .run, .warning, "hourglass.bottom.half.filled",
                        "Your slouches last \(median) minutes",
                        "You settle into bad posture and stay there — half of your slouched time comes from stretches of ten minutes or more, and the longest ran \(Int(episodes.longestMinutes)) minutes.",
                        "Long episodes mean the alert is arriving too late or too quietly to register. Shorten the alert delay in Settings and switch the sound on for a week — the aim is to be interrupted at two minutes rather than at twelve.",
                        89)
        }
        if episodes.perDay >= 8 && episodes.medianMinutes <= 4 {
            return make("deep.episodesMany", .run, .neutral, "waveform.path",
                        "\(perDay) short slouches a day",
                        "You drift out of position often but catch it quickly — a median episode lasts \(median == 0 ? 1 : median) minutes. Frequent short lapses point at support rather than attention.",
                        "Your back is doing work your chair should be doing. Add a lumbar cushion or raise the seat so your hips sit slightly above your knees, then check whether the count falls next week.",
                        87)
        }
        return nil
    }

    private static func alertResponseInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard let alerts = p.alerts else { return nil }
        let seconds = Int(alerts.medianSeconds.rounded())

        if let previous = alerts.previousMedianSeconds {
            let before = Int(previous.rounded())
            if before - seconds >= 8 {
                return make("deep.alertFaster", .alerts, .celebration, "bolt.fill",
                            "You correct \(before - seconds) seconds faster",
                            "After an alert you are back upright in about \(seconds) seconds, down from \(before) a fortnight ago. Reaction time improves weeks before the score does.",
                            "This is the moment to make the target harder rather than easier: tighten the detection threshold a notch so the alerts keep catching the small slips you now fix on your own.",
                            88, delta: before - seconds)
            }
            if seconds - before >= 8 {
                return make("deep.alertSlower", .alerts, .warning, "bolt.slash",
                            "Slower to correct than before",
                            "You now take about \(seconds) seconds to return to position after an alert, against \(before) a fortnight ago — a sign that the nudges are becoming background noise.",
                            "Change the signal rather than the threshold: switch the alert sound on if it is off, or off and back to haptics if it has been on for months. Novelty is what restores a response, not volume.",
                            87, delta: before - seconds)
            }
        }

        if seconds >= 45 {
            return make("deep.alertSlow", .alerts, .warning, "bolt.slash",
                        "You take \(seconds) seconds to react",
                        "That is the median gap between an alert and returning to an upright position, measured across \(alerts.count) alerts. Long response times mean the alert is registering as information rather than as a prompt.",
                        "Turn the alert sound on for a fortnight, or move the notification to a delay of five seconds so it arrives while the slouch still feels deliberate. Reacting inside fifteen seconds is a realistic target.",
                        86)
        }
        if seconds <= 15 {
            return make("deep.alertFast", .alerts, .positive, "bolt.fill",
                        "You correct within \(seconds) seconds",
                        "Across \(alerts.count) alerts you return to position almost immediately, which is the behaviour that eventually makes the alerts unnecessary.",
                        "Keep the thresholds where they are — at this response rate the nudges are working exactly as intended, and tightening them is the fastest way to start ignoring them.",
                        80)
        }
        return nil
    }

    // MARK: - Exercise

    private static func exerciseInsight(_ p: PosturePatterns) -> PostureInsight? {
        guard let effect = p.exerciseEffect, effect.delta > 0 else { return nil }
        let target = p.worstBlock.map { clock($0.start, minusMinutes: 15) }

        let advice: String
        if let target = target {
            advice = "Move one session to \(target), just ahead of your weakest stretch of the day. You already know the effect is real for you — this puts it where it does the most work."
        } else {
            advice = "Anchor one session to a fixed point in your day rather than doing it when you remember. Mid-afternoon works for most people, because that is when postural endurance is lowest."
        }

        return make("deep.exerciseEffect", .recovery, .celebration, "sparkles",
                    "Move breaks are worth \(effect.delta) points",
                    "In the three hours after a guided exercise you average \(effect.aScore), against \(effect.bScore) in the same hours on days you skip it — across \(effect.days) comparable days.",
                    advice,
                    91, delta: effect.delta)
    }

    // MARK: - Helpers

    private static func clock(_ hour: Int, minusMinutes minutes: Int = 0) -> String {
        var total = hour * 60 - minutes
        if total < 0 { total += 24 * 60 }
        return String(format: "%02d:%02d", (total / 60) % 24, total % 60)
    }
}
