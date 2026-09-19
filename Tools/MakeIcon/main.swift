import AppKit
import SwiftUI

// Renders Toki from the app's own SwiftUI drawing into an .iconset folder.
// Usage: MakeIcon <output.iconset>
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

struct IconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(Color(red: 0.99, green: 0.95, blue: 0.89))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
            BuddyFace(kind: .fluffyCat, mood: .neutral)
                .scaleEffect(6.3)
                .offset(y: 6)
        }
        .frame(width: 1024, height: 1024)
    }
}

let host = NSHostingView(rootView: IconView())
host.appearance = NSAppearance(named: .aqua)
host.frame = NSRect(x: 0, y: 0, width: 1024, height: 1024)
let win = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
win.backgroundColor = .clear
win.isOpaque = false
win.contentView = host
win.orderFront(nil)
RunLoop.main.run(until: Date().addingTimeInterval(0.3))
host.layoutSubtreeIfNeeded()

let master = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
host.cacheDisplay(in: host.bounds, to: master)
let masterImage = NSImage(size: NSSize(width: 1024, height: 1024))
masterImage.addRepresentation(master)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    ctx.cgContext.clear(CGRect(x: 0, y: 0, width: px, height: px))
    masterImage.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
win.orderOut(nil)
print("wrote \(sizes.count) icon sizes to \(outDir)")
