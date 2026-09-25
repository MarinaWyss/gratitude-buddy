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

/// Once or twice a day, at random moments between 10 am and 5 pm, a buddy drops by with a one-line
/// reminder. A day's times are picked all at once and saved, so relaunching doesn't roll new ones.
final class ReminderScheduler {
    var onFire: (() -> Void)?

    private let hours = 10..<17
    private let gap: TimeInterval = 2 * 60 * 60   // between two reminders on the same day

    private var next: Date?
    private var timer: Timer?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        arm(after: Date())
    }

    /// Moves on to the next planned reminder. Even if this one ran late, the next stays `gap` away.
    func scheduleNext() {
        arm(after: Date().addingTimeInterval(gap))
    }

    /// Tries again in a little while, or moves on if that would fall outside the hours.
    func schedule(in seconds: TimeInterval) {
        let at = Date().addingTimeInterval(seconds)
        if inHours(at) { schedule(at: at) } else { scheduleNext() }
    }

    /// Arms the first planned time after `date`, planning a fresh day when the saved plan is
    /// from an earlier day or used up.
    private func arm(after date: Date) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var times = Settings.reminderTimes
        if times.first.map({ $0 < today }) ?? true {
            times = plan(for: today)
        }
        if !times.contains(where: { $0 > date }) {
            times = plan(for: cal.date(byAdding: .day, value: 1, to: today)!)
        }
        Settings.reminderTimes = times
        if let at = times.first(where: { $0 > date }) { schedule(at: at) }
    }

    /// One or two random times inside the hours on `day`, at least `gap` apart.
    private func plan(for day: Date) -> [Date] {
        let open = Calendar.current.date(bySettingHour: hours.lowerBound, minute: 0, second: 0, of: day) ?? day
        let span = TimeInterval(hours.count * 60 * 60)
        let count = Int.random(in: 1...2)
        var offsets: [TimeInterval]
        repeat {
            offsets = (0..<count).map { _ in TimeInterval.random(in: 0..<span) }.sorted()
        } while count == 2 && offsets[1] - offsets[0] < gap
        return offsets.map { open.addingTimeInterval($0) }
    }

    private func inHours(_ date: Date) -> Bool {
        hours.contains(Calendar.current.component(.hour, from: date))
    }

    private func schedule(at date: Date) {
        timer?.invalidate()
        next = date
        let t = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.timerFired()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func timerFired() {
        // Asleep through the rest of the day's hours: let this one go.
        if inHours(Date()) { onFire?() } else { scheduleNext() }
    }

    /// Re-arm against the clock after sleep, and don't pop up the moment the lid opens.
    @objc private func didWake() {
        guard let next else { return }
        schedule(at: max(next, Date().addingTimeInterval(10 * 60)))
    }
}
