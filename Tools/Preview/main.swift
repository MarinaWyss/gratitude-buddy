import AppKit
import SwiftUI

// Renders the buddies and each step of the card to PNG so the design can be checked
// without waiting for a pop-up. Usage: render <output dir>
let out = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

func snapshot<V: View>(_ view: V, name: String, dark: Bool) {
    let host = NSHostingView(rootView: view)
    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    let size = host.fittingSize
    host.frame = NSRect(origin: .zero, size: size)
    let win = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    win.backgroundColor = dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.93, alpha: 1)
    win.contentView = host
    win.orderFront(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    let img = NSImage(size: size)
    img.lockFocus()
    win.backgroundColor.setFill(); NSRect(origin: .zero, size: size).fill()
    rep.draw(in: NSRect(origin: .zero, size: size))
    img.unlockFocus()
    let final = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try? final.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
    win.orderOut(nil)
    print("wrote \(name) \(Int(size.width))x\(Int(size.height))")
}

struct BuddySheet: View {
    var body: some View {
        VStack(spacing: 6) {
            ForEach(BuddyKind.allCases, id: \.rawValue) { kind in
                HStack(spacing: 10) {
                    BuddyFace(kind: kind, mood: .neutral)
                    BuddyFace(kind: kind, mood: .attentive)
                    BuddyFace(kind: kind, mood: .happy)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .windowBackgroundColor)))
            }
        }
        .padding(12)
    }
}

snapshot(BuddySheet(), name: "0-buddies-light", dark: false)

let intro = CheckInModel(isIntro: true, kind: .fluffyCat)
snapshot(BuddyView(model: intro), name: "1-intro", dark: false)

let m = CheckInModel(isIntro: false, kind: .sleekCat)
snapshot(BuddyView(model: m), name: "2-greeting", dark: false)
m.step = .feelings; m.selected = ["calm", "tired"]
snapshot(BuddyView(model: m), name: "3-feelings", dark: false)
let mr = CheckInModel(isIntro: false, kind: .sleekCat, reflection: CheckInModel.reflections[0])
mr.step = .feelings; mr.selected = ["calm"]
snapshot(BuddyView(model: mr), name: "3b-feelings-reflection", dark: false)

let g = CheckInModel(isIntro: false, kind: .goldenRetriever)
g.step = .gratitude; g.gratitude = "the light coming through the window"
snapshot(BuddyView(model: g), name: "4-gratitude", dark: false)
g.step = .done
snapshot(BuddyView(model: g), name: "5-done", dark: false)

let meet = CheckInModel(isIntro: false, kind: .fluffyCat, meet: true)
snapshot(BuddyView(model: meet), name: "6-meet", dark: false)

for (i, line) in CheckInModel.reminders.enumerated() {
    let r = CheckInModel(isIntro: false, kind: BuddyKind.allCases[i % BuddyKind.allCases.count], reminder: line)
    snapshot(BuddyView(model: r), name: "7-reminder-\(i + 1)", dark: false)
}
