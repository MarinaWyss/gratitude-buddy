import SwiftUI

enum Theme {
    static let accent = Color(red: 0.86, green: 0.49, blue: 0.37)
    static let ink = Color(red: 0.16, green: 0.12, blue: 0.10)
    static let pink = Color(red: 0.93, green: 0.58, blue: 0.62)
}

/// The three buddies take turns, one per check-in.
enum BuddyKind: Int, CaseIterable {
    case fluffyCat, sleekCat, goldenRetriever

    var name: String {
        switch self {
        case .fluffyCat: return "fluffy black cat"
        case .sleekCat: return "sleek black cat"
        case .goldenRetriever: return "cream golden retriever"
        }
    }

    /// Returns whoever is up next and advances the persisted turn counter.
    static func next() -> BuddyKind {
        let all = BuddyKind.allCases
        let idx = Settings.buddyTurn % all.count
        Settings.buddyTurn = idx + 1
        return all[idx]
    }
}

/// Shared frame, bobbing and blinking. The species-specific drawing lives below.
struct BuddyFace: View {
    var kind: BuddyKind
    var mood: Mood

    @State private var eyesClosed = false
    @State private var bobbing = false
    @State private var alive = false

    var body: some View {
        ZStack {
            switch kind {
            case .fluffyCat: CatFace(fluffy: true, mood: mood, eyesClosed: eyesClosed)
            case .sleekCat: CatFace(fluffy: false, mood: mood, eyesClosed: eyesClosed)
            case .goldenRetriever: DogFace(mood: mood, eyesClosed: eyesClosed)
            }
        }
        .frame(width: 100, height: 110)
        .offset(y: bobbing ? -2.5 : 2.5)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: mood)
        .onAppear {
            alive = true
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                bobbing = true
            }
            scheduleBlink()
        }
        .onDisappear { alive = false }
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.5...5.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard alive else { return }
            withAnimation(.easeInOut(duration: 0.07)) { eyesClosed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.easeInOut(duration: 0.09)) { eyesClosed = false }
                scheduleBlink()
            }
        }
    }
}

// MARK: - Cats

private struct CatFace: View {
    let fluffy: Bool
    let mood: Mood
    let eyesClosed: Bool

    private var fur: Color { fluffy ? Color(white: 0.17) : Color(white: 0.11) }
    private var furLight: Color { fluffy ? Color(white: 0.30) : Color(white: 0.24) }
    private var outline: Color { Color.white.opacity(0.30) }   // keeps the silhouette readable on dark cards
    private var iris: Color { Color(red: 0.95, green: 0.78, blue: 0.24) }   // yellow, both cats
    private var whisker: Color { Color.white.opacity(0.45) }

    var body: some View {
        ZStack {
            // ears sit behind the head
            CatEar(fur: fur, outline: outline, fluffy: fluffy)
                .frame(width: fluffy ? 30 : 22, height: fluffy ? 32 : 31)
                .rotationEffect(.degrees(mood == .attentive ? -8 : -16))
                .offset(x: -27, y: fluffy ? -40 : -34)
            CatEar(fur: fur, outline: outline, fluffy: fluffy)
                .scaleEffect(x: -1)
                .frame(width: fluffy ? 30 : 22, height: fluffy ? 32 : 31)
                .rotationEffect(.degrees(mood == .attentive ? 8 : 16))
                .offset(x: 27, y: fluffy ? -40 : -34)

            if fluffy {
                FluffyBlob()
                    .fill(fur)
                    .overlay(FluffyBlob().stroke(outline, lineWidth: 1))
                    .frame(width: 96, height: 86)
                // a little volume on the cheeks
                HStack(spacing: 40) {
                    Ellipse().fill(furLight.opacity(0.5)).frame(width: 22, height: 16)
                    Ellipse().fill(furLight.opacity(0.5)).frame(width: 22, height: 16)
                }
                .offset(y: 12)
            } else {
                Ellipse()
                    .fill(fur)
                    .overlay(Ellipse().stroke(outline, lineWidth: 1))
                    .frame(width: 84, height: 72)
                // glossy sheen
                Ellipse()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 38, height: 14)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -14, y: -22)
            }

