import AppKit
import SwiftUI

/// Compact head/neck mark tinted by posture state.
enum StatusGlyph {
    static func image(state: PostureState, tiltDeg _: Double, size: CGFloat = 18) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let img = NSImage(size: imageSize, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let main = Theme.menuBar(state).withAlphaComponent(state == .paused ? 0.70 : 1.0)

            if let mask = AppImage.png("status-head"), let cgMask = mask.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let target = aspectFit(source: mask.size, in: rect.insetBy(dx: 1.5, dy: 1.0))
                ctx.saveGState()
                ctx.clip(to: target, mask: cgMask)
                ctx.setFillColor(main.cgColor)
                ctx.fill(target)
                ctx.restoreGState()
            } else {
                drawFallback(in: ctx, rect: rect, color: main)
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func aspectFit(source: NSSize, in rect: CGRect) -> CGRect {
        let aspect = max(source.width, 1) / max(source.height, 1)
        var width = rect.width
        var height = width / aspect
        if height > rect.height {
            height = rect.height
            width = height * aspect
        }
        return CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
    }

    private static func drawFallback(in ctx: CGContext, rect: CGRect, color: NSColor) {
        let s = rect.height / 18.0
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(1.7 * s)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addEllipse(in: CGRect(x: 5.0 * s, y: 10.2 * s, width: 5.2 * s, height: 5.2 * s))
        ctx.fillPath()
        ctx.move(to: CGPoint(x: 7.8 * s, y: 9.8 * s))
        ctx.addCurve(to: CGPoint(x: 7.2 * s, y: 3.2 * s),
                     control1: CGPoint(x: 5.7 * s, y: 8.0 * s),
                     control2: CGPoint(x: 8.9 * s, y: 5.7 * s))
        ctx.strokePath()
    }
}

/// NSStatusItem + transient popover. Plan §5.1: NSStatusItem, not MenuBarExtra (for icon control).
final class StatusBarController {
    private let item: NSStatusItem
    private let popover = NSPopover()
    private let engine: PostureEngine

    init(engine: PostureEngine, onStartExercise: @escaping () -> Void, onCheckForUpdates: @escaping () -> Void) {
        self.engine = engine
        item = NSStatusBar.system.statusItem(withLength: 24)

        if let b = item.button {
            b.image = StatusGlyph.image(state: .paused, tiltDeg: 0)
            b.imageScaling = .scaleProportionallyUpOrDown
            b.imagePosition = .imageOnly
            b.toolTip = tooltip(for: .paused)
            b.action = #selector(togglePopover)
            b.target = self
        }

        popover.behavior = .transient
        let hosting = NSHostingController(rootView: PopoverContentView(
            engine: engine,
            onStartExercise: onStartExercise,
            onCheckForUpdates: onCheckForUpdates
        ))
        hosting.sizingOptions = .preferredContentSize   // exact size from the SwiftUI content → no top clipping
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        popover.contentViewController = hosting

        engine.onStateChange = { [weak self] s in
            self?.refresh(state: s)
        }
    }

    private func refresh(state: PostureState) {
        item.button?.image = StatusGlyph.image(state: state, tiltDeg: engine.currentTilt)
        item.button?.toolTip = tooltip(for: state)
    }

    private func tooltip(for state: PostureState) -> String {
        "UpPod · \(L10n.stateLabel(state))"
    }

    @objc private func togglePopover() {
        guard let b = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
