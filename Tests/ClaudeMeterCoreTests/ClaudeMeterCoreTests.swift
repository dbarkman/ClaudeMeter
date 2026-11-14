import Foundation
import Testing
@testable import ClaudeMeterCore

struct ParsingTests {
    let now = ISO8601DateFormatter().date(from: "2026-11-12T20:00:00Z")!

    @Test func parsesBothWindows() throws {
        let json = """
        {"five_hour":{"utilization":51.0,"resets_at":"2026-11-12T22:05:00.123456+00:00"},
         "seven_day":{"utilization":25,"resets_at":"2026-11-15T18:00:00Z"},
         "seven_day_opus":null}
        """
        let usage = try UsageService.parse(Data(json.utf8), now: now)
        #expect(usage.sessionUsed == 51)
        #expect(usage.sessionLeft == 49)
        #expect(usage.weekUsed == 25)
        let sessionReset = try #require(usage.sessionResetsAt)
        #expect(abs(sessionReset.timeIntervalSince(ISO8601DateFormatter().date(from: "2026-11-12T22:05:00Z")!)) < 1)
        #expect(usage.weekResetsAt == ISO8601DateFormatter().date(from: "2026-11-15T18:00:00Z")!)
    }

    @Test func missingResetsFallBack() throws {
        let json = #"{"five_hour":{"utilization":0,"resets_at":null},"seven_day":{"utilization":3}}"#
        let usage = try UsageService.parse(Data(json.utf8), now: now)
        #expect(usage.sessionResetsAt == nil)
        #expect(usage.weekResetsAt == Schedule.nextSundayEleven(after: now))
    }

    @Test func rejectsUnexpectedShape() {
        #expect(throws: UsageProblem.badResponse) {
            try UsageService.parse(Data(#"{"error":"nope"}"#.utf8), now: now)
        }
    }

    @Test func readsTokenAndExpiry() throws {
        let expiresMs = (now.timeIntervalSince1970 + 3600) * 1000
        let creds = #"{"claudeAiOauth":{"accessToken":"abc","expiresAt":\#(Int(expiresMs))}}"#
        let parsed = try UsageService.credentials(from: Data(creds.utf8))
        #expect(parsed.token == "abc")
        #expect(parsed.expiresAt == now.addingTimeInterval(3600))
    }

    @Test func missingTokenMeansSignedOut() {
        #expect(throws: UsageProblem.notSignedIn) {
            try UsageService.credentials(from: Data(#"{"claudeAiOauth":{}}"#.utf8))
        }
    }
}

struct RenewalTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func renewsShortlyBeforeExpiry() {
        #expect(!Renewal.isDue(expiresAt: now.addingTimeInterval(3600), now: now))
        #expect(!Renewal.isDue(expiresAt: now.addingTimeInterval(Renewal.margin + 1), now: now))
        #expect(Renewal.isDue(expiresAt: now.addingTimeInterval(Renewal.margin), now: now))
        #expect(Renewal.isDue(expiresAt: now.addingTimeInterval(-60), now: now))
        #expect(!Renewal.isDue(expiresAt: nil, now: now))
    }

    @Test func paidRenewalIsRateLimited() {
        let start = Date().addingTimeInterval(10 * 365 * 86400)  // far from any real call
        #expect(ClaudeCLI.renewalSteps(now: start) == [ClaudeCLI.statusStep, ClaudeCLI.requestStep])
        #expect(ClaudeCLI.renewalSteps(now: start.addingTimeInterval(60)) == [ClaudeCLI.statusStep])
        #expect(ClaudeCLI.renewalSteps(now: start.addingTimeInterval(ClaudeCLI.requestCooldown)) == [ClaudeCLI.statusStep, ClaudeCLI.requestStep])
    }
}

struct ScheduleTests {
    @Test func nextSundayElevenIsSundayAtEleven() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Phoenix")!
        // Thursday 2026-11-12 13:00 Phoenix.
        let thursday = ISO8601DateFormatter().date(from: "2026-11-12T20:00:00Z")!
        let reset = Schedule.nextSundayEleven(after: thursday, calendar: calendar)
        let parts = calendar.dateComponents([.weekday, .hour, .minute, .day], from: reset)
        #expect(parts.weekday == 1)
        #expect(parts.hour == 11)
        #expect(parts.minute == 0)
        #expect(parts.day == 15)
    }

    @Test func weekFraction() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(Schedule.weekElapsedFraction(resetsAt: now.addingTimeInterval(Schedule.week), now: now) == 0)
        #expect(Schedule.weekElapsedFraction(resetsAt: now.addingTimeInterval(Schedule.week / 2), now: now) == 0.5)
        #expect(Schedule.weekElapsedFraction(resetsAt: now, now: now) == 1)
    }

    @Test func spokenDurations() {
        #expect(Schedule.spokenDuration(2 * 3600 + 5 * 60) == "2 hours 5 minutes")
        #expect(Schedule.spokenDuration(3600) == "1 hour")
        #expect(Schedule.spokenDuration(61) == "2 minutes")
        #expect(Schedule.spokenDuration(0) == "less than a minute")
        #expect(Schedule.spokenDuration(26 * 3600 + 600) == "1 day 2 hours")
    }
}
