//
//  DebugDataScreen.swift
//  PostureDetector
//
//  Debug builds only: load a named data scenario so every state the app can be
//  in — empty, waiting for deep analysis, mid-gap, on a streak, slumping after
//  lunch — can be reached without waiting weeks for real sessions.
//
//  Each scenario writes both halves of the model: the daily records that drive
//  the calendar and the shallow coach, and the intraday samples that the deep
//  analysis needs.
//

#if DEBUG

import SwiftUI

// MARK: - Scenario

struct DebugScenario: Identifiable {
    enum Group: String, CaseIterable {
        case starting = "GETTING STARTED"
        case coverage = "COVERAGE & GAPS"
        case quality  = "SCORES & TRENDS"
        case deep     = "DEEP ANALYSIS"
        case appState = "APP STATE"
    }

    let id: String
    let group: Group
    let title: String
    let detail: String
    let apply: () -> Void
}

// MARK: - Screen

struct DebugDataScreen: View {
    @ObservedObject private var subscriptions = SubscriptionManager.shared
    @State private var applied: String?

    var body: some View {
        List {
            ForEach(DebugScenario.Group.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(DebugDataFactory.scenarios.filter { $0.group == group }) { scenario in
                        Button {
                            scenario.apply()
                            applied = scenario.id
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(scenario.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(scenario.detail)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                if applied == scenario.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            Section("CURRENT STATE") {
                HStack {
                    Text("PRO").font(.system(size: 15))
                    Spacer()
                    Text(subscriptions.isPro ? "active" : "free")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(subscriptions.isPro ? .green : .secondary)
                }
                HStack {
                    Text("Onboarding").font(.system(size: 15))
                    Spacer()
                    Text(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") ? "done" : "pending")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.secondary)
                }
            }

            Section {
                Text("Scenarios replace all posture data — both the daily records and the intraday samples the deep coach reads. Restart the app or switch tabs to see the effect.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        .navigationTitle("Sample data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Factory

enum DebugDataFactory {

    private static let calendar = Calendar.current

    // MARK: Building blocks

    /// One day of daily totals.
    private static func day(_ ago: Int, score: Int, hours: Double, alerts: Int? = nil) -> PostureHistory {
        let date = calendar.date(byAdding: .day, value: -ago, to: Date()) ?? Date()
        var history = PostureHistory(date: date)
        let total = hours * 3600
        let good = total * Double(score) / 100
        history.updateFromSession(goodSeconds: good,
                                  badSeconds: total - good,
                                  alerts: alerts ?? Int((total - good) / 420))
        return history
    }

    /// Deterministic jitter so scenarios look organic but reproduce exactly.
    private static func wobble(_ seed: Int, _ spread: Int) -> Int {
        let value = (seed &* 2654435761) % 1000
        return Int(Double(abs(value)) / 1000 * Double(spread * 2)) - spread
    }

    /// Writes daily records only — the deep coach will show its progress bar.
    private static func write(_ history: [PostureHistory]) {
        PostureSampleStore.shared.clearSamples()
        PostureDataStore.shared.replaceHistory(history)
    }

    /// Writes daily records plus matching intraday samples.
    private static func write(_ history: [PostureHistory], samples: [PostureDaySamples]) {
        PostureSampleStore.shared.replaceAll(with: samples.sorted { $0.date > $1.date })
        PostureDataStore.shared.replaceHistory(history)
    }

    /// Intraday samples for one day, shaped by an hourly score curve.
    private static func samples(_ ago: Int,
                                hours: [(hour: Int, score: Int, minutes: Double, mode: PostureMode)],
                                decayFrom: Int? = nil,
                                episodes: [(minutes: Double, recovery: Double?)] = [],
                                exerciseHour: Int? = nil) -> PostureDaySamples {
        let date = calendar.date(byAdding: .day, value: -ago, to: Date()) ?? Date()
        var day = PostureDaySamples(date: date)

        for entry in hours {
            let total = entry.minutes * 60
            let good = total * Double(entry.score) / 100
            let bad = total - good
            day.slots.append(PostureSlot(index: entry.hour * 4,
                                         totals: PostureTotals(good: good,
                                                               forward: bad * 0.88,
                                                               sideways: bad * 0.12),
                                         alerts: Int(bad / 600),
                                         mode: entry.mode.rawValue))
        }

        if let start = decayFrom {
            let curve: [(Int, Double, Int)] = [(0, 30, start),
                                               (1, 30, start - 5),
                                               (2, 60, start - 16),
                                               (3, 45, start - 22)]
            day.decay = curve.map { bucket, minutes, score in
                let total = minutes * 60
                let good = total * Double(max(score, 5)) / 100
                return PostureDecayBucket(bucket: bucket,
                                          totals: PostureTotals(good: good,
                                                                forward: total - good,
                                                                sideways: 0))
            }
        }

        for (index, episode) in episodes.enumerated() {
            let start = calendar.date(bySettingHour: 10 + index * 2, minute: 10, second: 0, of: date) ?? date
            day.episodes.append(SlouchEpisode(start: start,
                                              duration: episode.minutes * 60,
                                              alerted: episode.recovery != nil,
                                              recoverySeconds: episode.recovery))
        }

        if let hour = exerciseHour,
           let time = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: date) {
            day.exercises.append(time)
        }

        return day
    }

    private static func isWeekend(_ ago: Int) -> Bool {
        guard let date = calendar.date(byAdding: .day, value: -ago, to: Date()) else { return false }
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    /// A plain working-day curve at roughly the given score.
    private static func workday(_ score: Int) -> [(hour: Int, score: Int, minutes: Double, mode: PostureMode)] {
        [(9, score + 4, 55, .desk), (10, score + 2, 55, .desk), (11, score, 55, .desk),
         (14, score - 2, 55, .desk), (15, score - 3, 55, .desk), (16, score, 45, .desk),
         (20, score + 6, 40, .relaxed)]
    }

    // MARK: Scenarios

    static var scenarios: [DebugScenario] { starting + coverage + quality + deep + appState }

    private static var appState: [DebugScenario] {
        [
            DebugScenario(id: "resetOnboarding", group: .appState,
                          title: "Replay onboarding",
                          detail: "Clears the completion flag — onboarding appears immediately.") {
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            },
            DebugScenario(id: "resetPaywall", group: .appState,
                          title: "Replay intro paywall",
                          detail: "The paywall shows again on the next launch.") {
                UserDefaults.standard.set(false, forKey: "hasSeenInitialPaywall")
            },
            DebugScenario(id: "proOn", group: .appState,
                          title: "Turn PRO on",
                          detail: "Unlocks everything without a purchase.") {
                Task { @MainActor in SubscriptionManager.shared.setPro(true) }
            },
            DebugScenario(id: "proOff", group: .appState,
                          title: "Turn PRO off",
                          detail: "Back to the free tier.") {
                Task { @MainActor in SubscriptionManager.shared.setPro(false) }
            },
            DebugScenario(id: "freshInstall", group: .appState,
                          title: "Fresh install",
                          detail: "Wipes posture data, PRO, onboarding and paywall flags.") {
                write([])
                Task { @MainActor in SubscriptionManager.shared.setPro(false) }
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                UserDefaults.standard.set(false, forKey: "hasSeenInitialPaywall")
            }
        ]
    }

    private static var starting: [DebugScenario] {
        [
            DebugScenario(id: "empty", group: .starting,
                          title: "No data at all",
                          detail: "Empty state on every screen; the coach asks for a first session.") {
                write([])
            },
            DebugScenario(id: "firstDay", group: .starting,
                          title: "First session today",
                          detail: "One tracked day, score 62. Welcome insight, no trends yet.") {
                write([day(0, score: 62, hours: 1.5)])
            },
            DebugScenario(id: "threeDays", group: .starting,
                          title: "Three days in",
                          detail: "Early baseline. Deep analysis shows 0 / 14 — no intraday data yet.") {
                write((0...2).map { day($0, score: 68 + wobble($0, 6), hours: 3) })
            },
            DebugScenario(id: "firstWeek", group: .starting,
                          title: "First week complete",
                          detail: "Seven consecutive days, week-over-week comparisons unlock.") {
                write((0...6).map { day($0, score: 70 + wobble($0, 8), hours: 4) })
            }
        ]
    }

    private static var coverage: [DebugScenario] {
        [
            DebugScenario(id: "gapToday", group: .coverage,
                          title: "Nothing tracked today",
                          detail: "Streak of six days ending yesterday — the at-risk warning.") {
                write((1...6).map { day($0, score: 74 + wobble($0, 6), hours: 4) })
            },
            DebugScenario(id: "gap3", group: .coverage,
                          title: "Three-day gap",
                          detail: "Tracked until three days ago, then silence.") {
                write((3...9).map { day($0, score: 72 + wobble($0, 6), hours: 4) })
            },
            DebugScenario(id: "gap10", group: .coverage,
                          title: "Ten days away",
                          detail: "Long gap: stale trends, recalibration advice.") {
                write((10...20).map { day($0, score: 70 + wobble($0, 8), hours: 4) })
            },
            DebugScenario(id: "gapMonth", group: .coverage,
                          title: "Back after a month",
                          detail: "Nothing for 40 days, then one session today.") {
                write([day(0, score: 58, hours: 2)] + (40...52).map { day($0, score: 74, hours: 4) })
            },
            DebugScenario(id: "weekdaysOnly", group: .coverage,
                          title: "Weekdays only",
                          detail: "Four weeks of workdays, weekends never tracked.") {
                let history = (0...27).filter { !isWeekend($0) }
                    .map { day($0, score: 74 + wobble($0, 8), hours: 5) }
                let days = (0...27).filter { !isWeekend($0) }
                    .map { samples($0, hours: workday(74), decayFrom: 84) }
                write(history, samples: days)
            },
            DebugScenario(id: "sparse", group: .coverage,
                          title: "Sparse month",
                          detail: "Six scattered days in the last thirty.") {
                write([0, 4, 9, 15, 22, 27].map { day($0, score: 66 + wobble($0, 10), hours: 3) })
            }
        ]
    }

    private static var quality: [DebugScenario] {
        [
            DebugScenario(id: "improving", group: .quality,
                          title: "Improving fast",
                          detail: "This week well above last — big upward trend.") {
                write((0...13).map { day($0, score: $0 < 7 ? 84 - wobble($0, 4) : 63 + wobble($0, 4), hours: 4) })
            },
            DebugScenario(id: "declining", group: .quality,
                          title: "Slipping",
                          detail: "Sharp drop against last week.") {
                write((0...13).map { day($0, score: $0 < 7 ? 58 + wobble($0, 4) : 80 - wobble($0, 4), hours: 4) })
            },
            DebugScenario(id: "excellent", group: .quality,
                          title: "Excellent streak",
                          detail: "Three weeks above 85 with a long run and a personal best.") {
                write((0...20).map { day($0, score: $0 == 3 ? 97 : 87 + wobble($0, 4), hours: 5) })
            },
            DebugScenario(id: "rough", group: .quality,
                          title: "Rough patch",
                          detail: "Two weeks under 55 — setup-problem advice.") {
                write((0...13).map { day($0, score: 48 + wobble($0, 6), hours: 5) })
            },
            DebugScenario(id: "volatile", group: .quality,
                          title: "Very volatile",
                          detail: "Scores swinging 40 points day to day.") {
                write((0...20).map { day($0, score: $0 % 2 == 0 ? 88 : 46, hours: 4) })
            },
            DebugScenario(id: "alertHeavy", group: .quality,
                          title: "Alert storm",
                          detail: "Long days with a very high alert rate.") {
                write((0...13).map { day($0, score: 62, hours: 8, alerts: 45) })
            },
            DebugScenario(id: "shortSessions", group: .quality,
                          title: "Very short sessions",
                          detail: "Fifteen minutes a day — flattering scores, thin data.") {
                write((0...13).map { day($0, score: 88, hours: 0.25) })
            }
        ]
    }

    private static var deep: [DebugScenario] {
        [
            DebugScenario(id: "deepHalfway", group: .deep,
                          title: "Waiting: 7 of 14 days",
                          detail: "Intraday data half collected — progress bar visible.") {
                let history = (0...6).map { day($0, score: 74 + wobble($0, 6), hours: 5) }
                let days = (0...6).map { samples($0, hours: workday(74), decayFrom: 84) }
                write(history, samples: days)
            },
            DebugScenario(id: "deepAlmost", group: .deep,
                          title: "Waiting: 13 of 14 days",
                          detail: "One tracked day short of unlocking pattern analysis.") {
                let history = (0...12).map { day($0, score: 74 + wobble($0, 6), hours: 5) }
                let days = (0...12).map { samples($0, hours: workday(74), decayFrom: 84) }
                write(history, samples: days)
            },
            DebugScenario(id: "deepAfternoon", group: .deep,
                          title: "Afternoon slump",
                          detail: "Three weeks with a clear 14:00 dip and fatigue after an hour.") {
                var history: [PostureHistory] = []
                var days: [PostureDaySamples] = []
                for ago in 0...20 where !isWeekend(ago) {
                    history.append(day(ago, score: 71 + wobble(ago, 5), hours: 6))
                    days.append(samples(ago, hours: [
                        (9, 84, 55, .desk), (10, 86, 55, .desk), (11, 82, 55, .desk),
                        (14, 57, 55, .desk), (15, 55, 55, .desk), (16, 68, 45, .desk),
                        (20, 87, 40, .relaxed)
                    ], decayFrom: 85, episodes: [(3, 24), (2.5, 28), (4, 20)]))
                }
                write(history, samples: days)
            },
            DebugScenario(id: "deepContext", group: .deep,
                          title: "Desk is the weak context",
                          detail: "Desk mode far below Relaxed — furniture, not willpower.") {
                var history: [PostureHistory] = []
                var days: [PostureDaySamples] = []
                for ago in 0...20 where !isWeekend(ago) {
                    history.append(day(ago, score: 70 + wobble(ago, 5), hours: 6))
                    days.append(samples(ago, hours: [
                        (9, 61, 60, .desk), (10, 63, 60, .desk), (11, 60, 60, .desk),
                        (14, 62, 60, .desk),
                        (19, 88, 60, .relaxed), (20, 86, 45, .relaxed)
                    ], decayFrom: 74))
                }
                write(history, samples: days)
            },
            DebugScenario(id: "deepExercise", group: .deep,
                          title: "Move breaks working",
                          detail: "Exercise every other day lifts the hours that follow.") {
                var history: [PostureHistory] = []
                var days: [PostureDaySamples] = []
                for ago in 0...20 where !isWeekend(ago) {
                    let didExercise = ago % 2 == 0
                    history.append(day(ago, score: didExercise ? 82 : 66, hours: 5))
                    days.append(samples(ago, hours: [
                        (9, 80, 55, .desk), (10, 80, 55, .desk),
                        (13, didExercise ? 88 : 62, 55, .desk),
                        (14, didExercise ? 86 : 60, 55, .desk),
                        (15, didExercise ? 84 : 61, 55, .desk)
                    ], exerciseHour: didExercise ? 12 : nil))
                }
                write(history, samples: days)
            },
            DebugScenario(id: "deepSlowAlerts", group: .deep,
                          title: "Slow to react to alerts",
                          detail: "Long slouch episodes with 70-second recovery times.") {
                var history: [PostureHistory] = []
                var days: [PostureDaySamples] = []
                for ago in 0...16 where !isWeekend(ago) {
                    history.append(day(ago, score: 63, hours: 6))
                    days.append(samples(ago, hours: workday(63), decayFrom: 72,
                                        episodes: [(14, 72), (12, 66), (11, 80)]))
                }
                write(history, samples: days)
            },
            DebugScenario(id: "deepFastAlerts", group: .deep,
                          title: "Correcting quickly",
                          detail: "Short episodes, 12-second recovery — the improving signal.") {
                var history: [PostureHistory] = []
                var days: [PostureDaySamples] = []
                for ago in 0...16 where !isWeekend(ago) {
                    history.append(day(ago, score: 82, hours: 6))
                    days.append(samples(ago, hours: workday(82), decayFrom: 88,
                                        episodes: [(1.5, 11), (2, 13), (1, 12), (2.5, 14)]))
                }
                write(history, samples: days)
            },
            DebugScenario(id: "deepSideways", group: .deep,
                          title: "Side lean dominant",
                          detail: "Most bad time is leaning sideways, not forward.") {
                var history: [PostureHistory] = []
                var days: [PostureDaySamples] = []
                for ago in 0...16 where !isWeekend(ago) {
                    history.append(day(ago, score: 66, hours: 6))
                    var sampleDay = samples(ago, hours: workday(66), decayFrom: 76)
                    sampleDay.slots = sampleDay.slots.map { slot in
                        var copy = slot
                        let bad = copy.totals.bad
                        copy.totals.forward = bad * 0.35
                        copy.totals.sideways = bad * 0.65
                        return copy
                    }
                    days.append(sampleDay)
                }
                write(history, samples: days)
            }
        ]
    }
}

#endif
