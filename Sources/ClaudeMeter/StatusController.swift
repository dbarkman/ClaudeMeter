import AppKit
import Combine
import SwiftUI
import ClaudeMeterCore

/// Owns the menu bar item ("51/25") and shows the panel while the pointer is over
/// the item or the panel. A click also toggles the panel and refreshes.
@MainActor
final class StatusController: NSResponder {
    private let store: UsageStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: HoverPanel
    private var hideWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(store: UsageStore) {
        self.store = store
        self.panel = HoverPanel(rootView: PanelView(store: store))
        super.init()

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
        }
        setTitle(usage: nil, problem: nil)

        panel.onMouseEnter = { [weak self] in self?.hideWork?.cancel() }
        panel.onMouseExit = { [weak self] in self?.scheduleHide() }

        store.$usage.combineLatest(store.$problem)
            .sink { [weak self] usage, problem in
                self?.setTitle(usage: usage, problem: problem)
                // Let SwiftUI apply the new state before re-measuring the panel.
                DispatchQueue.main.async { self?.repositionIfVisible() }
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Hover

    override func mouseEntered(with event: NSEvent) {
        hideWork?.cancel()
        showPanel()
        store.refreshIfStale()
    }

    override func mouseExited(with event: NSEvent) {
        scheduleHide()
    }

    @objc private func clicked() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
        store.refresh()
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let pointer = NSEvent.mouseLocation
            if self.panel.frame.contains(pointer) || self.buttonScreenRect().contains(pointer) { return }
            self.panel.orderOut(nil)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    // MARK: - Panel placement

    private func buttonScreenRect() -> NSRect {
        guard let button = item.button, let window = button.window else { return .zero }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func showPanel() {
        place()
        panel.orderFrontRegardless()
    }

    private func repositionIfVisible() {
        if panel.isVisible { place() }
    }

    private func place() {
        panel.fitToContent()
        let anchor = buttonScreenRect()
        let size = panel.frame.size
        var x = anchor.midX - size.width / 2
        if let visible = (item.button?.window?.screen ?? NSScreen.main)?.visibleFrame {
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: anchor.minY - size.height - 6))
    }

    // MARK: - Title

    private func setTitle(usage: Usage?, problem: UsageProblem?) {
        let text: String
        var color: NSColor? = nil
        if let usage {
            text = "\(Int(usage.sessionUsed.rounded()))/\(Int(usage.weekUsed.rounded()))"
            let worst = max(usage.sessionUsed, usage.weekUsed)
            if problem != nil {
                color = .secondaryLabelColor
            } else if worst >= 90 {
                color = .systemRed
            } else if worst >= 75 {
                color = .systemOrange
            }
        } else {
            text = "–/–"
            color = .secondaryLabelColor
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        ]
        if let color { attributes[.foregroundColor] = color }
        item.button?.attributedTitle = NSAttributedString(string: text, attributes: attributes)
    }
}
