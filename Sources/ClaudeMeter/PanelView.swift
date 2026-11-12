import SwiftUI
import ServiceManagement
import ClaudeMeterCore

struct PanelView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        // Re-render every 30 s so the countdowns stay current while the panel is open.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .padding(16)
        .frame(width: HoverPanel.width)
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let usage = store.usage {
                sessionCard(usage, now: now)
                weekCard(usage, now: now)
            } else if store.problem == nil {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Spacer()
                }
                .padding(.vertical, 20)
            }

            if let problem = store.problem {
                ProblemBanner(problem: problem, lastGood: store.usage?.fetchedAt)
            }

            Divider().opacity(0.6)
            FooterBar(updatedAt: store.usage?.fetchedAt)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Claude Usage")
                .font(.headline)
            Spacer()
            if store.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Button { store.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
            }
        }
    }

    private func sessionCard(_ usage: Usage, now: Date) -> some View {
        let resetText: String
        let footnote: String?
        if let resetsAt = usage.sessionResetsAt {
            resetText = "resets in \(Schedule.spokenDuration(resetsAt.timeIntervalSince(now)))"
            footnote = "Resets at \(resetsAt.formatted(date: .omitted, time: .shortened))"
        } else {
            resetText = "no active session"
            footnote = nil
        }
        return MeterCard(
            title: "Current session",
            systemImage: "clock",
            used: usage.sessionUsed,
            marker: nil,
            detail: "\(Int(usage.sessionLeft.rounded()))% left · \(resetText)",
            footnote: footnote
        )
    }

    private func weekCard(_ usage: Usage, now: Date) -> some View {
        let elapsed = usage.weekElapsedFraction(now: now)
        let elapsedPercent = Int((elapsed * 100).rounded())
        let pace = usage.weekUsed > elapsed * 100 + 2 ? "ahead of pace" : "on pace"
        let resets = usage.weekResetsAt.formatted(.dateTime.weekday(.wide).hour().minute())
        return MeterCard(
            title: "This week",
            systemImage: "calendar",
            used: usage.weekUsed,
            marker: elapsed,
            detail: "\(Int(usage.weekUsed.rounded()))% used · \(elapsedPercent)% point of the week",
            footnote: "Resets \(resets) · \(pace)"
        )
    }
}

// MARK: - Pieces

private struct MeterCard: View {
    let title: String
    let systemImage: String
    let used: Double
    /// 0...1 position for a "where we are in time" tick, if any.
    let marker: Double?
    let detail: String
    let footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(used.rounded()))%")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(levelColor(for: used))
                    .contentTransition(.numericText())
            }
            UsageBar(fraction: used / 100, tint: levelColor(for: used), marker: marker)
            Text(detail)
                .font(.callout)
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
        .animation(.easeInOut(duration: 0.35), value: used)
    }
}

private struct UsageBar: View {
    let fraction: Double
    let tint: Color
    let marker: Double?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(8, width * min(max(fraction, 0), 1)))
                if let marker {
                    Capsule()
                        .fill(Color.primary.opacity(0.8))
                        .frame(width: 2, height: 14)
                        .offset(x: width * min(max(marker, 0), 1) - 1)
                        .help("Where you are in the week")
                }
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.35), value: fraction)
    }
}

private struct ProblemBanner: View {
    let problem: UsageProblem
    let lastGood: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: problem.message)
                if let lastGood {
                    Text("Showing numbers from \(lastGood.formatted(date: .omitted, time: .shortened)).")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}

private struct FooterBar: View {
    let updatedAt: Date?
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Open at login", isOn: $openAtLogin)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.caption)
                .onChange(of: openAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Spacer()
            if let updatedAt {
                Text(updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Last updated")
            }
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }
}

private func levelColor(for percent: Double) -> Color {
    switch percent {
    case ..<50: return .green
    case ..<75: return .yellow
    case ..<90: return .orange
    default: return .red
    }
}
