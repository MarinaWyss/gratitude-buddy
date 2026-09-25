import SwiftUI

/// The card the buddy peeks over. Content changes with the check-in step.
struct BuddyView: View {
    @ObservedObject var model: CheckInModel
    @FocusState private var focus: Field?

    enum Field { case other, gratitude }

    var body: some View {
        ZStack(alignment: .topLeading) {
            card.padding(.top, model.step == .meet ? 0 : 98)
            if model.step != .meet {
                BuddyFace(kind: model.kind, mood: model.mood).padding(.leading, 18)
            }
        }
        .padding(18)
        .fixedSize()
        .tint(Theme.accent)
        .onChange(of: model.step) { _, step in
            if step == .gratitude {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = .gratitude }
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, model.step == .meet ? 20 : 66)
        .padding(.bottom, 18)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .greeting: greeting
        case .feelings: feelings
        case .gratitude: gratitude
        case .done: done
        case .meet: MeetView(onClose: { model.dismiss() })
        case .reminder: reminder
        }
    }

    // MARK: Steps

    private var greeting: some View {
        Group {
            if model.isIntro {
                TitleText("Hi. I'm \(model.kind.name).")
                BodyText("About once an hour I'll pop up and ask two quick things: how you're feeling, and whether there's anything to be grateful for.\n\nYou can snooze or pause me from the paw in your menu bar.\n\nThere are three of us, Toki, Skwisgaar and Appa, and we take turns. Want to try one now?")
            } else {
                TitleText(model.greeting)
                BodyText("Take one slow breath first.")
            }
            HStack {
                Spacer()
                Button(model.isIntro ? "Later" : "Not now") { model.dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button(model.isIntro ? "Sure" : "Okay") { model.begin() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
    }

    private var feelings: some View {
        Group {
            TitleText("What's here right now?")
            if let line = model.reflection {
                Text(line)
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)
            }
            BodyText("Pick whatever fits. Nothing to fix.")
            FlowLayout(spacing: 6) {
                ForEach(CheckInModel.feelings, id: \.self) { f in
                    Chip(label: f, selected: model.selected.contains(f)) {
                        if model.selected.contains(f) { model.selected.remove(f) }
                        else { model.selected.insert(f) }
                    }
                }
            }
            .padding(.top, 2)
            InputField("or something else", text: $model.otherFeeling)
                .focused($focus, equals: .other)
            HStack {
                Spacer()
                Button("Next") { model.toFeelingsDone() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
    }

    private var gratitude: some View {
        Group {
            TitleText("Anything to be grateful for, right now?")
            BodyText("Small counts. It's fine if there's nothing today.")
            InputField("Something small is enough", text: $model.gratitude)
                .focused($focus, equals: .gratitude)
            HStack {
                Spacer()
                Button("Nothing today") { model.finish(skipGratitude: true) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button("Save") { model.finish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
    }

    private var done: some View {
        Group {
            TitleText(model.doneTitle)
            if model.gratitudeTrimmed.isEmpty {
                BodyText("That's okay. See you in about an hour.")
            } else {
                BodyText("Saved to your journal. See you in about an hour.")
            }
        }
    }

    private var reminder: some View {
        Group {
            Text(model.reminder ?? "")
                .font(.system(size: 17, design: .serif).italic())
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Thanks") { model.dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Small pieces

private struct TitleText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BodyText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct InputField: View {
    let placeholder: String
    @Binding var text: String
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10))
            )
    }
}

private struct Chip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(selected ? Theme.accent : Color.primary.opacity(0.06)))
                .overlay(Capsule().strokeBorder(selected ? Theme.accent : Color.primary.opacity(0.12)))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}

/// Wraps chips onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                    proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Meet the buddies

/// All three side by side, each cycling through its expressions.
private struct MeetView: View {
    let onClose: () -> Void
    @State private var tick = 0
    private let moods: [Mood] = [.neutral, .attentive, .happy]
    private let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            TitleText("Toki, Skwisgaar and Appa.")
            BodyText("They take turns, one per check-in.")
            HStack(spacing: 0) {
                ForEach(Array(BuddyKind.allCases.enumerated()), id: \.element.rawValue) { i, kind in
                    VStack(spacing: 2) {
                        BuddyFace(kind: kind, mood: moods[(tick + i) % moods.count], size: 110)
                        Text(kind.name)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                        Text(kind.species)
                            .font(.system(size: 10.5, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(width: 100)
                    }
                }
            }
            .padding(.top, 6)
            .onReceive(timer) { _ in tick += 1 }
            HStack {
                Spacer()
                Button("Nice") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
    }
}
