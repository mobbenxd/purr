import Foundation

/// Where `mo` lives and how to call it non-interactively.
public enum MoleCLI {
    public static var candidates: [String] {
        ["/opt/homebrew/bin/mo", "/usr/local/bin/mo",
         NSHomeDirectory() + "/.local/bin/mo", "/run/current-system/sw/bin/mo"]
    }

    public static func find() -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Identifies the installed copy of `mo`: changes when Homebrew (or Mole's
    /// own installer) replaces it, even though `mo` keeps the same path.
    /// `nil` while nothing is there, e.g. halfway through an upgrade.
    public static func installStamp(_ mo: String) -> String? {
        let real = URL(fileURLWithPath: mo).resolvingSymlinksInPath().path
        guard let modified = (try? FileManager.default.attributesOfItem(atPath: real))?[.modificationDate] as? Date else {
            return nil
        }
        return "\(real)@\(modified.timeIntervalSince1970)"
    }

    public static var shellPath: String {
        "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    /// Plain output: no colours, no spinners that redraw the line.
    public static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = shellPath
        env["NO_COLOR"] = "1"
        env["TERM"] = "dumb"
        return env
    }

    public static func run(_ mo: String, _ args: [String], lowPriority: Bool = false,
                           timeout: TimeInterval = 600) async throws -> (status: Int32, output: Data) {
        try await GroupProcess.capture(mo, args, environment: environment, lowPriority: lowPriority, timeout: timeout)
    }

    public static func version(_ mo: String) async -> SemanticVersion? {
        guard let result = try? await run(mo, ["--version"], timeout: 15) else { return nil }
        return SemanticVersion(String(decoding: result.output, as: UTF8.self))
    }

    public static func history(_ mo: String) async -> MoleHistory? {
        guard let result = try? await run(mo, ["history", "--json"], timeout: 30) else { return nil }
        return try? MoleHistory.decode(result.output)
    }
}
