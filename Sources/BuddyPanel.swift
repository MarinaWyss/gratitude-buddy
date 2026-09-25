import AppKit
import SwiftUI
import Combine

/// Borderless, non-activating panel: floats over everything, can take keyboard
/// input, and never yanks focus from the app you were using.
final class BuddyPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) { onEscape?() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?(); return }   // esc
        super.keyDown(with: event)
    }
}

final class BuddyPanelController {
    enum Outcome {
        case completed(JournalEntry)
        case dismissed
        case timedOut
        case closed          // demo card closed; leave the schedule alone
    }

    var onOutcome: ((Outcome) -> Void)?

    private let panel: BuddyPanel
    private var model: CheckInModel?
    private var hosting: NSHostingView<BuddyView>?
    private var stepSub: AnyCancellable?
    private var timeoutItem: DispatchWorkItem?

    var isShowing: Bool { panel.isVisible }

    /// When the card last slid away, so a reminder can leave some room after a check-in.
    private(set) var lastHidden: Date?

    init() {
        panel = BuddyPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.appearance = NSAppearance(named: .aqua)   // always light: the illustrations are drawn for a light background
        panel.onEscape = { [weak self] in self?.escape() }
    }

    func show(intro: Bool, kind: BuddyKind? = nil, meet: Bool = false, reminder: String? = nil) {
        if isShowing { hide { [weak self] in self?.show(intro: intro, kind: kind, meet: meet, reminder: reminder) }; return }

        let model = CheckInModel(isIntro: intro, kind: kind ?? (meet ? .fluffyCat : .next()),
                                 meet: meet, reminder: reminder)
        let checkIn = !meet && reminder == nil
        model.onDismiss = { [weak self] in
            self?.hide { self?.onOutcome?(checkIn ? .dismissed : .closed) }
        }
        model.onComplete = { [weak self, weak model] entry in
            self?.onOutcome?(.completed(entry))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                guard let self, let model, self.model === model else { return }
                self.hide {}
            }
        }
        self.model = model

        let hosting = NSHostingView(rootView: BuddyView(model: model))
        self.hosting = hosting
        panel.contentView = hosting

        let size = hosting.fittingSize
        let target = restingFrame(for: size)
        var start = target
        start.origin.y -= 22
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        // A reminder has nothing to type into, so it leaves the keyboard with the app you're in.
        if reminder == nil { panel.makeKeyAndOrderFront(nil) } else { panel.orderFrontRegardless() }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.42
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }

        stepSub = model.$step
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.relayout() }
            }

        if Settings.soundEnabled, let s = NSSound(named: "Pop") {
            s.volume = 0.25
            s.play()
        }

        // If it sits there ignored for a long while, slide away quietly. A reminder only stays a minute.
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isShowing, self.model?.step != .done else { return }
            self.hide { self.onOutcome?(reminder == nil ? .timedOut : .closed) }
        }
        timeoutItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (reminder == nil ? 15 * 60 : 60), execute: item)
    }

    func hide(completion: @escaping () -> Void) {
        guard isShowing else { completion(); return }
        timeoutItem?.cancel()
        timeoutItem = nil
        stepSub = nil

        var f = panel.frame
        f.origin.y -= 14
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(f, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.panel.contentView = NSView()
            self.hosting = nil
            self.model = nil
            self.lastHidden = Date()
            completion()
        })
    }

    private func escape() {
        guard let model else { hide {}; return }
        if model.step == .done { hide {} } else { model.dismiss() }
    }

    /// Resize to fit the new step, keeping the bottom-right corner where it is.
    private func relayout() {
        guard let hosting, isShowing else { return }
        let size = hosting.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        let cur = panel.frame
        let f = NSRect(x: cur.maxX - size.width, y: cur.minY, width: size.width, height: size.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(f, display: true)
        }
    }

    private func restingFrame(for size: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(x: vf.maxX - size.width - 6,
                      y: vf.minY + 6,
                      width: size.width, height: size.height)
    }
}
