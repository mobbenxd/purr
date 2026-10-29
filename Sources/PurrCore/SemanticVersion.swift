import Foundation

/// `major.minor.patch`, parsed leniently from tags like `v1.2.0`, `V1.65.0`
/// or `Mole version 1.55.0`. Pre-release suffixes are ignored.
public struct SemanticVersion: Comparable, Hashable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(_ major: Int, _ minor: Int = 0, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ text: String) {
        guard let range = text.range(of: #"\d+(\.\d+){0,2}"#, options: .regularExpression) else { return nil }
        let parts = text[range].split(separator: ".").compactMap { Int($0) }
        guard let major = parts.first else { return nil }
        self.init(major, parts.count > 1 ? parts[1] : 0, parts.count > 2 ? parts[2] : 0)
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (a: Self, b: Self) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }
}

/// The subset of GitHub's "latest release" payload Purr needs.
public struct GitHubRelease: Decodable, Equatable, Sendable {
    public struct Asset: Decodable, Equatable, Sendable {
        public let name: String
        public let browserDownloadUrl: URL
    }

    public let tagName: String
    public let htmlUrl: URL
    public let name: String?
    public let body: String?
    public let assets: [Asset]

    public var version: SemanticVersion? { SemanticVersion(tagName) }

    /// The packaged app, if the release has one.
    public var zipAsset: Asset? { assets.first { $0.name.hasSuffix(".zip") } }

    public static func decode(_ data: Data) throws -> GitHubRelease {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    /// Whether this release should be offered to someone running `current`.
    public func isNewer(than current: SemanticVersion, skipping skipped: String? = nil) -> Bool {
        guard let version, version > current else { return false }
        return skipped.flatMap(SemanticVersion.init) != version
    }
}

extension GitHubRelease {
    /// The first few readable lines of the release notes: Markdown headings,
    /// HTML tags, images and emphasis markers removed.
    public func notesPreview(maxLines: Int = 3) -> String {
        let text = (body ?? "").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return text.components(separatedBy: .newlines)
            .map { line -> String in
                var l = line.trimmingCharacters(in: .whitespaces)
                l = l.replacingOccurrences(of: #"!\[[^\]]*\]\([^)]*\)"#, with: "", options: .regularExpression)
                l = l.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
                l = l.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
                l = l.replacingOccurrences(of: #"^[-*]\s+"#, with: "• ", options: .regularExpression)
                return l.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty && $0 != "---" }
            .prefix(maxLines)
            .joined(separator: "\n")
    }
}