            HStack(spacing: fluffy ? 18 : 20) {
                CatEye(mood: mood, closed: eyesClosed, iris: iris, sleek: !fluffy)
                CatEye(mood: mood, closed: eyesClosed, iris: iris, sleek: !fluffy)
            }
            .offset(y: -2)

            NoseShape()
                .fill(Theme.pink)
                .frame(width: 7, height: 5)
                .offset(y: 12)

            CatMouth()
                .stroke(furLight.opacity(1.6), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: mood == .happy ? 16 : 13, height: 5)
                .offset(y: 18.5)

            Whiskers()
                .stroke(whisker, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(width: 26, height: 16)
                .offset(x: 36, y: 13)
            Whiskers()
                .stroke(whisker, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(width: 26, height: 16)
                .scaleEffect(x: -1)
                .offset(x: -36, y: 13)
        }
        .offset(y: 8)
    }
}

private struct CatEar: View {
    let fur: Color
    let outline: Color
    let fluffy: Bool

    var body: some View {
        ZStack {
            EarShape().fill(fur)
            EarShape().stroke(outline, lineWidth: 1)
            EarShape()
                .fill(Theme.pink.opacity(0.75))
                .scaleEffect(x: 0.5, y: 0.55, anchor: .bottom)
                .offset(y: -2)
            if fluffy {
                // lynx-style tuft at the tip
                EarShape().fill(fur).frame(width: 5, height: 11).offset(y: -19)
                EarShape().stroke(outline, lineWidth: 0.8).frame(width: 5, height: 11).offset(y: -19)
            }
        }
    }
}

private struct CatEye: View {
    let mood: Mood
    let closed: Bool
    let iris: Color
    let sleek: Bool

    var body: some View {
        Group {
            if mood == .happy {
                HappyEye()
                    .stroke(iris, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 11, height: 6)
            } else {
                let wide = mood == .attentive
                let w: CGFloat = sleek ? 14 : 13
                let h: CGFloat = wide ? 12 : (sleek ? 8 : 10)
                ZStack {
                    Ellipse().fill(iris).frame(width: w, height: h)
                    // pupils dilate when a cat is interested
                    if wide {
                        Circle().fill(Theme.ink).frame(width: h * 0.78, height: h * 0.78)
                    } else {
                        Capsule().fill(Theme.ink).frame(width: 3, height: h * 0.85)
                    }
                    Circle().fill(.white.opacity(0.9)).frame(width: 2.6, height: 2.6)
                        .offset(x: -2.5, y: -2.2)
                }
                .scaleEffect(y: closed ? 0.08 : 1, anchor: .center)
            }
        }
        .frame(width: 14, height: 12)
    }
}

/// A round-ish head with straight, pointed tufts around the edge (Maine coon, not poodle).
/// The tufts get longer toward the cheeks and jaw to suggest a ruff.
struct FluffyBlob: Shape {
    var bumps: Int = 22
    var amplitude: CGFloat = 3.5
    var ruff: CGFloat = 3

    func path(in r: CGRect) -> Path {
        var p = Path()
        let cx = r.midX, cy = r.midY
        let maxAmp = amplitude + ruff
        let rx = r.width / 2 - maxAmp, ry = r.height / 2 - maxAmp
        let steps = 360
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
            // sharp peaks pointing outward, rounded valleys between them
            let spike = 1 - abs(sin(t * CGFloat(bumps) / 2))
            let amp = amplitude + ruff * max(0, sin(t))          // sin(t) > 0 is the lower half
            let bump = amp * pow(spike, 1.6)
            let pt = CGPoint(x: cx + (rx + bump) * cos(t), y: cy + (ry + bump) * sin(t))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct EarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.minX + r.width * 0.12, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                       control: CGPoint(x: r.maxX - r.width * 0.12, y: r.midY))
        p.closeSubpath()
        return p
    }
}

private struct NoseShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY), control: CGPoint(x: r.minX, y: r.maxY))
        return p
    }
}

/// The little "ω" under a cat's nose.
private struct CatMouth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.minX + r.width * 0.25, y: r.maxY + 2))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.maxX - r.width * 0.25, y: r.maxY + 2))
        return p
    }
}

