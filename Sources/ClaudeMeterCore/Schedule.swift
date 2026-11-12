import Foundation

public enum Schedule {
    public static let week: TimeInterval = 7 * 24 * 60 * 60

    /// The next Sunday 11:00 AM local time after `now`. Used only when the usage
    /// service doesn't report the weekly reset itself.
    public static func nextSundayEleven(after now: Date, calendar: Calendar = .current) -> Date {
        var target = DateComponents()
        target.weekday = 1
        target.hour = 11
        target.minute = 0
        target.second = 0
        return calendar.nextDate(after: now, matching: target, matchingPolicy: .nextTime)
            ?? now.addingTimeInterval(week)
    }

    public static func weekElapsedFraction(resetsAt: Date, now: Date) -> Double {
        let remaining = resetsAt.timeIntervalSince(now)
        return min(max(1 - remaining / week, 0), 1)
    }

    /// "2 hours 5 minutes", "1 day 3 hours", "less than a minute".
    public static func spokenDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((max(0, seconds) / 60).rounded(.up))
        if totalMinutes == 0 { return "less than a minute" }
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60

        func unit(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }

        var parts: [String] = []
        if days > 0 { parts.append(unit(days, "day")) }
        if hours > 0 { parts.append(unit(hours, "hour")) }
        if minutes > 0 && days == 0 { parts.append(unit(minutes, "minute")) }
        return parts.joined(separator: " ")
    }
}
