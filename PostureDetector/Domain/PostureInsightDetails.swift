//
//  PostureInsightDetails.swift
//  PostureDetector
//
//  The summary half of every insight — what the state means and why it
//  happens, in the two or three sentences the detail sheet has room for. The
//  data sentence lives on the insight itself and the action lives in the tips,
//  so this text carries only the reasoning between them.
//
//  Also holds the topic each recommendation belongs to, so the tips list never
//  shows three different ways of saying the same thing.
//

import Foundation

/// What a recommendation is really asking for. Two insights that share a topic
/// would produce near-identical advice, so only one of them makes the list.
enum InsightActionTopic: String {
    case tracking       // record a session, keep the rhythm going
    case setup          // chair, desk, screen height, calibration
    case sessions       // how long a session runs, breaks inside it
    case review         // look back at the data and find the cause
    case routine        // protect or extend what already works
    case alerts         // thresholds and how often the app nudges
}

extension PostureInsight {
    /// The summary shown in the detail sheet.
    var detail: String {
        PostureInsightDetails.text(for: id) ?? PostureInsightDetails.fallback(for: category)
    }

    /// Which lever the recommendation pulls, used to avoid repeating advice.
    var actionTopic: InsightActionTopic {
        PostureInsightDetails.topic(for: id, category: category)
    }
}

enum PostureInsightDetails {

    static func text(for id: String) -> String? { catalog[id] }

    // MARK: - Action topics

    static func topic(for id: String, category: InsightCategory) -> InsightActionTopic {
        if let explicit = topics[id] { return explicit }
        switch category {
        case .welcome, .gap, .consistency: return .tracking
        case .streak, .milestone:          return .routine
        case .score, .run, .pattern:       return .setup
        case .trend, .recovery:            return .review
        case .alerts:                      return .alerts
        case .duration:                    return .sessions
        }
    }

    /// Overrides where a rule's advice does not match its category's default lever.
    private static let topics: [String: InsightActionTopic] = [
        "deep.worstBlock": .sessions,
        "deep.afternoonDip": .sessions,
        "deep.bestBlock": .sessions,
        "deep.sessionDecay": .sessions,
        "deep.context": .setup,
        "deep.leanForward": .setup,
        "deep.leanSideways": .setup,
        "deep.episodesLong": .alerts,
        "deep.episodesMany": .setup,
        "deep.alertFaster": .alerts,
        "deep.alertSlower": .alerts,
        "deep.alertSlow": .alerts,
        "deep.alertFast": .alerts,
        "deep.exerciseEffect": .routine,
        "streak.broken": .tracking,
        "streak.mostOfWeek": .tracking,
        "milestone.days10": .review,
        "milestone.days50": .review,
        "score.great": .sessions,
        "score.good": .sessions,
        "score.personalBest": .review,
        "score.aboveUsual": .review,
        "run.great3": .routine,
        "run.great5": .sessions,
        "run.great7": .routine,
        "run.great10": .routine,
        "run.volatile": .review,
        "pattern.weekdaySpread": .sessions,
        "alerts.medium": .setup,
        "alerts.high": .setup,
        "alerts.up": .setup,
        "recovery.longComeback": .tracking,
        "recovery.comeback": .tracking,
        "recovery.sliding": .sessions,
        "recovery.worstOfFortnight": .setup,
        "trend.downBig": .setup,
        "trend.flat": .setup
    ]

    // MARK: - Fallbacks

    static func fallback(for category: InsightCategory) -> String {
        switch category {
        case .welcome:
            return "Scores only mean something in comparison — to yesterday, to last week, to your own average. The first few sessions exist to build that reference point."
        case .gap:
            return "Gaps cost less than they feel like they do: averages run over thirty days, so a few missed sessions barely move them. The cost is to the habit, not the arithmetic."
        case .streak, .consistency:
            return "Consistency is what turns a set of scores into something you can act on. Comparable days are what let the app separate a bad day from a bad habit."
        case .score, .run, .recovery:
            return "Single sessions vary far more than habits do. Length, workload and where you sat move the number more than technique, so look for repeats before changing anything."
        case .trend:
            return "Trends are more reliable than individual days because they average out workload and mood. A direction that holds for two weeks is worth acting on."
        case .alerts:
            return "Alert rate describes how often posture drifts, which is a different question from how good it is on average. A high score with frequent alerts means support, not attention, is missing."
        case .duration:
            return "Time seated matters alongside the angle: load on the spine is roughly duration multiplied by position. Long days need more breaks rather than more concentration."
        case .milestone, .pattern:
            return "Long-running data shows things memory cannot. Memory keeps the dramatic days and discards the ordinary ones, which is exactly the wrong sample."
        }
    }


    // MARK: - Tips

    /// A tip is an imperative plus one clause. Anything longer belongs in the
    /// summary — the tips list is meant to be scanned, not read.
    struct TipCopy {
        let title: String
        let note: String
    }

