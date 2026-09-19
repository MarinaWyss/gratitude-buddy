import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let scheduler = Scheduler()
    private let buddy = BuddyPanelController()

    private let menu = NSMenu()
    private let nextItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause until tomorrow", action: #selector(togglePause), keyEquivalent: "")
    private let soundItem = NSMenuItem(title: "Soft sound", action: #selector(toggleSound), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()

        buddy.onOutcome = { [weak self] outcome in self?.handle(outcome) }
        scheduler.onFire = { [weak self] in self?.fire() }
        scheduler.onChange = { [weak self] in self?.refreshMenu() }
        scheduler.start()

        if !Settings.hasLaunchedBefore {
            Settings.hasLaunchedBefore = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.buddy.show(intro: true)
            }
        }
        refreshMenu()
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Gratitude Buddy")
            img?.isTemplate = true
            button.image = img
        }

        nextItem.isEnabled = false
        menu.addItem(nextItem)
        menu.addItem(NSMenuItem(title: "Check in now", action: #selector(checkInNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snooze 15 minutes", action: #selector(snooze), keyEquivalent: ""))
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open journal", action: #selector(openJournal), keyEquivalent: ""))
        menu.addItem(soundItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    private func refreshMenu() {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none

        if scheduler.isPaused, let p = scheduler.pausedUntil {
            let day = DateFormatter()
            day.dateFormat = "EEE"
            nextItem.title = "Paused until \(day.string(from: p)) \(fmt.string(from: p))"
            pauseItem.title = "Resume"
        } else if let next = scheduler.nextFire {
            nextItem.title = "Next check-in around \(fmt.string(from: next))"
            pauseItem.title = "Pause until tomorrow"
        } else {
            nextItem.title = "Not scheduled"
        }

        soundItem.state = Settings.soundEnabled ? .on : .off
        if #available(macOS 13.0, *) {
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            loginItem.isHidden = true
        }
    }

    // MARK: Actions

    @objc private func checkInNow() {
        buddy.show(intro: false)
    }

    @objc private func snooze() {
        buddy.hide { [weak self] in self?.scheduler.schedule(in: 15 * 60) }
    }

    @objc private func togglePause() {
        if scheduler.isPaused {
            scheduler.resume()
        } else {
            buddy.hide { [weak self] in self?.scheduler.pauseUntilTomorrow() }
        }
        refreshMenu()
    }

    @objc private func toggleSound() {
        Settings.soundEnabled.toggle()
        refreshMenu()
    }

    @objc private func toggleLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Login item change failed: \(error)")
        }
        refreshMenu()
    }

    @objc private func openJournal() {
        Journal.ensureExists()
        NSWorkspace.shared.open(Journal.url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: Scheduling glue

    private func fire() {
        if buddy.isShowing {
            scheduler.schedule(in: 5 * 60)
            return
        }
        // If nobody has touched the Mac for a while, wait until they're back.
        if idleSeconds() > 5 * 60 {
            scheduler.schedule(in: 2 * 60)
            return
        }
        buddy.show(intro: false)
    }

    private func handle(_ outcome: BuddyPanelController.Outcome) {
        switch outcome {
        case .completed(let entry):
            Journal.append(entry)
            scheduler.scheduleNext()
        case .dismissed:
            scheduler.schedule(in: 30 * 60)
        case .timedOut:
            scheduler.scheduleNext()
        }
    }

    private func idleSeconds() -> TimeInterval {
        let anyEvent = CGEventType(rawValue: UInt32.max) ?? .null
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
    }
}