private struct Whiskers: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY - 2)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.move(to: CGPoint(x: r.minX, y: r.midY));     p.addLine(to: CGPoint(x: r.maxX, y: r.midY + 1))
        p.move(to: CGPoint(x: r.minX, y: r.midY + 2)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

// MARK: - Golden retriever

private struct DogFace: View {
    let mood: Mood
    let eyesClosed: Bool

    private let cream = Color(red: 0.97, green: 0.93, blue: 0.84)
    private let creamLight = Color(red: 0.99, green: 0.97, blue: 0.91)
    private let creamDark = Color(red: 0.90, green: 0.82, blue: 0.66)
    private let creamLine = Color(red: 0.72, green: 0.61, blue: 0.44)
    private let brown = Color(red: 0.28, green: 0.19, blue: 0.13)

    var body: some View {
        ZStack {
            // floppy ears hang behind the head
            DogEar(fill: creamDark, line: creamLine)
                .rotationEffect(.degrees(mood == .attentive ? -14 : -7))
                .offset(x: -39, y: 10)
            DogEar(fill: creamDark, line: creamLine)
                .rotationEffect(.degrees(mood == .attentive ? 14 : 7))
                .offset(x: 39, y: 10)

            Ellipse()
                .fill(LinearGradient(colors: [creamLight, cream], startPoint: .top, endPoint: .bottom))
                .overlay(Ellipse().stroke(creamLine.opacity(0.5), lineWidth: 1))
                .frame(width: 86, height: 74)

            // muzzle
            Ellipse()
                .fill(Color.white.opacity(0.5))
                .frame(width: 38, height: 24)
                .offset(y: 15)

            HStack(spacing: 26) {
                DogEye(mood: mood, closed: eyesClosed, brown: brown)
                DogEye(mood: mood, closed: eyesClosed, brown: brown)
            }
            .offset(y: -5)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.ink)
                .frame(width: 13, height: 9)
                .overlay(
                    Ellipse().fill(.white.opacity(0.35)).frame(width: 5, height: 2.5).offset(x: -2, y: -2)
                )
                .offset(y: 9)

            mouth
        }
        .offset(y: 8)
        .rotationEffect(.degrees(mood == .attentive ? 9 : 0))
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .happy:
            ZStack {
                SmileMouth().fill(brown)
                Ellipse().fill(Theme.pink).frame(width: 9, height: 8).offset(y: 4)
                    .clipShape(SmileMouth())
            }
            .frame(width: 20, height: 11)
            .offset(y: 20)
        case .attentive:
            SoftSmile()
                .stroke(brown, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 10, height: 4)
                .offset(y: 19)
        case .neutral:
            SoftSmile()
                .stroke(brown, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 16, height: 6)
                .offset(y: 19)
        }
    }
}

private struct DogEar: View {
    let fill: Color
    let line: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .circular)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .circular).stroke(line.opacity(0.55), lineWidth: 1))
            .frame(width: 24, height: 48)
    }
}

private struct DogEye: View {
    let mood: Mood
    let closed: Bool
    let brown: Color

    var body: some View {
        Group {
            if mood == .happy {
                HappyEye()
                    .stroke(brown, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 10, height: 6)
            } else {
                let d: CGFloat = mood == .attentive ? 10.5 : 9.5
                Circle().fill(brown).frame(width: d, height: d)
                    .overlay(alignment: .topLeading) {
                        Circle().fill(.white.opacity(0.9)).frame(width: 3.2, height: 3.2)
                            .offset(x: 1.6, y: 1.6)
                    }
                    .scaleEffect(y: closed ? 0.08 : 1, anchor: .center)
            }
        }
        .frame(width: 11, height: 11)
    }
}

/// Open, happy mouth: flat on top, round underneath.
private struct SmileMouth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.9))
        p.closeSubpath()
        return p
    }
}

private struct SoftSmile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.6))
        return p
    }
}

// MARK: - Shared

/// Closed, content eyes: a gentle upward arc.
struct HappyEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                       control: CGPoint(x: r.midX, y: r.minY - r.height * 0.6))
        return p
    }
}