    static func tip(for id: String) -> TipCopy {
        tips[id] ?? TipCopy(title: "Keep tracking", note: "More sessions sharpen every reading.")
    }

    private static let tips: [String: TipCopy] = [

        // First steps
        "welcome.empty": .init(title: "Run 20 minutes", note: "An ordinary working day, not a good one."),
        "welcome.firstDay": .init(title: "Track tomorrow", note: "Two days is where trends begin."),
        "welcome.firstDayPast": .init(title: "Add a second day", note: "One reading has no context."),
        "welcome.secondDay": .init(title: "Aim for three days", note: "Same desk, same time of day."),
        "welcome.earlyDays": .init(title: "Track a normal day", note: "Unusual days skew the baseline."),
        "welcome.firstWeek": .init(title: "Finish the week", note: "Seven days unlock weekly comparisons."),

        // Gaps
        "gap.weekend": .init(title: "Try one weekend hour", note: "Sofa posture is usually the worst."),
        "gap.1day": .init(title: "Start a short session", note: "Ten minutes keeps the rhythm."),
        "gap.1day.streakAtRisk": .init(title: "Save the streak", note: "Ten tracked minutes still count."),
        "gap.2days": .init(title: "Track today", note: "Short is fine — presence is the point."),
        "gap.3days": .init(title: "Restart today", note: "One session begins a new streak."),
        "gap.4to6days": .init(title: "Do 15 minutes", note: "Then two more sessions this week."),
        "gap.week": .init(title: "Set a fresh baseline", note: "One normal working session."),
        "gap.fortnight": .init(title: "Recalibrate first", note: "Then track one honest session."),
        "gap.month": .init(title: "Recalibrate and restart", note: "Treat the old data as a before picture."),

        // Streaks
        "streak.2": .init(title: "Repeat the time", note: "Same hour tomorrow beats a better score."),
        "streak.3": .init(title: "Push for five", note: "That is where it stops being a decision."),
        "streak.4": .init(title: "Make it a full week", note: "One more day completes the set."),
        "streak.5": .init(title: "Add a weekend day", note: "Weekend posture is a different story."),
        "streak.6": .init(title: "Finish the week", note: "Whole weeks compare cleanly."),
        "streak.7": .init(title: "Beat your average by 3", note: "Aim at quality now, not presence."),
        "streak.8to9": .init(title: "Hold the routine", note: "Ten days is two sessions away."),
        "streak.10": .init(title: "Target your worst weekday", note: "One bad day lifts the whole average."),
        "streak.14": .init(title: "Compare the two weeks", note: "Coverage is identical, so the trend is real."),
        "streak.21": .init(title: "Raise the bar slightly", note: "Habits extend easiest while forming."),
        "streak.30": .init(title: "Look back at day one", note: "The change is bigger than it felt."),
        "streak.50": .init(title: "Protect the routine", note: "Keep the minimum session genuinely minimal."),
        "streak.100": .init(title: "Chase fewer alerts", note: "A better goal than more days."),
        "streak.record": .init(title: "Set the next mark now", note: "Before the let-down arrives."),
        "streak.nearRecord": .init(title: "Schedule tomorrow", note: "Decide it today, not in the morning."),
        "streak.broken": .init(title: "Start a new run", note: "Within a week keeps the month intact."),
        "streak.mostOfWeek": .init(title: "Pair two days", note: "Back to back turns coverage into a streak."),

        // Latest score
        "score.flawless": .init(title: "Try it for longer", note: "Hold this setup across a full stretch."),
        "score.perfect": .init(title: "Add hours, not points", note: "There is nothing left to fix inside."),
        "score.excellent": .init(title: "Change nothing", note: "Keep the desk exactly as it is."),
        "score.great": .init(title: "Fix the last hour", note: "That is where the slouched time hides."),
        "score.good": .init(title: "Reset every 30 minutes", note: "Short breaks push this into the 80s."),
        "score.fair": .init(title: "Raise your screen", note: "Top edge level with your eyes."),
        "score.poor": .init(title: "Check chair and support", note: "Feet flat, lower back supported."),
        "score.veryPoor": .init(title: "Sit somewhere else once", note: "If the score jumps, it is the desk."),
        "score.personalBest": .init(title: "Write down the setup", note: "Chair, screen, time of day."),
        "score.aboveUsual": .init(title: "Copy today tomorrow", note: "Find the one thing that differed."),

        // Runs
        "run.great3": .init(title: "Keep the routine identical", note: "The environment is doing the work."),
        "run.great5": .init(title: "Add an hour", note: "Good posture extends easier than it rebuilds."),
        "run.great7": .init(title: "Leave the setup alone", note: "Bank the week before changing anything."),
        "run.great10": .init(title: "Protect the sessions", note: "The habit lapses before the posture does."),
        "run.rough3": .init(title: "Stretch every 30 minutes", note: "Two minutes is enough to reset."),
        "run.rough5": .init(title: "Change one thing", note: "Screen height first, then the chair."),
        "run.volatile": .init(title: "Compare two days", note: "A good one against a bad one."),

        // Trends
        "trend.upBig": .init(title: "Write down what changed", note: "A cause can be repeated."),
        "trend.upMedium": .init(title: "Hold for one more week", note: "Change nothing while it climbs."),
        "trend.upSmall": .init(title: "Add one reset break", note: "Small trends respond to small changes."),
        "trend.flat": .init(title: "Change one variable", note: "Screen height, chair, or break frequency."),
        "trend.downSmall": .init(title: "Check your hours", note: "Longer weeks cost a few points."),
        "trend.downMedium": .init(title: "Look at the calendar", note: "Meeting days and laptop days show here."),
        "trend.downBig": .init(title: "Recalibrate first", note: "Then check what moved on the desk."),
        "trend.monthUp": .init(title: "Keep the routine", note: "Let the numbers accumulate."),
        "trend.monthDown": .init(title: "Find the bad week", note: "The decline is rarely spread evenly."),

        // Consistency
        "consistency.near30": .init(title: "Trust the weekday pattern", note: "The samples are large enough now."),
        "consistency.high": .init(title: "Fill one missing day", note: "Usually a weekend, usually the worst."),
        "consistency.medium": .init(title: "Aim for four days a week", note: "That makes weekday patterns real."),
        "consistency.low": .init(title: "Pick two fixed days", note: "Rhythm beats volume early on."),
        "consistency.sparse": .init(title: "Track three days in one week", note: "One comparable week beats scattered days."),

        // Patterns
        "pattern.weekendWorse": .init(title: "Set up one weekend hour", note: "Proper chair, screen at eye level."),
        "pattern.weekdayWorse": .init(title: "Spend ten minutes on the desk", note: "Chair height, then monitor height."),
        "pattern.weekdaySpread": .init(title: "Move hard work to your best day", note: "Add breaks on the weak one."),

        // Alerts
        "alerts.none": .init(title: "Note the session length", note: "Holding for hours means good setup."),
        "alerts.veryLow": .init(title: "Tighten the threshold", note: "The current one almost never fires."),
        "alerts.low": .init(title: "Leave the settings", note: "This is a healthy nudge rate."),
        "alerts.medium": .init(title: "Add lumbar support", note: "A cushion beats concentration here."),
        "alerts.high": .init(title: "Recalibrate honestly", note: "Sit the way you sit for an hour."),
        "alerts.down": .init(title: "Tighten a notch", note: "You are catching the small slips yourself."),
        "alerts.up": .init(title: "Check what moved", note: "Chair, screen or day length."),

        // Session length
        "duration.veryShort": .init(title: "Aim for 45 minutes", note: "Posture holds fine for the first 30."),
        "duration.short": .init(title: "Try one long session", note: "It reveals the afternoon slump."),
        "duration.medium": .init(title: "Compare first and last hour", note: "The gap tells you when to break."),
        "duration.long": .init(title: "Walk every 90 minutes", note: "Five minutes is enough."),
        "duration.veryLong": .init(title: "Split the day in two", note: "Total sitting time matters as much."),
        "duration.up": .init(title: "Add a stand-up per hour", note: "Longer days need breaks, not willpower."),
        "duration.down": .init(title: "Compare score per hour", note: "Short weeks flatter the average."),
        "duration.longest": .init(title: "Compare with a normal day", note: "If it held, the setup works."),

        // Milestones
        "milestone.days10": .init(title: "Find your best day", note: "Then work out what made it different."),
        "milestone.days25": .init(title: "Set a 5-point target", note: "The average is stable enough now."),
        "milestone.days50": .init(title: "Compare first ten to last ten", note: "That is your actual progress."),
        "milestone.days100": .init(title: "Raise the target band", note: "Try 85 and see how it feels."),
        "milestone.hours10": .init(title: "Keep the sessions coming", note: "The next milestone arrives sooner."),
        "milestone.hours50": .init(title: "Check the setup still fits", note: "Small annoyances become habits."),
        "milestone.hours100": .init(title: "Keep going", note: "The effects are cumulative and quiet."),
        "milestone.hours250": .init(title: "Change nothing", note: "The routine is the achievement."),
        "milestone.hours500": .init(title: "Protect, do not optimise", note: "New targets break old habits."),

        // Recovery
        "recovery.longComeback": .init(title: "Get two more sessions in", note: "Ignore the score this week."),
        "recovery.comeback": .init(title: "Track tomorrow too", note: "Back-to-back rebuilds fastest."),
        "recovery.bounce": .init(title: "Make today the default", note: "One good day proves the setup."),
        "recovery.better": .init(title: "Repeat today's conditions", note: "Before the reason gets lost."),
        "recovery.worse": .init(title: "Think what moved", note: "Room, screen, or a long meeting."),
        "recovery.climbing": .init(title: "Change nothing", note: "Let the run tell you how far it goes."),
        "recovery.sliding": .init(title: "Shorter session tomorrow", note: "Break the pattern deliberately."),
        "recovery.tiedBest": .init(title: "Go one point further", note: "Same setup, slightly longer."),
        "recovery.bestOfFortnight": .init(title: "Note the time of day", note: "Your best sessions cluster."),
        "recovery.worstOfFortnight": .init(title: "Wait one day", note: "Recalibrate only if it repeats."),

        // Deep patterns
        "deep.worstBlock": .init(title: "Break before the dip", note: "Five minutes, 15 minutes early."),
        "deep.afternoonDip": .init(title: "Move hard work to mornings", note: "Meetings and admin after lunch."),
        "deep.bestBlock": .init(title: "Book your long block early", note: "Work with the curve, not against it."),
        "deep.sessionDecay": .init(title: "Set a repeating timer", note: "Stand for two minutes when it fires."),
        "deep.context": .init(title: "Measure the weak setup", note: "Screen at eye level, feet flat."),
        "deep.leanForward": .init(title: "Raise the display", note: "Top edge level with your eyes."),
        "deep.leanSideways": .init(title: "Centre your desk", note: "Armrest, mouse and screen alignment."),
        "deep.episodesLong": .init(title: "Shorten the alert delay", note: "Be interrupted at two minutes."),
        "deep.episodesMany": .init(title: "Support your lower back", note: "A cushion or a higher seat."),
        "deep.alertFaster": .init(title: "Tighten the threshold", note: "Keep catching the small slips."),
        "deep.alertSlower": .init(title: "Change the signal", note: "Sound to haptics, or the reverse."),
        "deep.alertSlow": .init(title: "Turn the sound on", note: "Aim to react inside 15 seconds."),
        "deep.alertFast": .init(title: "Leave the settings alone", note: "The alert count will fall on its own."),
        "deep.exerciseEffect": .init(title: "Anchor one session", note: "Just before your weakest hours.")
    ]

