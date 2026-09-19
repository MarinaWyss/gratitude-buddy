import SwiftUI

enum Theme {
    static let accent = Color(red: 0.86, green: 0.49, blue: 0.37)
    static let ink = Color(red: 0.12, green: 0.09, blue: 0.08)
    static let pink = Color(red: 0.93, green: 0.58, blue: 0.62)
}

/// The three buddies take turns, one per check-in.
enum BuddyKind: Int, CaseIterable {
    case fluffyCat, sleekCat, goldenRetriever

    var name: String {
        switch self {
        case .fluffyCat: return "Toki"
        case .sleekCat: return "Skwisgaar"
        case .goldenRetriever: return "Appa"
        }
    }

    var species: String {
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


extension BuddyKind {
    var slug: String { name.lowercased() }
}

extension Mood {
    var slug: String {
        switch self {
        case .neutral: return "neutral"
        case .attentive: return "curious"
        case .happy: return "happy"
        }
    }
}

/// Illustrated art for each buddy and mood, e.g. `toki-curious.png`. Looked up in the app bundle's
/// `buddies` folder, then `$BUDDY_ART_DIR`, then `Resources/buddies` under the working directory
/// (for the preview and icon tools). A missing mood falls back to neutral; a missing buddy falls
/// back to the drawn version below.
enum BuddyArt {
    private static var cache: [String: NSImage?] = [:]

    private static var directories: [URL] {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("buddies")) }
        if let env = ProcessInfo.processInfo.environment["BUDDY_ART_DIR"] { dirs.append(URL(fileURLWithPath: env)) }
        dirs.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/buddies"))
        return dirs
    }

    static func image(for kind: BuddyKind, mood: Mood) -> NSImage? {
        let key = "\(kind.slug)-\(mood.slug)"
        if let cached = cache[key] { return cached }
        var found: NSImage? = nil
        for dir in directories {
            if let img = NSImage(contentsOf: dir.appendingPathComponent(key + ".png")) { found = img; break }
        }
        if found == nil, mood != .neutral { found = image(for: kind, mood: .neutral) }
        cache[key] = found
        return found
    }
}

/// Shared frame, bobbing and blinking. The species-specific drawing lives below.
struct BuddyFace: View {
    var kind: BuddyKind
    var mood: Mood
    var size: CGFloat = 150          // height in points

    @State private var eyesClosed = false
    @State private var bobbing = false
    @State private var alive = false

    private static let moods: [Mood] = [.neutral, .attentive, .happy]

