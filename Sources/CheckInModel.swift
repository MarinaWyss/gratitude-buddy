import Foundation
import Combine

enum Mood { case neutral, attentive, happy }

/// State for one check-in conversation.
final class CheckInModel: ObservableObject {
    enum Step { case greeting, feelings, gratitude, done }

    @Published var step: Step = .greeting
    @Published var selected: Set<String> = []
    @Published var otherFeeling = ""
    @Published var gratitude = ""

    let isIntro: Bool
    let kind: BuddyKind
    let greeting: String
    let doneTitle: String

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

    init(isIntro: Bool, kind: BuddyKind = .next()) {
        self.isIntro = isIntro
        self.kind = kind
        self.greeting = Self.greetings.randomElement()!
        self.doneTitle = Self.doneTitles.randomElement()!
    }

    var mood: Mood {
        switch step {
        case .greeting: return .neutral
        case .feelings, .gratitude: return .attentive
        case .done: return .happy
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
