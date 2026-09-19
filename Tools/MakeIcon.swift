import AppKit

// Draws the fluffy black cat into an .iconset folder. Usage: MakeIcon <output.iconset>
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func render(pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))

    let s = CGFloat(pixels) / 1024.0
    func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }

    let fur = color(0.17, 0.17, 0.17)
    let furLight = color(0.30, 0.30, 0.30)
    let outline = color(1, 1, 1, 0.22)
    let amber = color(0.95, 0.78, 0.24)
    let ink = color(0.10, 0.08, 0.07)
    let pink = color(0.93, 0.58, 0.62)

    // Background tile with a soft shadow.
    let tile = NSBezierPath(roundedRect: R(100, 100, 824, 824), xRadius: 186 * s, yRadius: 186 * s)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    color(0.99, 0.95, 0.89).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Ears (behind the head)
    func ear(cx: CGFloat, flip: CGFloat) {
        let p = NSBezierPath()
        p.move(to: P(cx - 95, 620))
        p.curve(to: P(cx, 870), controlPoint1: P(cx - 85, 750), controlPoint2: P(cx - 30, 850))
        p.curve(to: P(cx + 95, 620), controlPoint1: P(cx + 30, 850), controlPoint2: P(cx + 85, 750))
        p.close()
        var t = AffineTransform.identity
        t.translate(x: cx * s, y: 620 * s)
        t.rotate(byDegrees: -14 * flip)
        t.translate(x: -cx * s, y: -610 * s)
        p.transform(using: t)
        fur.setFill(); p.fill()
        outline.setStroke(); p.lineWidth = 6 * s; p.stroke()
        // tuft at the tip
        let tuft = NSBezierPath()
        tuft.move(to: P(cx - 18, 850)); tuft.line(to: P(cx, 930)); tuft.line(to: P(cx + 18, 850)); tuft.close()
        tuft.transform(using: t)
        fur.setFill(); tuft.fill()
        // inner ear
        let inner = NSBezierPath()
        inner.move(to: P(cx - 45, 668))
        inner.curve(to: P(cx, 790), controlPoint1: P(cx - 40, 740), controlPoint2: P(cx - 15, 780))
        inner.curve(to: P(cx + 45, 668), controlPoint1: P(cx + 15, 780), controlPoint2: P(cx + 40, 740))
        inner.close()
        inner.transform(using: t)
        pink.withAlphaComponent(0.75).setFill(); inner.fill()
    }
    ear(cx: 512 - 190, flip: 1)
    ear(cx: 512 + 190, flip: -1)

    // Fluffy head: scalloped ellipse
    let head = NSBezierPath()
    let cx: CGFloat = 512, cy: CGFloat = 470, rx: CGFloat = 305, ry: CGFloat = 275, amp: CGFloat = 16, ruff: CGFloat = 16, bumps: CGFloat = 22
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let spike = 1 - abs(sin(t * bumps / 2))
        let bump = (amp + ruff * max(0, -sin(t))) * pow(spike, 1.6)   // AppKit is y-up: -sin is the lower half
        let pt = P(cx + (rx + bump) * cos(t), cy + (ry + bump) * sin(t))
        if i == 0 { head.move(to: pt) } else { head.line(to: pt) }
    }
    head.close()
    fur.setFill(); head.fill()
    outline.setStroke(); head.lineWidth = 6 * s; head.stroke()

    // cheek volume
    furLight.withAlphaComponent(0.5).setFill()
    NSBezierPath(ovalIn: R(300, 360, 150, 100)).fill()
    NSBezierPath(ovalIn: R(574, 360, 150, 100)).fill()

    // Eyes: amber with slit pupils
    for ex in [cx - 105, cx + 105] {
        amber.setFill()
        NSBezierPath(ovalIn: R(ex - 48, 470, 96, 72)).fill()
        ink.setFill()
        NSBezierPath(roundedRect: R(ex - 11, 476, 22, 60), xRadius: 11 * s, yRadius: 11 * s).fill()
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: R(ex - 30, 512, 18, 18)).fill()
    }

    // Nose
    let nose = NSBezierPath()
    nose.move(to: P(cx - 26, 430)); nose.line(to: P(cx + 26, 430))
    nose.curve(to: P(cx, 396), controlPoint1: P(cx + 26, 400), controlPoint2: P(cx + 8, 396))
    nose.curve(to: P(cx - 26, 430), controlPoint1: P(cx - 8, 396), controlPoint2: P(cx - 26, 400))
    pink.setFill(); nose.fill()

    // Mouth "ω"
    let mouth = NSBezierPath()
    mouth.move(to: P(cx - 46, 392))
    mouth.curve(to: P(cx, 392), controlPoint1: P(cx - 40, 352), controlPoint2: P(cx - 6, 352))
    mouth.curve(to: P(cx + 46, 392), controlPoint1: P(cx + 6, 352), controlPoint2: P(cx + 40, 352))
    mouth.lineWidth = 11 * s; mouth.lineCapStyle = .round
    furLight.setStroke(); mouth.stroke()

    // Whiskers
    let wh = NSBezierPath()
    for side in [CGFloat(-1), 1] {
        let x0 = cx + side * 150, x1 = cx + side * 330
        wh.move(to: P(x0, 445)); wh.line(to: P(x1, 480))
        wh.move(to: P(x0, 428)); wh.line(to: P(x1, 424))
        wh.move(to: P(x0, 411)); wh.line(to: P(x1, 368))
    }
    wh.lineWidth = 7 * s; wh.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.45).setStroke(); wh.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    if let data = render(pixels: px) {
        try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    }
}
print("wrote \(sizes.count) icon sizes to \(outDir)")