    var body: some View {
        Group {
            if BuddyArt.image(for: kind, mood: .neutral) != nil {
                // Every expression is laid out, only the current one is visible, so moods crossfade.
                ZStack(alignment: .bottom) {
                    ForEach(Self.moods, id: \.slug) { m in
                        if let art = BuddyArt.image(for: kind, mood: m) {
                            Image(nsImage: art)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(height: size)
                                .opacity(m == mood ? 1 : 0)
                        }
                    }
                }
                .scaleEffect(mood == .attentive ? 1.03 : 1, anchor: .bottom)
            } else {
                drawn
                    .scaleEffect(size / 110)
                    .frame(width: 100 * size / 110, height: size)
            }
        }
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

    /// Vector fallback, used only when no illustration is available.
    private var drawn: some View {
        ZStack {
            switch kind {
            case .fluffyCat: CatFace(fluffy: true, mood: mood, eyesClosed: eyesClosed)
            case .sleekCat: CatFace(fluffy: false, mood: mood, eyesClosed: eyesClosed)
            case .goldenRetriever: DogFace(mood: mood, eyesClosed: eyesClosed)
            }
        }
        .frame(width: 100, height: 110)
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

// MARK: - Cats (Toki is fluffy, Skwisgaar is sleek)

private struct CatFace: View {
    let fluffy: Bool
    let mood: Mood
    let eyesClosed: Bool

    private var furTop: Color { fluffy ? Color(white: 0.26) : Color(white: 0.19) }
    private var furMid: Color { fluffy ? Color(white: 0.17) : Color(white: 0.12) }
    private var furBottom: Color { fluffy ? Color(white: 0.12) : Color(white: 0.08) }
    private var outline: Color { Color.white.opacity(0.30) }   // keeps the silhouette readable on dark cards
    private var iris: Color {
        fluffy ? Color(red: 0.87, green: 0.80, blue: 0.27)      // Toki: yellow with a hint of green
               : Color(red: 0.95, green: 0.78, blue: 0.24)      // Skwisgaar: yellow
    }
    private var whisker: Color { Color.white.opacity(fluffy ? 0.62 : 0.45) }
    private var noseColor: Color { fluffy ? Color(white: 0.07) : Theme.pink }

    var body: some View {
        ZStack {
            ear(left: true)
            ear(left: false)

            if fluffy {
                let head = FluffyBlob(bumps: 24, amplitude: 3.2, ruff: 5.5)
                head.fill(LinearGradient(colors: [furTop, furMid, furBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(head.stroke(outline, lineWidth: 1))
                    .frame(width: 96, height: 92)
            } else {
                Ellipse()
                    .fill(LinearGradient(colors: [furTop, furBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(Ellipse().stroke(outline, lineWidth: 1))
                    .frame(width: 84, height: 72)
                Ellipse()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 38, height: 14)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -14, y: -22)
            }

            HStack(spacing: fluffy ? 15 : 18) {
                CatEye(mood: mood, closed: eyesClosed, iris: iris, tilt: -7)
                CatEye(mood: mood, closed: eyesClosed, iris: iris, tilt: 7)
            }
            .offset(y: -3)

            if fluffy {
                // brow whiskers
                BrowWhiskers()
                    .stroke(whisker, style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                    .frame(width: 11, height: 12)
                    .offset(x: -18, y: -19)
                BrowWhiskers()
                    .stroke(whisker, style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                    .frame(width: 11, height: 12)
                    .scaleEffect(x: -1)
                    .offset(x: 18, y: -19)
            }

            ZStack {
                NoseShape().fill(noseColor)
                Ellipse().fill(.white.opacity(fluffy ? 0.28 : 0.45))
                    .frame(width: 3, height: 1.4).offset(x: -1.2, y: -1.2)
            }
            .frame(width: 7, height: 5)
            .offset(y: 11)

            CatMouth()
                .stroke(Color(white: fluffy ? 0.5 : 0.4), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                .frame(width: mood == .happy ? 16 : 13, height: 5)
                .offset(y: 17.5)

            Whiskers(count: fluffy ? 4 : 3, curved: fluffy)
                .stroke(whisker, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(width: fluffy ? 30 : 26, height: fluffy ? 18 : 16)
                .offset(x: fluffy ? 38 : 36, y: 12)
            Whiskers(count: fluffy ? 4 : 3, curved: fluffy)
                .stroke(whisker, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(width: fluffy ? 30 : 26, height: fluffy ? 18 : 16)
                .scaleEffect(x: -1)
                .offset(x: fluffy ? -38 : -36, y: 12)
        }
        .offset(y: 8)
    }

    private func ear(left: Bool) -> some View {
        let w: CGFloat = fluffy ? 32 : 22
        let h: CGFloat = fluffy ? 36 : 31
        let tilt: Double = mood == .attentive ? 6 : 15
        return CatEar(fur: furMid, outline: outline, fluffy: fluffy)
            .frame(width: w, height: h)
            .scaleEffect(x: left ? 1 : -1)
            .rotationEffect(.degrees(left ? -tilt : tilt))
            .offset(x: left ? -27 : 27, y: fluffy ? -40 : -34)
    }
}

private struct CatEar: View {
    let fur: Color
    let outline: Color
    let fluffy: Bool

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                EarShape().fill(fur)
                EarShape().stroke(outline, lineWidth: 1)
                EarShape()
                    .fill(fluffy ? Color(red: 0.62, green: 0.46, blue: 0.46).opacity(0.75)
                                 : Theme.pink.opacity(0.75))
                    .scaleEffect(x: 0.5, y: 0.58, anchor: .bottom)
                    .offset(y: -2)
                if fluffy {
                    // lynx tufts
                    TuftShape()
                        .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                        .frame(width: 14, height: 16)
                        .offset(y: -h / 2 - 6)
                }
            }
            .frame(width: geo.size.width, height: h)
        }
    }
}

private struct CatEye: View {
    let mood: Mood
    let closed: Bool
    let iris: Color
    let tilt: Double

    var body: some View {
        Group {
            if mood == .happy {
                HappyEye()
                    .stroke(iris, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 12, height: 6)
            } else {
                let wide = mood == .attentive
                let w: CGFloat = 16
                let h: CGFloat = wide ? 12 : 9.5
                ZStack {
                    AlmondShape()
                        .fill(LinearGradient(colors: [iris.opacity(0.85), iris], startPoint: .top, endPoint: .bottom))
                    // pupils dilate when a cat is interested
                    if wide {
                        Circle().fill(Theme.ink).frame(width: h * 0.72, height: h * 0.72)
                    } else {
                        Capsule().fill(Theme.ink).frame(width: 2.8, height: h * 0.9)
                    }
                    Circle().fill(.white.opacity(0.9)).frame(width: 2.6, height: 2.6)
                        .offset(x: -3, y: -2)
                }
                .frame(width: w, height: h)
                .clipShape(AlmondShape())
                .rotationEffect(.degrees(tilt))
                .scaleEffect(y: closed ? 0.08 : 1, anchor: .center)
            }
        }
        .frame(width: 16, height: 12)
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

/// Cat eye: pointed at both corners.
private struct AlmondShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.45))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.45))
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

/// Three wisps rising from an ear tip.
private struct TuftShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let base = CGPoint(x: r.midX, y: r.maxY)
        p.move(to: base); p.addQuadCurve(to: CGPoint(x: r.midX - 5, y: r.minY + 2), control: CGPoint(x: r.midX - 1, y: r.midY))
        p.move(to: base); p.addQuadCurve(to: CGPoint(x: r.midX - 1, y: r.minY), control: CGPoint(x: r.midX, y: r.midY))
        p.move(to: base); p.addQuadCurve(to: CGPoint(x: r.midX + 4, y: r.minY + 4), control: CGPoint(x: r.midX + 1, y: r.midY))
        return p
    }
}

private struct InnerEarFur: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for f in [0.25, 0.5, 0.75] {
            let x = r.minX + r.width * CGFloat(f)
            p.move(to: CGPoint(x: x, y: r.maxY))
            p.addLine(to: CGPoint(x: x + (CGFloat(f) - 0.5) * 6, y: r.minY + r.height * 0.3))
        }
        return p
    }
}

private struct BrowWhiskers: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let base = CGPoint(x: r.maxX, y: r.maxY)
        p.move(to: base); p.addLine(to: CGPoint(x: r.minX, y: r.midY + 1))
        p.move(to: base); p.addLine(to: CGPoint(x: r.minX + 4, y: r.minY))
        p.move(to: base); p.addLine(to: CGPoint(x: r.midX + 2, y: r.minY - 2))
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
    var count: Int = 3
    var curved: Bool = false

    func path(in r: CGRect) -> Path {
        var p = Path()
        for i in 0..<count {
            let f = CGFloat(i) / CGFloat(max(count - 1, 1))          // 0...1 top to bottom
            let start = CGPoint(x: r.minX, y: r.midY - 3 + f * 6)
            let end = CGPoint(x: r.maxX, y: r.minY + f * r.height)
            p.move(to: start)
            if curved {
                let ctrl = CGPoint(x: r.midX, y: (start.y + end.y) / 2 + (f - 0.5) * 4)
                p.addQuadCurve(to: end, control: ctrl)
            } else {
                p.addLine(to: end)
            }
        }
        return p
    }
}

// MARK: - Appa the golden retriever

private struct DogFace: View {
    let mood: Mood
    let eyesClosed: Bool

    private let cream = Color(red: 0.97, green: 0.94, blue: 0.86)
    private let creamLight = Color(red: 0.995, green: 0.98, blue: 0.93)
    private let warm = Color(red: 0.93, green: 0.83, blue: 0.64)
    private let earTop = Color(red: 0.91, green: 0.77, blue: 0.53)
    private let earBottom = Color(red: 0.83, green: 0.66, blue: 0.42)
    private let line = Color(red: 0.72, green: 0.60, blue: 0.42)
    private let brown = Color(red: 0.16, green: 0.10, blue: 0.07)
    private let mouthDark = Color(red: 0.24, green: 0.10, blue: 0.09)

    var body: some View {
        ZStack {
            // floppy, fluffy ears set high and behind the head
            DogEar(top: earTop, bottom: earBottom, line: line)
                .rotationEffect(.degrees(mood == .attentive ? 16 : 7), anchor: .top)
                .offset(x: -42, y: 6)
            DogEar(top: earTop, bottom: earBottom, line: line)
                .rotationEffect(.degrees(mood == .attentive ? -16 : -7), anchor: .top)
                .offset(x: 42, y: 6)

            let head = FluffyBlob(bumps: 36, amplitude: 0.8, ruff: 1.2)
            head.fill(LinearGradient(colors: [creamLight, cream], startPoint: .top, endPoint: .bottom))
                .overlay(head.stroke(line.opacity(0.45), lineWidth: 1))
                .frame(width: 92, height: 80)

            // warmer tone across the crown, like the photo
            Ellipse().fill(warm.opacity(0.22))
                .frame(width: 54, height: 18)
                .offset(y: -26)
                .blur(radius: 3)

            // muzzle
            Ellipse().fill(Color.white.opacity(0.55))
                .frame(width: 42, height: 28)
                .offset(y: 14)

            HStack(spacing: 24) {
                DogEye(mood: mood, closed: eyesClosed, brown: brown)
                DogEye(mood: mood, closed: eyesClosed, brown: brown)
            }
            .offset(y: -7)

            // big black nose
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.ink)
                Ellipse().fill(.white.opacity(0.35)).frame(width: 6, height: 3).offset(x: -3.5, y: -3)
            }
            .frame(width: 17, height: 12)
            .offset(y: 6)

            if mood != .happy {
                Capsule().fill(brown.opacity(0.55)).frame(width: 1.4, height: 5).offset(y: 14.5)
            }

            mouth
        }
        .offset(y: 8)
        .rotationEffect(.degrees(mood == .attentive ? 9 : 0))
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .happy:
            ZStack {
                SmileMouth().fill(mouthDark)
                Ellipse().fill(Theme.pink).frame(width: 15, height: 13).offset(y: 5)
                // the two little lower teeth
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.95)).frame(width: 2.6, height: 3)
                    RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.95)).frame(width: 2.6, height: 3)
                }
                .offset(y: 6.5)
            }
            .frame(width: 26, height: 13)
            .clipShape(SmileMouth())
            .offset(y: 21)
        case .attentive:
            SoftSmile()
                .stroke(brown, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 12, height: 4)
                .offset(y: 20)
        case .neutral:
            SoftSmile()
                .stroke(brown, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 18, height: 6)
                .offset(y: 20)
        }
    }
}

private struct DogEar: View {
    let top: Color
    let bottom: Color
    let line: Color
    var body: some View {
        let shape = FluffyBlob(bumps: 14, amplitude: 0.9, ruff: 1.2)
        shape.fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
            .overlay(shape.stroke(line.opacity(0.5), lineWidth: 1))
            .frame(width: 30, height: 54)
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
                    .frame(width: 11, height: 6)
            } else {
                let d: CGFloat = mood == .attentive ? 12 : 11
                ZStack {
                    Circle().fill(brown)
                    Circle().fill(.white.opacity(0.92)).frame(width: 3.6, height: 3.6).offset(x: -2.4, y: -2.6)
                    Circle().fill(.white.opacity(0.5)).frame(width: 1.6, height: 1.6).offset(x: 2.4, y: 2.2)
                }
                .frame(width: d, height: d)
                .scaleEffect(y: closed ? 0.08 : 1, anchor: .center)
            }
        }
        .frame(width: 12, height: 12)
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
