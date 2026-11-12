import Foundation
import ClaudeMeterCore

/// Holds the latest reading. A failed refresh keeps the last good numbers and
/// records the problem, so the menu bar never flips to blank on a network blip.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var usage: Usage?
    @Published private(set) var problem: UsageProblem?
    @Published private(set) var isLoading = false

    private var timer: Timer?
    private var lastAttempt = Date.distantPast

    static let refreshInterval: TimeInterval = 5 * 60
    static let hoverRefreshMinimum: TimeInterval = 30

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refreshIfStale() {
        if Date().timeIntervalSince(lastAttempt) >= Self.hoverRefreshMinimum { refresh() }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        lastAttempt = Date()
        Task {
            do {
                usage = try await UsageService.fetch()
                problem = nil
            } catch let failure as UsageProblem {
                problem = failure
            } catch {
                problem = .network(error.localizedDescription)
            }
            isLoading = false
        }
    }
}
