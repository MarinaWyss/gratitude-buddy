import Foundation
import Combine

enum Mood { case neutral, attentive, happy }

/// State for one check-in conversation.
final class CheckInModel: ObservableObject {
    enum Step { case greeting, feelings, gratitude, done, meet, reminder }

    @Published var step: Step = .greeting
    @Published var selected: Set<String> = []
    @Published var otherFeeling = ""
    @Published var gratitude = ""

    let isIntro: Bool
    let kind: BuddyKind
    let greeting: String
    let doneTitle: String
    /// Occasionally, a small reminder that time is finite. Gratitude-flavoured, not grim.
    let reflection: String?
    /// Set when a buddy has only dropped by to say this one line.
    let reminder: String?

    var onDismiss: (() -> Void)?
    var onComplete: ((JournalEntry) -> Void)?

    static let feelings = [
        "calm", "focused", "content", "tired", "tense", "restless",
        "frustrated", "anxious", "flat", "scattered", "glad", "overwhelmed",
    ]

    private static let greetings = [
        "Hey. Got a second?",
        "Quick pause?",
        "Checking in.",
        "Hi. Mind stopping for a moment?",
        "Still here. Want to check in?",
    ]

    private static let doneTitles = ["Noted.", "Got it.", "Thanks."]

    static let reflections = [
        "Remember, it's later than you think.",
        "Today is all we ever really have.",
        "This hour won't come around again. That's what makes it worth noticing.",
        "You won't always be here. Right now, you are.",
        "Someday you'll miss an ordinary afternoon like this one.",
        "Everything you love is temporary.",
        "The days are long and the years are short.",
        "One of these ordinary days will be the last one.",
        "Remember you'll die, so remember to live.",
        "Nothing is permanent.",
        "We never arrive at someday. Today is all there is.",
        "The people you love are mortal too.",
        "You are alive right now. Don't forget.",
    ]

    /// Roughly one check-in in three carries a reflection.
    static let reflectionChance = 0.35

    /// Once or twice a day, a buddy drops by with just one of these. No questions, nothing saved.
    static let reminders = [
        "Remember why you're doing this.",
        "Are you acting from a place of service?",
        "How can you enjoy this moment just a little bit more?",
    ]

    init(isIntro: Bool, kind: BuddyKind = .next(), meet: Bool = false, reminder: String? = nil,
         reflection: String?? = nil) {
        self.isIntro = isIntro
        self.kind = kind
        if meet { self.step = .meet }
        if reminder != nil { self.step = .reminder }
        self.reminder = reminder
        self.greeting = Self.greetings.randomElement()!
        self.doneTitle = Self.doneTitles.randomElement()!
        if let forced = reflection {
            self.reflection = forced
        } else {
            self.reflection = (!isIntro && Double.random(in: 0..<1) < Self.reflectionChance)
                ? Self.reflections.randomElement() : nil
        }
    }

    var mood: Mood {
        switch step {
        case .greeting: return .neutral
        case .feelings, .gratitude: return .attentive
        case .done: return .happy
        case .meet: return .neutral
        case .reminder: return .neutral
        }
    }

    var gratitudeTrimmed: String {
        gratitude.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func begin() {
        guard step == .greeting else { return }
        step = .feelings
    }

    func toFeelingsDone() {
        guard step == .feelings else { return }
        step = .gratitude
    }

    func finish(skipGratitude: Bool = false) {
        guard step == .gratitude else { return }
        if skipGratitude { gratitude = "" }

        var feelings = Self.feelings.filter { selected.contains($0) }
        let other = otherFeeling.trimmingCharacters(in: .whitespacesAndNewlines)
        if !other.isEmpty { feelings.append(other) }

        let entry = JournalEntry(date: Date(), feelings: feelings, gratitude: gratitudeTrimmed)
        step = .done
        onComplete?(entry)
    }

    func dismiss() {
        onDismiss?()
    }
}
