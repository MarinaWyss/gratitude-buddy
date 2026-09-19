import AppKit

/// Decides when the buddy should next appear. "Roughly once an hour" means a random
/// 50–70 minute gap, so it never feels like a metronome.
final class Scheduler {
    var onFire: (() -> Void)?
    var onChange: (() -> Void)?

    private(set) var nextFire: Date?
    private var timer: Timer?

    private let range: ClosedRange<TimeInterval> = {
        // Handy for testing: BUDDY_INTERVAL_SECONDS=10 open "Gratitude Buddy.app"
        if let raw = ProcessInfo.processInfo.environment["BUDDY_INTERVAL_SECONDS"],
           let s = TimeInterval(raw), s > 0 {
            return s...s
        }
        return (50 * 60)...(70 * 60)
    }()

    var pausedUntil: Date? {
        get { Settings.pausedUntil }
        set { Settings.pausedUntil = newValue }
    }

    var isPaused: Bool {
        if let p = pausedUntil, p > Date() { return true }
        return false
    }

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        if isPaused, let p = pausedUntil {
            schedule(at: p)
        } else {
            pausedUntil = nil
            scheduleNext()
        }
    }

    func scheduleNext() {
        schedule(in: TimeInterval.random(in: range))
    }

    func schedule(in seconds: TimeInterval) {
        schedule(at: Date().addingTimeInterval(seconds))
    }

    func pauseUntilTomorrow() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let at = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        pausedUntil = at
        schedule(at: at)
    }

    func resume() {
        pausedUntil = nil
        scheduleNext()
    }

    private func schedule(at date: Date) {
        timer?.invalidate()
        nextFire = date
        let t = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.timerFired()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        onChange?()
    }

    private func timerFired() {
        if isPaused, let p = pausedUntil {
            schedule(at: p)
        } else {
            pausedUntil = nil
            onFire?()
        }
    }

    /// If the Mac was asleep past the scheduled time, don't ambush the user the
    /// second the lid opens. Give them a few minutes to settle in.
    @objc private func didWake() {
        guard !isPaused, let next = nextFire, next.timeIntervalSinceNow < 120 else { return }
        schedule(in: 5 * 60)
    }
}
