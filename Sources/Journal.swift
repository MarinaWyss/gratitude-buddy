import Foundation

struct JournalEntry {
    let date: Date
    let feelings: [String]
    let gratitude: String

    var isEmpty: Bool { feelings.isEmpty && gratitude.isEmpty }
}

/// Appends check-ins to a plain Markdown file so the record is yours and readable anywhere.
enum Journal {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Gratitude Buddy", isDirectory: true)
    }

    static var url: URL { directory.appendingPathComponent("journal.md") }

    static func ensureExists() {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path) {
            let header = "# Check-ins\n\nOne entry per check-in. Feelings first, then anything you were grateful for.\n"
            try? header.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func append(_ entry: JournalEntry) {
        guard !entry.isEmpty else { return }
        ensureExists()

        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE d MMM yyyy, HH:mm"

        var block = "\n## \(fmt.string(from: entry.date))\n"
        if !entry.feelings.isEmpty {
            block += "- Feeling: \(entry.feelings.joined(separator: ", "))\n"
        }
        if !entry.gratitude.isEmpty {
            block += "- Grateful for: \(entry.gratitude)\n"
        }

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(block.utf8))
        }
    }
}
