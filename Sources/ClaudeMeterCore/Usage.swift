import Foundation

/// One reading of the Claude plan limits. Percentages are 0–100.
public struct Usage: Equatable {
    public let sessionUsed: Double
    public let sessionResetsAt: Date?
    public let weekUsed: Double
    public let weekResetsAt: Date
    public let fetchedAt: Date

    public init(sessionUsed: Double, sessionResetsAt: Date?, weekUsed: Double, weekResetsAt: Date, fetchedAt: Date) {
        self.sessionUsed = sessionUsed
        self.sessionResetsAt = sessionResetsAt
        self.weekUsed = weekUsed
        self.weekResetsAt = weekResetsAt
        self.fetchedAt = fetchedAt
    }

    public var sessionLeft: Double { max(0, 100 - sessionUsed) }

    /// How far through the current week we are, 0...1.
    public func weekElapsedFraction(now: Date) -> Double {
        Schedule.weekElapsedFraction(resetsAt: weekResetsAt, now: now)
    }
}

public enum UsageProblem: Error, Equatable {
    case notSignedIn
    case expired
    case http(Int)
    case badResponse
    case network(String)

    public var message: String {
        switch self {
        case .notSignedIn:
            return "Claude Code isn't signed in. Run claude in Terminal and use /login."
        case .expired:
            return "Couldn't renew the Claude Code sign-in automatically. Run claude once in Terminal."
        case .http(let code):
            return "The usage service returned an error (\(code))."
        case .badResponse:
            return "The usage service sent a response ClaudeMeter doesn't understand."
        case .network(let detail):
            return "Can't reach Anthropic: \(detail)"
        }
    }
}
