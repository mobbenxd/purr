import Foundation

public enum AnsiCleaner {
    /// Strips ANSI escapes that Mole may still emit even with `NO_COLOR`.
    public static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r\n", with: "\n")
    }
}

/// Collects streamed output as lines, keeping only the tail. Spinner frames
/// (text followed by `\r`) are collapsed so only the last frame survives,
/// even when a frame is split across chunks.
public struct LogBuffer {
    public let maxLines: Int
    public private(set) var lines: [String] = []
    private var partial = ""

    public init(maxLines: Int = 2_000) {
        self.maxLines = maxLines
    }

    public var isEmpty: Bool { lines.isEmpty && partial.isEmpty }

    public var text: String {
        let tail = Self.lastFrame(partial)
        return tail.isEmpty ? lines.joined(separator: "\n") : (lines + [tail]).joined(separator: "\n")
    }

    public mutating func append(_ raw: String) {
        let pieces = (partial + AnsiCleaner.clean(raw)).components(separatedBy: "\n")
        partial = pieces.last ?? ""
        lines.append(contentsOf: pieces.dropLast().map(Self.lastFrame))
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
    }

    public mutating func reset(_ header: String = "") {
        lines = []
        partial = ""
        if !header.isEmpty { append(header + "\n") }
    }

    private static func lastFrame(_ line: String) -> String {
        guard let r = line.lastIndex(of: "\r") else { return line }
        let after = line[line.index(after: r)...]
        // A trailing \r means the frame is still being drawn; keep the previous one.
        if after.isEmpty, let prev = line[..<r].lastIndex(of: "\r") {
            return String(line[line.index(after: prev)..<r])
        }
        return after.isEmpty ? String(line[..<r]) : String(after)
    }
}
