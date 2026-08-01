//
//  PostureSamples.swift
//  PostureDetector
//
//  Intraday posture data — the raw material the deep coach needs. The daily
//  record in PostureHistory answers "how was today"; this answers "when, in
//  what context, and in what shape".
//
//  Three things are recorded, all derived from work the monitor already does:
//    • 15-minute slots  — when during the day, in which mode, forward vs sideways
//    • decay buckets    — how posture holds as a session gets longer
//    • slouch episodes  — how often it collapses, for how long, and how fast
//                         it recovers after an alert
//
//  Stored as a JSON file in the app group container rather than UserDefaults:
//  the daily record is rewritten every five seconds and this payload is far
//  too large to ride along with it.
//

import Foundation

// MARK: - Model

/// Seconds split by posture quality and, for bad posture, by direction.
struct PostureTotals: Codable, Equatable {
    var good: Double = 0
    var forward: Double = 0
    var sideways: Double = 0

    var bad: Double { forward + sideways }
    var total: Double { good + bad }

    /// Percentage of upright time, or nil when there is nothing to score.
    var score: Int? {
        guard total > 0 else { return nil }
        return Int((good / total * 100).rounded())
    }

    mutating func add(_ other: PostureTotals) {
        good += other.good
        forward += other.forward
        sideways += other.sideways
    }
}

/// One 15-minute slice of local wall-clock time.
struct PostureSlot: Codable, Equatable {
    /// 0…95, computed from local time so daylight saving needs no handling.
    var index: Int
    var totals = PostureTotals()
    var alerts: Int = 0
    /// `PostureMode.rawValue` the monitor was running in.
    var mode: Int

    var hour: Int { index / 4 }
}

/// How posture held as a session got longer. Bucket 0 = first half hour.
struct PostureDecayBucket: Codable, Equatable {
    static let bounds: [(lower: Double, upper: Double, label: String)] = [
        (0, 30, "first 30 min"),
        (30, 60, "30–60 min"),
        (60, 120, "1–2 hours"),
        (120, .infinity, "past 2 hours")
    ]

    var bucket: Int
    var totals = PostureTotals()

    var label: String { Self.bounds.indices.contains(bucket) ? Self.bounds[bucket].label : "" }
}

/// A continuous stretch of bad posture.
struct SlouchEpisode: Codable, Equatable {
    var start: Date
    var duration: TimeInterval
    /// True when the grace timer fired an alert during this episode.
    var alerted: Bool
    /// Seconds between the alert and returning to good posture.
    var recoverySeconds: TimeInterval?
}

/// Everything recorded for one calendar day.
struct PostureDaySamples: Codable, Identifiable, Equatable {
    var id: String              // "yyyy-MM-dd"
    var date: Date
    var slots: [PostureSlot] = []
    var decay: [PostureDecayBucket] = []
    var episodes: [SlouchEpisode] = []
    /// Times a guided exercise was completed.
    var exercises: [Date] = []

    init(date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.id = formatter.string(from: date)
        self.date = Calendar.current.startOfDay(for: date)
    }

    var totals: PostureTotals {
        slots.reduce(into: PostureTotals()) { $0.add($1.totals) }
    }

    /// Totals for a half-open hour range, e.g. 13..<16.
    func totals(hours range: Range<Int>) -> PostureTotals {
        slots.filter { range.contains($0.hour) }
            .reduce(into: PostureTotals()) { $0.add($1.totals) }
    }

    func totals(mode: Int) -> PostureTotals {
        slots.filter { $0.mode == mode }
            .reduce(into: PostureTotals()) { $0.add($1.totals) }
    }
}

// MARK: - Store

/// Collects intraday samples in memory and persists them to the app group
/// container. Writes are coalesced — at most one per minute unless forced.
final class PostureSampleStore {

    static let shared = PostureSampleStore()

    /// Days kept on disk, newest first.
    private(set) var days: [PostureDaySamples]

    private let retentionDays = 90
    private let minimumWriteInterval: TimeInterval = 60
    private var lastWrite: Date?
    private let calendar = Calendar.current
    private let io = DispatchQueue(label: "cz.peachdev.postureplus.samples", qos: .utility)

