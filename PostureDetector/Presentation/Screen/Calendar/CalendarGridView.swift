//
//  CalendarGridView.swift
//  PostureDetector
//
//  Custom calendar grid showing monthly posture scores
//

import SwiftUI

struct CalendarGridView: View {
    let month: Date
    let history: [PostureHistory]
    let onDayTapped: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar days
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            history: historyForDate(date),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month)
                        )
                        .onTapGesture {
                            onDayTapped(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar

        // Get the weekday symbols starting from the calendar's first weekday
        // Use shortWeekdaySymbols for clearer abbreviations (Mon, Tue, etc.)
        guard var symbols = formatter.shortWeekdaySymbols else {
            return []
        }

        let firstWeekday = calendar.firstWeekday

        // Rotate the array to match the calendar's first weekday
        // firstWeekday is 1-based (1 = Sunday, 2 = Monday, etc.)
        let rotateBy = firstWeekday - 1
        if rotateBy > 0 {
            symbols = Array(symbols[rotateBy...]) + Array(symbols[0..<rotateBy])
        }

        return symbols
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
        return history.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
    }
}

struct DayCell: View {
    let date: Date
    let history: PostureHistory?
    let isToday: Bool
    let isCurrentMonth: Bool

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var backgroundColor: Color {
        guard let history = history, history.totalMonitoredSeconds > 0 else {
            return Color.gray.opacity(0.1)
        }

        let score = history.score
        if score >= 80 {
            return Color.green.opacity(0.2)
        } else if score >= 60 {
            return Color.orange.opacity(0.2)
        } else {
            return Color.red.opacity(0.2)
        }
    }

    private var borderColor: Color {
        guard let history = history, history.totalMonitoredSeconds > 0 else {
            return Color.clear
        }

        let score = history.score
        if score >= 80 {
            return Color.green
        } else if score >= 60 {
            return Color.orange
        } else {
            return Color.red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayNumber)
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isCurrentMonth ? .primary : .gray.opacity(0.5))

            if let history = history, history.totalMonitoredSeconds > 0 {
                Text("\(history.score)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(borderColor)
            } else {
                Text("-")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue : borderColor, lineWidth: isToday ? 2 : 1)
        )
        .cornerRadius(8)
        .opacity(isCurrentMonth ? 1.0 : 0.4)
    }
}
