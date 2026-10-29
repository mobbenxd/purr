import Foundation

/// `mo history --json`.
public struct MoleHistory: Decodable, Sendable {
    public struct Actions: Decodable, Equatable, Sendable {
        public var removed: Int = 0
        public var trashed: Int = 0
        public var skipped: Int = 0
        public var failed: Int = 0
    }

    public struct Session: Decodable, Equatable, Sendable, Identifiable {
        public var command: String
        public var startedAt: String
        public var endedAt: String?
        public var items: Int?
        public var size: String?
        public var actions: Actions?

        public var id: String { command + startedAt }
        public var startedDate: Date? { MoleHistory.parseDate(startedAt) }
        public var sizeBytes: Int64 { size.flatMap(ByteSize.parse) ?? 0 }

        /// Mole records dry runs too; they never remove or trash anything.
        public var changedFiles: Bool {
            guard let actions else { return false }
            return actions.removed + actions.trashed > 0
        }
    }

    public struct Logs: Decodable, Sendable {
        public var operations: String?
        public var deletions: String?
    }

    public var sessions: [Session]
    public var logs: Logs?

    public static func decode(_ data: Data) throws -> MoleHistory {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MoleHistory.self, from: data)
    }

    /// The session for a run of `command` that began at or after `start`.
    public func session(for command: String, startedAfter start: Date) -> Session? {
        sessions
            .filter { $0.command == command && ($0.startedDate ?? .distantPast) >= start.addingTimeInterval(-2) }
            .max { ($0.startedDate ?? .distantPast) < ($1.startedDate ?? .distantPast) }
    }

    /// Total space freed by sessions that actually changed files.
    public var totalFreed: Int64 {
        sessions.filter(\.changedFiles).reduce(0) { $0 + $1.sizeBytes }
    }

    static func parseDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: text)
    }
}

public enum ByteSize {
    /// Parses Mole's sizes such as `1.64GB`, `375.9MB`, `475KB` or `0B`.
    public static func parse(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).uppercased()
        guard let range = trimmed.range(of: #"^[0-9.]+"#, options: .regularExpression),
              let number = Double(trimmed[range]) else { return nil }
        let unit = trimmed[range.upperBound...].trimmingCharacters(in: .whitespaces)
        let powers = ["B": 0.0, "": 0, "KB": 1, "K": 1, "MB": 2, "M": 2, "GB": 3, "G": 3, "TB": 4, "T": 4]
        guard let power = powers[unit] else { return nil }
        return Int64(number * pow(1000, power))
    }
}
