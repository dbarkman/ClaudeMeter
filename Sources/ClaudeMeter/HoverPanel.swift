import AppKit
import SwiftUI

/// Borderless frosted panel that floats under the menu bar item without taking
/// focus from the app you're in.
final class HoverPanel: NSPanel {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    private let hosting: NSHostingView<AnyView>
    static let width: CGFloat = 320

    init<Content: View>(rootView: Content) {
        hosting = NSHostingView(rootView: AnyView(rootView))
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true

        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        background.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
        contentView = background
    }

    override var canBecomeKey: Bool { true }

    override func mouseEntered(with event: NSEvent) { onMouseEnter?() }
    override func mouseExited(with event: NSEvent) { onMouseExit?() }

    /// Sizes the panel to the SwiftUI content's natural height.
    func fitToContent() {
        hosting.layoutSubtreeIfNeeded()
        let height = ceil(hosting.fittingSize.height)
        setContentSize(NSSize(width: Self.width, height: max(height, 60)))
        invalidateShadow()
    }
}