    // MARK: - Catalog

    private static let catalog: [String: String] = [

        // MARK: First steps

        "welcome.empty": "Scores only mean something next to other scores, and the first session is what creates that reference point. Run it on an ordinary working day rather than one where you are sitting well on purpose — a flattering baseline makes every later improvement look smaller than it was.",
        "welcome.firstDay": "A first day tells you where you start, not how you are doing. Early numbers swing with session length and how unusual the day was, far more than with posture itself. That settles after about a week, and direction matters more than level until it does.",
        "welcome.firstDayPast": "One reading has no context around it. Two sessions on consecutive days beat five scattered across a month, because consecutive days share a desk, a workload and a chair — and shared conditions are what make two numbers comparable at all.",
        "welcome.secondDay": "Two points make a line but not a trend. Holding the conditions steady now — same desk, same rough time of day — is what lets later changes say something about you rather than about the day you happened to measure.",
        "welcome.earlyDays": "Averages are unstable below about a week of data, and one long or unusual session can move them ten points. Tracking ordinary days rather than good ones keeps the baseline honest about the posture you actually want to change.",
        "welcome.firstWeek": "A week of sessions is the first point where the app can compare like with like. Alert rates need a few hours before they mean anything and weekday patterns need repeats, so this is where the coach stops describing and starts finding.",

        // MARK: Tracking gaps

        "gap.weekend": "Weekend gaps are the most common shape in posture data and usually harmless — provided those days are genuinely away from a screen. Weekend laptop time on a sofa produces the worst scores in most histories, because the screen ends up far below eye level.",
        "gap.1day": "One missed day costs almost nothing statistically, but it is the day most streaks die. The second miss becomes far more likely once the first has happened, because the rule quietly changes from never miss to missing is fine.",
        "gap.1day.streakAtRisk": "Streaks are motivational rather than statistical, but the motivation is real: people who keep one going track roughly twice as many days. What ends most runs is not busyness but the belief that a ten-minute session is not worth recording.",
        "gap.2days": "Two days is where a break stops looking accidental. Nothing is lost yet — thirty-day averages barely notice — but the corrections that felt automatic start to fade, because they were being reinforced by feedback that has now stopped.",
        "gap.3days": "After three days the recent-week statistics describe last week rather than this one. The habit being reinforced is not sitting up straight but noticing that you are not, and that noticing fades within a few days of the nudges stopping.",
        "gap.4to6days": "Nearly a week of silence leaves the trend lines comparing old data with older data. Expect the first session back to come in below your average — that is attention returning, not a real decline, and it usually recovers within two or three sessions.",
        "gap.week": "A week away is long enough for the setup to change without you registering it: a different room, a chair someone else adjusted, a laptop where a monitor used to be. Any of those moves a score more than a change in habit would.",
        "gap.fortnight": "Two weeks of silence means the stored numbers describe a version of you that no longer applies. The calibration matters most here — it was captured under conditions that may have moved, and a stale one produces both false alerts and false confidence.",
        "gap.month": "After a month the valuable thing in your history is not the average but the comparison it will let you make later. Measuring yourself against a routine that no longer exists turns the first session back into a failure it does not need to be.",

        // MARK: Streaks

        "streak.2": "Two consecutive days is the smallest real unit of a habit. The research is consistent about what makes the third likely: repeating at the same time of day, attached to something that already happens, matters more than how well you do it.",
        "streak.3": "Three days in a row means your weekly average rests on comparable conditions rather than scattered samples. It is also where drop-off is highest — the novelty has gone and the data is not yet interesting enough to replace it.",
        "streak.4": "Four consecutive days is enough to see posture decay across a working week. Most people score lower on day four than day one even with nothing else changing, because postural endurance is the first thing fatigue takes.",
        "streak.5": "A full working week gives you your first honest weekly average. Adding one weekend day is the most informative next step, because weekend posture is often either the best or by far the worst of the week — and either answer is useful.",
        "streak.6": "Six days is close enough to a complete week that one more makes every comparison cleaner. Whole weeks contain the same mix of heavy and light days, which is what lets the app say this week beat last week and mean it.",
        "streak.7": "Seven consecutive days means every part of your week is represented, including the days you would rather not measure. That completeness is what makes weekday patterns trustworthy instead of anecdotal.",
        "streak.8to9": "Past a week the streak stops being about data quality and becomes about routine. The data is already good enough; what you are building now is the reflex of starting a session without deciding to, and that is what survives a busy month.",
        "streak.10": "Ten days is roughly where tracking stops requiring a decision each morning. That frees attention for something specific — and a single weak weekday usually lifts the weekly average more than trying to improve every day slightly.",
        "streak.14": "Two weeks of unbroken tracking makes week-over-week comparison genuinely reliable, because both weeks have identical coverage. It is also a good moment to look backwards: gradual change is almost impossible to perceive from the inside.",
        "streak.21": "Three weeks is long enough that the routine survives ordinary disruption — a busy day, a trip, a bad night. Habits are easiest to extend while still forming, which makes this the cheapest moment to raise the bar slightly.",
        "streak.30": "A month without a gap turns your history from a sample into a record. Comparing your first week with this one usually shows more improvement than it felt, because your sense of normal moves along with the change.",
        "streak.50": "Fifty consecutive days is exceptional by any measure of habit persistence. The usual failure mode from here is ambition rather than boredom: someone raises the bar, misses the new target, and abandons the whole thing.",
        "streak.100": "A hundred consecutive days is far past where most tracking habits survive, and the score stopped being the interesting number some time ago. Alert rate and total upright hours describe your progress better now.",
        "streak.record": "Records are rare by definition, and the practical value is not the number but the confidence — you now know the routine survives whatever the last few weeks contained. The risk right after one is the let-down that makes the next session feel optional.",
        "streak.nearRecord": "Matching your longest run means the conditions that made the first one possible have returned, which suggests circumstance rather than willpower — and circumstance can be recreated deliberately. Deciding tomorrow's session today is usually what decides whether the record falls.",
        "streak.broken": "A broken streak costs nothing statistically: every tracked day is still in your history and still counts toward every average. The only real loss is momentum, and that returns after two or three sessions rather than needing rebuilding.",
        "streak.mostOfWeek": "Coverage matters more than chains — five days out of seven gives a reliable weekly average whether or not they were consecutive. Consecutive days add one thing only: the day-over-day comparisons that reveal fatigue effects.",

        // MARK: Latest score

        "score.flawless": "A perfect score means no monitored minute crossed the threshold, which is rare and much easier over a short session. The interesting question is whether the same setup holds it across a full working stretch — ability and endurance are different things.",
        "score.perfect": "Above ninety-five there is nothing meaningful left to improve inside the session. The gains from here are duration and consistency: more hours at this quality, fewer untracked stretches where the posture is simply unknown.",
        "score.excellent": "The ninety band means only a few minutes were spent out of position. At this level the score is less about correcting posture and more about maintaining an environment where good posture is the path of least resistance.",
        "score.great": "Above eighty, roughly four in five monitored minutes were upright. The slouched remainder rarely spreads evenly — it clusters in the last hour, when fatigue makes an upright position feel like work.",
        "score.good": "The seventies mean about a quarter of your time was spent leaning forward, which is normal for a desk day with a reasonable setup. This is the band where short regular resets move the average more than trying to sit perfectly does.",
        "score.fair": "Scores in the sixties usually point at a screen below eye level. The head weighs around five kilograms, and every centimetre forward multiplies the load on the neck extensors — which is why screen height dominates this band.",
        "score.poor": "Under sixty means roughly half the session was out of position. At that ratio the cause is nearly always physical: unsupported feet, no lumbar support, or a screen you have to lean toward to read comfortably.",
        "score.veryPoor": "A score this low usually means the working position itself makes good posture impractical rather than that you are doing something wrong. One session somewhere else entirely is the fastest way to tell the difference.",
        "score.personalBest": "Best-ever days are worth reverse-engineering. Chair, screen height, time of day and session length explain most of the gap between anyone's best and average days — and all four can be repeated once you know which one mattered.",
        "score.aboveUsual": "Days above your average are more informative than days below it: a bad day has a hundred possible causes, a good one usually has two. That ceiling is also a better target than a round number, because it is demonstrably reachable in your own setup.",

        // MARK: Runs

        "run.great3": "Three strong sessions in a row usually mean the environment is right rather than that you concentrated harder. Concentration cannot be sustained across three days; a chair at the right height and a screen at eye level work whether you think about them or not.",
        "run.great5": "Five strong sessions is past coincidence — your baseline has moved, and the same effort now produces a better score than it did a month ago. Extending the time at this level tends to be easier than pushing the level higher.",
        "run.great7": "A full week above eighty is a level most people never reach. The slouched minutes that remain are usually deep-work moments when posture is not available to attention at all, so they respond to environment rather than intention.",
        "run.great10": "Ten or more sessions above eighty means good posture is your default rather than a performance, and postural muscles fatigue more slowly with regular use. The risk now is the routine lapsing long before the posture does.",
        "run.rough3": "Three weak sessions is where a bad patch becomes a habit, because the body adapts to whatever position it spends the most time in. The usual causes — a changed workstation, laptop-only days, a run of long days — are environmental rather than motivational.",
        "run.rough5": "Five consecutive sessions under sixty is a setup problem rather than a discipline one: sustained poor posture means the good position is uncomfortable or impossible where you are sitting, and discomfort beats intention over a working day.",
        "run.volatile": "Large swings between days usually mean more than one workplace. The gap between a monitor with a desk chair and a laptop on a soft chair is commonly fifteen to twenty-five points, which is larger than most habit changes produce.",

        // MARK: Trends

        "trend.upBig": "Week-over-week moves of ten points or more nearly always have a concrete cause, because genuine habit change is gradual. A new chair, an external monitor or a lighter week explains most of them — and a cause can be repeated where a number cannot.",
        "trend.upMedium": "A steady mid-sized improvement is the most sustainable kind. It usually reflects an environmental change that keeps paying out, rather than a burst of effort that fades — effort-driven weeks tend to show one spike and a return to baseline.",
        "trend.upSmall": "Small weekly gains compound quickly: three points a week is twelve points a month. They are also the most common shape of real improvement, because postural change is adaptation rather than decision, and adaptation is slow.",
        "trend.flat": "A flat week means your setup and habits are stable, which is what makes a deliberate change measurable. Plateaus break when one variable moves — changing several at once usually costs you the ability to tell which one worked.",
        "trend.downSmall": "Small dips normally sit inside normal variation, and treating them as problems tends to produce overcorrection. Longer weeks reliably cost a few points regardless of technique, because the extra hours are the tired ones.",
        "trend.downMedium": "A drop of five or more points tends to track the calendar rather than motivation. Meeting-heavy weeks are the classic cause: long stretches of listening produce more slouching than active work, because there is nothing to lean toward.",
        "trend.downBig": "Double-digit weekly drops usually have a physical explanation, and the measurement is the first thing to rule out. A recalibration in an unusual position shifts every later score without your posture changing at all.",
        "trend.monthUp": "Month-over-month improvement is the most meaningful trend here, because a month averages out weeks, workloads and moods. It is also the scale at which physical adaptation shows up — postural endurance improves over weeks, not days.",
        "trend.monthDown": "A weaker month is worth breaking down week by week. In most histories the decline concentrates in one or two bad weeks rather than spreading evenly, which makes the cause far easier to identify and usually already over.",

        // MARK: Consistency

        "consistency.near30": "With near-complete coverage the harder statistics become trustworthy: weekday averages, alert rates and the shape of a typical day. This is where the app can tell you something you could not have worked out from memory.",
        "consistency.high": "Coverage this good makes weekly comparison reliable, but the gaps can flatter you. Untracked days are rarely random — they tend to be the unusual ones, which are also the ones with the worst posture.",
        "consistency.medium": "Half a month is enough for a trend but not for a weekday pattern: two sessions on the same weekday can differ by twenty points. The app is limited by comparable days rather than total hours, so more days beat longer ones.",
        "consistency.low": "With a handful of days, one rough session moves the monthly average by several points, which makes effort look ineffective when the noise is larger than the signal. A fixed rhythm stabilises it faster than more hours would.",
        "consistency.sparse": "At this level the average is closer to a sample than a summary — and a biased one, because the days you remember to track are rarely the days you most need to. Three deliberate sessions beat ten accidental ones.",

        // MARK: Patterns

        "pattern.weekendWorse": "Sofas, beds and kitchen tables share a mechanism: they put the screen well below eye level and let the pelvis roll backwards, which flattens the lower back and pulls the head forward. That combination is the worst case in most histories.",
        "pattern.weekdayWorse": "When weekends beat workdays the cause is the work setup rather than effort — which is encouraging, because setups are fixed once and stay fixed. Screen height, seat height and seat depth are the three worth measuring.",
        "pattern.weekdaySpread": "Consistent weekday differences track your calendar rather than your discipline. Because they repeat weekly they can look like a personality trait when they are really a schedule, which means the fix is scheduling too.",

        // MARK: Alerts

        "alerts.none": "A session with no alerts means your neutral position held the whole way through. Length changes what that means: forty minutes is normal, three hours usually says the desk is set up well rather than that you concentrated harder.",
        "alerts.veryLow": "Almost no alerts means one of two things. With a high score, your posture is genuinely stable; with a middling score, the detection is missing your particular slouch and a recalibration is worth doing, because thresholds that never fire give no feedback.",
        "alerts.low": "One or two alerts an hour is the sweet spot — often enough to catch real slips, rare enough that you keep responding. Alert fatigue is the main reason posture apps stop working, so this rate is worth protecting.",
        "alerts.medium": "Alerts at this rate mean you correct quickly but drift back within minutes, which is a support problem rather than an attention one. An unsupported lower back lets the pelvis roll and the head follows forward, undoing every conscious correction.",
        "alerts.high": "A constant stream of alerts usually means the neutral position being compared against is not one you can hold in your chair. The app is then measuring the gap between a target and a possibility, not between intention and effort.",
        "alerts.down": "Fewer alerts at the same score means you are catching the drift yourself rather than waiting for the nudge. That is the transition from being reminded to having a habit, and it usually appears weeks before the average moves.",
        "alerts.up": "A jump in alerts normally has a physical cause: a different chair, a laptop, or simply a longer day. Fatigue shows here before it shows in the score, because tiredness increases drifting before it worsens the resting position.",

        // MARK: Session length

        "duration.veryShort": "Posture rarely fails in the first half hour — it fails when attention drifts and the muscles tire. Sessions under twenty minutes therefore capture your best behaviour, which is why they tend to score better than they deserve to.",
        "duration.short": "Half-hour to hour-long sessions catch the start of the fatigue curve but stop before the worst of it. If the score looks good here while your neck aches by evening, the answer is in the hours you are not measuring.",
        "duration.medium": "This is the most useful session length: long enough for fatigue to appear, short enough that you finish it. The drift between the first and last half hour is the single most actionable number in your data.",
        "duration.long": "Sessions this long describe a real working day, so the score reflects how you actually sit rather than how you sit while paying attention. Expect it lower than a short session — that is completeness, not regression.",
        "duration.veryLong": "Past about six hours, total seated time matters as much as the angle. Uninterrupted sitting affects circulation, disc pressure and muscular fatigue regardless of how good the position looks, so movement outranks alignment here.",
        "duration.up": "More hours at the desk cost a few points even when nothing else changes, because fatigue accumulates and the extra hours are the tired ones. A score that held while your hours rose is a real improvement in disguise.",
        "duration.down": "A shorter week flatters the average, since most slouching happens in the hours you did not sit through. Comparing weeks of different lengths is the easiest way to draw the wrong conclusion from this data.",
        "duration.longest": "Your longest session is the harshest test of the setup, because everything slightly wrong becomes uncomfortable given enough time. A score that held means the chair and screen are doing the work rather than your attention.",

        // MARK: Milestones

        "milestone.days10": "Ten sessions is roughly where noise settles and signal appears. Below it, single unusual days dominate every average; above it, the app can tell the difference between a bad session and a bad trend.",
        "milestone.days25": "Around twenty-five days the averages stop moving much with each new session, and that stability is what makes goals meaningful. A five-point target now represents a real change rather than a lucky week.",
        "milestone.days50": "Fifty tracked days is more posture data than most people ever collect about themselves. The interesting comparison is no longer day to day but your first ten sessions against your last ten.",
        "milestone.days100": "A hundred sessions is well past the point where tracking is an experiment. The useful next goal is usually a lower alert rate rather than a higher score — holding position unprompted is what transfers to the hours you do not track.",
        "milestone.hours10": "Ten hours of measured upright time is a real reduction in cumulative load on the neck and lower back. Load is roughly hours multiplied by angle, which is why total upright time tracks progress better than a percentage does.",
        "milestone.hours50": "Fifty hours upright is about a full working week spent in a position that does not load your neck. The effects are cumulative and quiet — less end-of-day stiffness long before any single session feels different.",
        "milestone.hours100": "A hundred hours is where most people notice something outside the app: fewer tension headaches, less evening shoulder tightness. Nothing happens on the day you cross it, which is rather the point of a cumulative measure.",
        "milestone.hours250": "At this scale the number describes a habit that has held for months, through holidays, deadlines and chair changes. That durability is worth more than any individual score.",
        "milestone.hours500": "Five hundred hours is a genuinely unusual amount of measured upright time. The biggest risk to a habit this established is trying to improve it — a new target that fails tends to take the old routine down with it.",

        // MARK: Recovery and momentum

        "recovery.longComeback": "Restarting is the hardest part of any tracking habit, and it is already done. Postural endurance declines measurably within a couple of weeks, so expect the first sessions back to sit below your old average and recover within a week.",
        "recovery.comeback": "Short breaks barely dent a thirty-day average, so there is nothing to make up for. What decayed was the habit of starting rather than the ability to sit well, and back-to-back sessions rebuild that faster than one intense day.",
        "recovery.bounce": "Large day-to-day swings almost always have a situational cause rather than a physiological one — bodies do not change overnight, but desks, rooms and schedules do. Reconstructing the day usually finds it in a minute.",
        "recovery.better": "A double-digit improvement in one day is worth investigating while you still remember the day. Posture responds quickly to environment and slowly to intention, so the chair and the screen explain more than motivation does.",
        "recovery.worse": "A sharp single-day drop is usually circumstantial: a different room, a lower screen, a much longer session, or simply less sleep. Reacting to one day tends to produce a sequence of adjustments that each undo the last.",
        "recovery.climbing": "Three improving days in a row is longer than random variation usually produces, so something in the routine is working. The common mistake is adding more changes and losing track of which one caused it.",
        "recovery.sliding": "Three declining sessions is a pattern rather than noise. Fatigue accumulates across a week, so the cause often lies in the days before rather than today — postural endurance recovers more slowly than energy does.",
        "recovery.tiedBest": "Matching your best score means it was not a fluke. Two readings at the same level tell you the ceiling is repeatable in your actual environment, which makes it a target rather than an anecdote.",
        "recovery.bestOfFortnight": "Your best day in two weeks is a useful reference, and the most informative thing about it is usually the time of day. Postural strength depends on recent load, so most people peak after a break rather than first thing.",
        "recovery.worstOfFortnight": "One weak day below everything recent rarely means much on its own. Sleep, workload and session length move a daily score more than technique, and two or three of them together easily produce an outlier.",

        // MARK: Deep patterns

        "deep.worstBlock": "A dip at the same time of day is one of the few findings here that is genuinely about you rather than about a particular day, because it survives repetition. The cause is accumulated load rather than the clock, which is why the timing of a break matters more than its length.",
        "deep.afternoonDip": "The post-lunch decline is real — core temperature, glucose and alertness move together in the early afternoon, and postural endurance follows. Its size depends heavily on what the afternoon contains: long unbroken desk stretches deepen it, movement flattens it.",
        "deep.bestBlock": "Almost everyone has a window where posture holds better, and it is rarely first thing — most people peak an hour or two in, warm but not yet tired. Knowing yours turns posture from something you maintain into something you schedule around.",
        "deep.sessionDecay": "Posture inside a long session does not decline smoothly. It holds while the postural muscles have capacity and then falls off fairly sharply, and your own crossover point is visible here. Breaks timed by feel lag the physiology by ten or fifteen minutes.",
        "deep.context": "Context comparison separates a posture problem from a furniture problem — the same body, the same day, a different chair or screen. That distinction decides the fix: habits respond to feedback, but no amount of attention compensates for a screen fifteen centimetres too low.",
        "deep.leanForward": "Forward head posture is the dominant failure mode for screen work and it is mechanical rather than motivational. The head weighs about five kilograms in neutral and the load on the neck extensors rises steeply as it moves forward, so anything that makes you look down invites it.",
        "deep.leanSideways": "Side lean points somewhere quite different from forward head: asymmetry rather than height. An armrest, a distant mouse, or an off-centre screen are the usual causes, and because people lean consistently to one side, that side shortens over weeks until the position feels neutral.",
        "deep.episodesLong": "The shape of your bad time matters as much as its total. Long unbroken episodes load the same tissues continuously with no chance to recover — considerably worse than the same minutes spread across short lapses — and they mean the alert is not registering.",
        "deep.episodesMany": "Frequent short lapses are the opposite signal: the feedback loop works, but the position will not hold on its own. When the lower back is unsupported the pelvis rolls back and the head drifts forward, so the chair undoes each conscious correction within minutes.",
        "deep.alertFaster": "Reaction time is the most sensitive measure of progress here and it moves weeks before the score. As the habit forms the gap shrinks first, then the number of alerts falls, and only then does the average rise — because you start catching the drift before the threshold.",
        "deep.alertSlower": "A lengthening response time is the earliest sign of alert fatigue, and it happens to nearly everyone. A signal that arrives in the same form for weeks stops producing an orienting response, which is habituation rather than a motivation problem.",
        "deep.alertSlow": "A long gap between alert and correction means the signal is registering as information rather than as a prompt — too subtle to interrupt, too late to feel wrong, or too familiar to notice. Load on the neck rises with the length of each episode, so response time matters directly.",
        "deep.alertFast": "Correcting within seconds means the nudge has become a reflex rather than a decision, which is the intended end state. From here the alert count falls on its own, and tightening thresholds now is the fastest route back to ignoring them.",
        "deep.exerciseEffect": "This is a rare thing to be able to measure: whether an intervention works for you specifically rather than in general. Guided sessions both restore range of movement and interrupt a long sitting stretch, and because the comparison uses the same hours on skipped days, it is not just the general trend."
    ]
}