    private static let fileName = "PostureSamples.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    init() {
        self.days = Self.load()
    }

    // MARK: Recording

    /// Adds one flush worth of monitored time to today's samples.
    /// Called from the session tracker every few seconds.
    func record(good: TimeInterval,
                forward: TimeInterval,
                sideways: TimeInterval,
                alerts: Int,
                mode: Int,
                minutesIntoSession: Double,
                at now: Date = Date()) {
        guard good + forward + sideways > 0 || alerts > 0 else { return }

        let totals = PostureTotals(good: good, forward: forward, sideways: sideways)
        var day = today(now)

        // 15-minute slot of local time
        let index = slotIndex(for: now)
        if let position = day.slots.firstIndex(where: { $0.index == index && $0.mode == mode }) {
            day.slots[position].totals.add(totals)
            day.slots[position].alerts += alerts
        } else {
            day.slots.append(PostureSlot(index: index, totals: totals, alerts: alerts, mode: mode))
        }

        // Session-length bucket
        let bucket = Self.decayBucket(forMinutes: minutesIntoSession)
        if let position = day.decay.firstIndex(where: { $0.bucket == bucket }) {
            day.decay[position].totals.add(totals)
        } else {
            day.decay.append(PostureDecayBucket(bucket: bucket, totals: totals))
        }

        store(day)
        flush()
    }

    /// Records a finished stretch of bad posture. Very short ones are noise.
    func recordEpisode(start: Date, duration: TimeInterval, alerted: Bool, recoverySeconds: TimeInterval?) {
        guard duration >= 20 else { return }
        var day = today(start)
        day.episodes.append(SlouchEpisode(start: start,
                                          duration: duration,
                                          alerted: alerted,
                                          recoverySeconds: recoverySeconds))
        store(day)
        flush()
    }

    /// Records a completed guided exercise, so the coach can measure what it does.
    func recordExercise(at date: Date = Date()) {
        var day = today(date)
        day.exercises.append(date)
        store(day)
        flush(force: true)
    }

    // MARK: Persistence

    /// Writes to disk, at most once a minute unless `force` is set.
    func flush(force: Bool = false) {
        let now = Date()
        if !force, let last = lastWrite, now.timeIntervalSince(last) < minimumWriteInterval { return }
        lastWrite = now

        let snapshot = days
        io.async {
            guard let url = Self.fileURL,
                  let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: Helpers

    private func slotIndex(for date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        return min(95, hour * 4 + minute / 15)
    }

    static func decayBucket(forMinutes minutes: Double) -> Int {
        PostureDecayBucket.bounds.firstIndex { minutes >= $0.lower && minutes < $0.upper } ?? 0
    }

    private func today(_ date: Date) -> PostureDaySamples {
        let start = calendar.startOfDay(for: date)
        if let existing = days.first(where: { calendar.isDate($0.date, inSameDayAs: start) }) {
            return existing
        }
        return PostureDaySamples(date: start)
    }

    private func store(_ day: PostureDaySamples) {
        if let position = days.firstIndex(where: { $0.id == day.id }) {
            days[position] = day
        } else {
            days.append(day)
        }
        let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        days = days.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }
    }

    /// Debug-only wholesale replacement, also used to clear the store.
    func replaceAll(with newDays: [PostureDaySamples]) {
        days = newDays
        flush(force: true)
    }

    private static func load() -> [PostureDaySamples] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([PostureDaySamples].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }
}

#if DEBUG
extension PostureSampleStore {

    /// Replaces the intraday store with a plausible three weeks: a real
    /// afternoon slump, a weak Desk context, posture that decays past an hour,
    /// forward-dominant lean, and exercises on every other day.
    func seedDemoSamples() {
        let calendar = Calendar.current
        var generated: [PostureDaySamples] = []
        var seed: UInt64 = 7
        func noise(_ spread: Double) -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return (Double((seed >> 33) % 1000) / 1000 - 0.5) * spread
        }

        for offset in 1...21 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 { continue }   // weekends left untracked on purpose

            var day = PostureDaySamples(date: date)
            let didExercise = offset % 2 == 0

            func add(hour: Int, score: Double, minutes: Double, mode: PostureMode) {
                let total = minutes * 60
                let good = total * min(max((score + noise(6)) / 100, 0), 1)
                let bad = total - good
                day.slots.append(PostureSlot(index: hour * 4,
                                             totals: PostureTotals(good: good,
                                                                   forward: bad * 0.88,
                                                                   sideways: bad * 0.12),
                                             alerts: Int(bad / 600),
                                             mode: mode.rawValue))
            }

            for hour in 9...11 { add(hour: hour, score: 82, minutes: 55, mode: .desk) }
            add(hour: 12, score: 76, minutes: 30, mode: .relaxed)
            for hour in 14...15 { add(hour: hour, score: didExercise ? 76 : 57, minutes: 55, mode: .desk) }
            add(hour: 16, score: 70, minutes: 45, mode: .desk)
            add(hour: 20, score: 87, minutes: 40, mode: .relaxed)

            day.decay = [
                PostureDecayBucket(bucket: 0, totals: PostureTotals(good: 30 * 60 * 0.85, forward: 30 * 60 * 0.15, sideways: 0)),
                PostureDecayBucket(bucket: 1, totals: PostureTotals(good: 30 * 60 * 0.79, forward: 30 * 60 * 0.21, sideways: 0)),
                PostureDecayBucket(bucket: 2, totals: PostureTotals(good: 60 * 60 * 0.66, forward: 60 * 60 * 0.34, sideways: 0)),
                PostureDecayBucket(bucket: 3, totals: PostureTotals(good: 45 * 60 * 0.60, forward: 45 * 60 * 0.40, sideways: 0))
            ]

            for index in 0..<4 {
                let start = calendar.date(bySettingHour: 10 + index * 2, minute: 10, second: 0, of: date) ?? date
                day.episodes.append(SlouchEpisode(start: start,
                                                  duration: 150 + Double(index) * 40,
                                                  alerted: true,
                                                  recoverySeconds: 22 + noise(10)))
            }

            if didExercise, let time = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: date) {
                day.exercises.append(time)
            }

            generated.append(day)
        }

        replaceAll(with: generated.sorted { $0.date > $1.date })
    }

    func clearSamples() { replaceAll(with: []) }
}
#endif
