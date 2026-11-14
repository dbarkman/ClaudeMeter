import Foundation

/// Reads the Claude Code sign-in from the login Keychain and asks Anthropic's usage
/// endpoint (the one behind Claude Code's /usage screen) for the plan limits.
///
/// ClaudeMeter never renews the token itself: each renewal rotates the refresh key,
/// so two programs renewing independently would sign each other out. When the token
/// is about to expire, it asks Claude Code to renew it (see `ClaudeCLI`).
public enum UsageService {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let keychainService = "Claude Code-credentials"

    public static func fetch(now: Date = Date()) async throws -> Usage {
        var credentials = try readCredentials()
        if Renewal.isDue(expiresAt: credentials.expiresAt, now: now) {
            credentials = try await renewed(replacing: credentials)
        }
        do {
            return try await request(token: credentials.token, now: now)
        } catch UsageProblem.expired {
            // The server rejected a token the clock says is still good: renew once and retry.
            let fresh = try await renewed(replacing: credentials)
            return try await request(token: fresh.token, now: now)
        }
    }

    static func request(token: String, now: Date) async throws -> Usage {
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ClaudeMeter/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageProblem.network(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw UsageProblem.expired }
        guard status == 200 else { throw UsageProblem.http(status) }
        return try parse(data, now: now)
    }

    public static func parse(_ data: Data, now: Date) throws -> Usage {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let fiveHour = root["five_hour"] as? [String: Any],
            let sevenDay = root["seven_day"] as? [String: Any],
            let sessionUsed = number(fiveHour["utilization"]),
            let weekUsed = number(sevenDay["utilization"])
        else { throw UsageProblem.badResponse }

        return Usage(
            sessionUsed: sessionUsed,
            sessionResetsAt: date(fiveHour["resets_at"]),
            weekUsed: weekUsed,
            weekResetsAt: date(sevenDay["resets_at"]) ?? Schedule.nextSundayEleven(after: now),
            fetchedAt: now
        )
    }

    // MARK: - Sign-in

    struct Credentials: Equatable {
        let token: String
        let expiresAt: Date?
    }

    static func readCredentials() throws -> Credentials {
        guard let raw = keychainCredentials() ?? fileCredentials() else {
            throw UsageProblem.notSignedIn
        }
        return try credentials(from: raw)
    }

    static func credentials(from raw: Data) throws -> Credentials {
        guard
            let root = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String, !token.isEmpty
        else { throw UsageProblem.notSignedIn }

        let expiresAt = number(oauth["expiresAt"]).map { Date(timeIntervalSince1970: $0 / 1000) }
        return Credentials(token: token, expiresAt: expiresAt)
    }

    /// Has Claude Code renew the sign-in, trying the free command first, and returns
    /// the new credentials. Throws `.expired` if nothing produced a fresh token.
    static func renewed(replacing old: Credentials) async throws -> Credentials {
        guard let claude = ClaudeCLI.locate() else { throw UsageProblem.expired }

        for step in ClaudeCLI.renewalSteps(now: Date()) {
            _ = await ClaudeCLI.run(claude, step)
            let current = try readCredentials()
            if current.token != old.token, !Renewal.isDue(expiresAt: current.expiresAt, now: Date()) {
                return current
            }
        }
        throw UsageProblem.expired
    }

    /// Uses /usr/bin/security, which Claude Code itself uses to store the item, so
    /// reading it doesn't raise a Keychain prompt for every rebuild of this app.
    private static func keychainCredentials() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", keychainService, "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let trimmed = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Data(trimmed.utf8)
    }

    private static func fileCredentials() -> Data? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        return try? Data(contentsOf: url)
    }

    // MARK: - JSON helpers

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fractional.date(from: s) { return d }
        return ISO8601DateFormatter().date(from: s)
    }
}

public enum Renewal {
    /// Renew this long before the token expires, so a refresh never lands on a dead token.
    public static let margin: TimeInterval = 5 * 60

    public static func isDue(expiresAt: Date?, now: Date) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) <= margin
    }
}
