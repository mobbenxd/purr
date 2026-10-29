import Foundation

/// Pulls the summary numbers out of Mole's human-readable output.
public enum OutputParser {
    public struct Estimate: Equatable, Sendable {
        public var bytes: Int64
        public var items: Int?
    }

    /// `Potential space: 70.5MB | Items: 16` (clean) or
    /// `Would free approximately: 375.9MB | Items: 9` (purge).
    public static func estimate(in text: String) -> Estimate? {
        let pattern = #"(?:Potential space|Would free approximately):\s*([0-9.]+\s*[KMGT]?B)(?:\s*\|\s*Items:\s*(\d+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              let sizeRange = Range(match.range(at: 1), in: text),
              let bytes = ByteSize.parse(String(text[sizeRange])) else { return nil }
        let items = Range(match.range(at: 2), in: text).flatMap { Int(text[$0]) }
        return Estimate(bytes: bytes, items: items)
    }

    /// Last few lines that look like a result, for commands without numbers.
    public static func resultLines(in text: String, limit: Int = 3) -> [String] {
        let keys = ["Potential space", "Would free", "Tracked cleanup", "Free space", "complete", "Nothing to"]
        return text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in keys.contains { line.contains($0) } }
            .suffix(limit)
    }

    public enum UpdateResult: Equatable {
        case updated(String)
        case alreadyLatest(String)
    }

    /// What `mo update` reported, from its last "Updated to …" or
    /// "Already on latest version, …" line.
    public static func updateResult(in text: String) -> UpdateResult? {
        for line in text.split(separator: "\n").reversed() {
            guard let comma = line.lastIndex(of: ",") else { continue }
            let version = line[line.index(after: comma)...].trimmingCharacters(in: .whitespaces)
            if line.contains("Already on latest version") { return .alreadyLatest(version) }
            if line.contains("Updated to") { return .updated(version) }
        }
        return nil
    }
}
