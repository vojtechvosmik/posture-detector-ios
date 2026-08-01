//
//  CalendarGridView.swift
//  PostureDetector
//
//  The month as a field of score rings: every tracked day draws a thin gradient
//  arc around its number — the fuller the ring, the better the posture. Great
//  days glow, untracked days keep a whisper-thin track, and the whole month
//  sweeps in ring by ring.
//

import SwiftUI

struct CalendarGridView: View {
    let month: Date
    let history: [PostureHistory]
    let onDayTapped: (Date) -> Void

    @State private var drawn = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol.prefix(2).uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.4)
                        .foregroundColor(isWeekendColumn(index) ? .secondary.opacity(0.55) : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            // Day rings
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        RingDayCell(
                            date: date,
                            history: historyForDate(date),
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > calendar.startOfDay(for: Date()),
                            drawn: drawn,
                            delay: Double(index) * 0.02
                        )
                        .onTapGesture { onDayTapped(date) }
                    } else {
                        Color.clear.frame(height: RingDayCell.height)
                    }
                }
            }
        }
        .onAppear { drawn = true }
        .onChange(of: monthKey) { _ in
            // Redraw the sweep whenever the user pages to another month.
            drawn = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                drawn = true
            }
        }
    }

    private var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: month)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar

        guard var symbols = formatter.shortWeekdaySymbols else { return [] }

        // Rotate so the row starts on the calendar's first weekday
        // (firstWeekday is 1-based: 1 = Sunday, 2 = Monday, …).
        let rotateBy = calendar.firstWeekday - 1
        if rotateBy > 0 {
            symbols = Array(symbols[rotateBy...]) + Array(symbols[0..<rotateBy])
        }

        return symbols
    }

    /// True when the column at `index` lands on Saturday or Sunday.
    private func isWeekendColumn(_ index: Int) -> Bool {
        let weekday = (calendar.firstWeekday - 1 + index) % 7 + 1
        return weekday == 1 || weekday == 7
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        let monthLastDay = calendar.date(byAdding: DateComponents(day: -1), to: monthInterval.end)!

        var days: [Date?] = []
        var date = monthFirstWeek.start

        while date <= monthLastDay || days.count % 7 != 0 {
            if calendar.isDate(date, equalTo: month, toGranularity: .month) {
                days.append(date)
            } else {
                days.append(nil)
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return days
    }

    private func historyForDate(_ date: Date) -> PostureHistory? {
        history.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
    }
}

// MARK: - Ring cell

/// A single day: the number inside a thin score ring. Tracked days sweep a
/// gradient arc proportional to their score, great days carry a soft bloom,
/// untracked days keep only a hairline track, and today is marked in accent.
private struct RingDayCell: View {
    let date: Date
    let history: PostureHistory?
    let isToday: Bool
    let isFuture: Bool
    let drawn: Bool
    let delay: Double

    static let height: CGFloat = 54
    private let ring: CGFloat = 42
    private let lineWidth: CGFloat = 3.5

    private var hasData: Bool { (history?.totalMonitoredSeconds ?? 0) > 0 }
    private var score: Int { history?.score ?? 0 }
    private var color: Color { Aura.scoreColor(score) }
    private var isGreat: Bool { hasData && score >= 80 }

    private var progress: CGFloat {
        guard hasData else { return 0 }
        return max(0.04, min(1, CGFloat(score) / 100))
    }

    var body: some View {
        ZStack {
            // Today: a solid accent disc inside the ring, so the day pops out of the grid
            if isToday {
                Circle()
                    .fill(
                        LinearGradient(colors: [Aura.accent, Aura.accent.opacity(0.78)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: ring - 2 * lineWidth - 2, height: ring - 2 * lineWidth - 2)
                    .shadow(color: Aura.accent.opacity(0.5), radius: 7, y: 1)
            }

            // Track — accent-tinted on today so it reads even behind a full arc
            Circle()
                .stroke(isToday ? Aura.accent.opacity(0.35) : Aura.softFill,
                        lineWidth: hasData || isToday ? lineWidth : 1.2)
                .frame(width: ring, height: ring)

            // Score arc
            if hasData {
                Circle()
                    .trim(from: 0, to: drawn ? progress : 0)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.35), color, color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: ring, height: ring)
                    .shadow(color: isGreat ? color.opacity(0.55) : .clear, radius: 5)
                    .animation(.easeOut(duration: 0.65).delay(delay), value: drawn)
            }

            // Day number
            Text(dayNumber)
                .font(.system(size: 15, weight: hasData || isToday ? .bold : .medium, design: .rounded))
                .foregroundColor(numberColor)
                .monospacedDigit()

        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .opacity(isFuture ? 0.28 : 1)
        .scaleEffect(drawn ? 1 : 0.8)
        .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(delay), value: drawn)
        .contentShape(Circle())
    }

    private var numberColor: Color {
        if isToday { return .white }
        return hasData ? .primary : .secondary.opacity(0.55)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
