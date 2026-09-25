import Foundation

/// Tiny UserDefaults wrapper for the handful of things we persist.
enum Settings {
    private static let d = UserDefaults.standard

    static var hasLaunchedBefore: Bool {
        get { d.bool(forKey: "hasLaunchedBefore") }
        set { d.set(newValue, forKey: "hasLaunchedBefore") }
    }

    static var soundEnabled: Bool {
        get { d.object(forKey: "soundEnabled") == nil ? true : d.bool(forKey: "soundEnabled") }
        set { d.set(newValue, forKey: "soundEnabled") }
    }

    static var buddyTurn: Int {
        get { d.integer(forKey: "buddyTurn") }
        set { d.set(newValue, forKey: "buddyTurn") }
    }

    static var pausedUntil: Date? {
        get { d.object(forKey: "pausedUntil") as? Date }
        set { d.set(newValue, forKey: "pausedUntil") }
    }

    static var reminderTimes: [Date] {
        get { d.array(forKey: "reminderTimes") as? [Date] ?? [] }
        set { d.set(newValue, forKey: "reminderTimes") }
    }
}
