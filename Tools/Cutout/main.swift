import AppKit
import Vision
import CoreImage

// cutout <maxPx> <out.png> <in.png>   lifts the subject, un-blends edge pixels from the white background,
//                                     trims to the subject and scales so the longest side is maxPx
// sheet <out.png> <in1.png> ...       tiles images onto a dark contact sheet
let args = CommandLine.arguments
let ctx = CIContext()

func cutout(_ inPath: String, _ outPath: String, maxPx: CGFloat, darkSubject: Bool) throws {
    guard let ci = CIImage(contentsOf: URL(fileURLWithPath: inPath)) else { fatalError("cannot read \(inPath)") }
    let handler = VNImageRequestHandler(ciImage: ci, options: [:])
    let req = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([req])
    guard let result = req.results?.first else { fatalError("no subject in \(inPath)") }
    let buf = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
    let masked = CIImage(cvPixelBuffer: buf)
    guard let cg = ctx.createCGImage(masked, from: masked.extent) else { fatalError("render failed") }

    // Pull pixels out as premultiplied RGBA (the only layout CGContext will draw into).
    let w = cg.width, h = cg.height
    let count = w * h * 4
    let px = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
    defer { px.deallocate() }
    px.initialize(repeating: 0, count: count)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    guard let bctx = CGContext(data: px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                               space: cs, bitmapInfo: info) else { fatalError("no bitmap context") }
    bctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

    // Erode the alpha a little so the white-blended fringe the mask called "opaque" becomes edge.
    let r = 2
    var alpha = [Double](repeating: 0, count: w * h)
    for i in 0..<(w * h) { alpha[i] = Double(px[i * 4 + 3]) / 255 }
    var eroded = alpha
    for y in 0..<h {
        for x in 0..<w {
            var m = alpha[y * w + x]
            if m == 0 { continue }
            for dy in -r...r {
                let yy = y + dy; if yy < 0 || yy >= h { m = 0; break }
                for dx in -r...r {
                    let xx = x + dx; if xx < 0 || xx >= w { m = 0; break }
                    m = min(m, alpha[yy * w + xx])
                }
                if m == 0 { break }
            }
            eroded[y * w + x] = m
        }
    }

    // Edge band: pixels within `band` px of transparency. Only there do we trust brightness.
    let band = 10
    var dist = [Int](repeating: band + 1, count: w * h)
    for i in 0..<(w * h) where alpha[i] < 0.02 { dist[i] = 0 }
    for _ in 0..<band {
        var next = dist
        for y in 0..<h { for x in 0..<w {
            let i = y * w + x
            if dist[i] <= band { continue }
            var best = dist[i]
            if x > 0 { best = min(best, dist[i - 1] + 1) }
            if x < w - 1 { best = min(best, dist[i + 1] + 1) }
            if y > 0 { best = min(best, dist[i - w] + 1) }
            if y < h - 1 { best = min(best, dist[i + w] + 1) }
            next[i] = best
        } }
        dist = next
    }

    for i in 0..<(w * h) {
        let o = i * 4
        let a = alpha[i]
        if a <= 0 { continue }
        var a2 = min(1, max(0, (eroded[i] - 0.10) / 0.90))
        var straight = [0.0, 0.0, 0.0]
        for c in 0..<3 { straight[c] = min(1, (Double(px[o + c]) / 255) / a) }
        if darkSubject && dist[i] <= band {
            // Dark fur blended with white: brightness tells us how much is white.
            let lum = 0.2126 * straight[0] + 0.7152 * straight[1] + 0.0722 * straight[2]
            let furMax = 0.42                                   // anything darker counts as solid fur
            let coverage = min(1, max(0, (1 - lum) / (1 - furMax)))
            a2 = min(a2, coverage)
        }
        if a2 <= 0.02 { px[o] = 0; px[o + 1] = 0; px[o + 2] = 0; px[o + 3] = 0; continue }
        for c in 0..<3 {
            let fg = (straight[c] - (1 - a2)) / a2               // undo the blend with white
            let v = min(1, max(0, fg))
            px[o + c] = UInt8((v * a2 * 255).rounded())          // re-premultiply for output
        }
        px[o + 3] = UInt8((a2 * 255).rounded())
    }

    var out = CIImage(cgImage: bctx.makeImage()!)
    let scale = min(1, maxPx / max(out.extent.width, out.extent.height))
    out = out.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let cgOut = ctx.createCGImage(out, from: out.extent) else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cgOut)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
    print("\(outPath): \(cgOut.width)x\(cgOut.height)")
}

func sheet(_ outPath: String, _ paths: [String]) throws {
    let cell: CGFloat = 300, cols = 3
    let rows = Int(ceil(Double(paths.count) / Double(cols)))
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(cell) * cols, pixelsHigh: Int(cell) * rows,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor(white: 0.12, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh).fill()
    for (i, p) in paths.enumerated() {
        guard let img = NSImage(contentsOfFile: p) else { continue }
        let col = i % cols, row = rows - 1 - i / cols
        let r = NSRect(x: CGFloat(col) * cell + 8, y: CGFloat(row) * cell + 8, width: cell - 16, height: cell - 16)
        let s = min(r.width / img.size.width, r.height / img.size.height)
        let sz = NSSize(width: img.size.width * s, height: img.size.height * s)
        img.draw(in: NSRect(x: r.midX - sz.width / 2, y: r.midY - sz.height / 2, width: sz.width, height: sz.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
}

switch args[1] {
case "cutout": try cutout(args[4], args[3], maxPx: CGFloat(Double(args[2])!), darkSubject: args.count > 5 && args[5] == "dark")
case "sheet": try sheet(args[2], Array(args[3...]))
default: fatalError("unknown command")
}
