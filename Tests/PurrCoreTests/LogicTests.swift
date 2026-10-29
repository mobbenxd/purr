import Darwin
import Foundation
import Testing
@testable import PurrCore

@Suite struct VersionTests {
    @Test(arguments: [("v1.2.3", "1.2.3"), ("V1.65.0", "1.65.0"), ("Mole version 1.55.0\nmacOS: 26.5", "1.55.0"), ("2", "2.0.0"), ("1.4-beta", "1.4.0")])
    func parses(text: String, expected: String) {
        #expect(SemanticVersion(text)?.description == expected)
    }

    @Test func hugeNumberIsNotAVersion() {
        #expect(SemanticVersion("v99999999999999999999999") == nil)
    }

    @Test func ordering() {
        #expect(SemanticVersion(1, 9, 9) < SemanticVersion(1, 10, 0))
        #expect(SemanticVersion("not a version") == nil)
    }

    @Test func releaseIsNewer() throws {
        let json = #"{"tag_name":"v1.2.0","html_url":"https://github.com/o/r/releases/tag/v1.2.0","name":"Purr 1.2.0","body":"notes","assets":[{"name":"Purr-1.2.0.zip","browser_download_url":"https://example.com/Purr-1.2.0.zip"}]}"#
        let release = try GitHubRelease.decode(Data(json.utf8))
        #expect(release.isNewer(than: SemanticVersion(1, 1, 0)))
        #expect(!release.isNewer(than: SemanticVersion(1, 2, 0)))
        #expect(!release.isNewer(than: SemanticVersion(1, 1, 0), skipping: "1.2.0"))
        #expect(release.isNewer(than: SemanticVersion(1, 1, 0), skipping: "1.1.5"))
        #expect(release.zipAsset?.name == "Purr-1.2.0.zip")
    }
}

@Suite struct ReleaseNotesTests {
    @Test func previewStripsMarkup() throws {
        let body = "<div align=\"center\">\n<img src=\"x.png\"/>\n</div>\n\n### Added\n- **New** [history](https://x) page\n- `mo purge` button\n\n---\n- third"
        let json = try JSONSerialization.data(withJSONObject: ["tag_name": "v1", "html_url": "https://x", "body": body, "assets": []])
        let release = try GitHubRelease.decode(json)
        #expect(release.notesPreview() == "Added\n• New history page\n• mo purge button")
    }
}

@Suite struct HealthTests {
    @Test func levels() {
        #expect(HealthLevel(score: 95) == .good)
        #expect(HealthLevel(score: 70) == .fair)
        #expect(HealthLevel(score: 10) == .poor)
        #expect(HealthLevel.fallbackScore(cpu: 10, memory: 40, diskUsed: 50) == 100)
        #expect(HealthLevel.fallbackScore(cpu: 100, memory: 100, diskUsed: 100) == 30)
    }

    @Test func alertsFromSnapshot() throws {
        var status = MoleStatus()
        status.disks = [.init(mount: "/", used: 240_000_000_000, total: 245_000_000_000)]
        status.memory = .init(usedPercent: 95, swapUsed: 6_000_000_000)
        status.processAlerts = [.init(pid: 42, name: "hog", cpu: 150, status: "active"),
                                .init(pid: 43, name: "ok", cpu: 10, status: "resolved")]
        let alerts = AlertRules().evaluate(status)
        #expect(alerts.map(\.key) == ["lowDisk", "memory", "process:42"])
        #expect(alerts[0].bytes == 5_000_000_000)

        var quiet = AlertRules()
        quiet.lowDisk = false
        quiet.memoryPressure = false
        quiet.runawayProcess = false
        #expect(quiet.evaluate(status).isEmpty)
    }

    @Test func noMemoryAlertWithoutSwap() {
        var status = MoleStatus()
        status.memory = .init(usedPercent: 95, swapUsed: 0)
        #expect(AlertRules().evaluate(status).isEmpty)
    }

    @Test func throttle() {
        var throttle = AlertThrottle(cooldown: 60)
        let t0 = Date(timeIntervalSince1970: 1_000)
        let fired = [
            throttle.shouldFire("a", now: t0),
            throttle.shouldFire("a", now: t0.addingTimeInterval(30)),
            throttle.shouldFire("b", now: t0.addingTimeInterval(30)),
            throttle.shouldFire("a", now: t0.addingTimeInterval(61)),
        ]
        #expect(fired == [true, false, true, true])
    }
}

@Suite struct GroupProcessTests {
    @Test func capturesOutputAndStatus() async throws {
        let result = try await GroupProcess.capture("/bin/sh", ["-c", "echo hi; echo err >&2; exit 3"])
        #expect(result.status == 3)
        #expect(String(decoding: result.output, as: UTF8.self) == "hi\nerr\n")
    }

    @Test func terminateKillsChildren() async throws {
        // The shell starts a background child that would outlive a plain SIGTERM to the shell.
        let process = GroupProcess(executable: "/bin/sh", arguments: ["-c", "sleep 30 & echo $!; wait"])
        let childPid = PidBox()
        let exited = ExitBox()
        process.onOutput = { data in
            if let pid = Int32(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) {
                childPid.value = pid
            }
        }
        process.onExit = { exited.value = $0 }
        try process.start()

        for _ in 0..<50 where childPid.value == 0 { try await Task.sleep(for: .milliseconds(20)) }
        let child = childPid.value
        #expect(child > 0)
        process.terminate(grace: 0.5)

        for _ in 0..<150 where exited.value == nil { try await Task.sleep(for: .milliseconds(20)) }
        #expect(exited.value != nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(kill(child, 0) == -1, "background child should be gone")
    }

    @Test func childGetsDefaultSignalsEvenIfParentIgnoresThem() async throws {
        // The app ignores SIGTERM for itself; `mo` must still be able to
        // trap it and clean up when the user presses Stop.
        let previous = signal(SIGTERM, SIG_IGN)
        defer { signal(SIGTERM, previous) }
        let process = GroupProcess(executable: "/bin/sh",
                                   arguments: ["-c", "trap 'echo cleaned; exit 7' TERM; echo ready; while :; do sleep 0.1; done"])
        let output = TextBox()
        let exited = ExitBox()
        process.onOutput = { output.append(String(decoding: $0, as: UTF8.self)) }
        process.onExit = { exited.value = $0 }
        try process.start()
        for _ in 0..<100 where !output.text.contains("ready") { try await Task.sleep(for: .milliseconds(20)) }
        process.terminate(grace: 5)
        for _ in 0..<150 where exited.value == nil { try await Task.sleep(for: .milliseconds(20)) }
        #expect(output.text.contains("cleaned"))
        #expect(exited.value == 7)
    }

    @Test func terminateAfterExitIsHarmless() async throws {
        let process = GroupProcess(executable: "/bin/sh", arguments: ["-c", "exit 0"])
        let exited = ExitBox()
        process.onExit = { exited.value = $0 }
        try process.start()
        for _ in 0..<100 where exited.value == nil { try await Task.sleep(for: .milliseconds(20)) }
        #expect(exited.value == 0)
        #expect(!process.isRunning)
        process.terminate(grace: 0)  // must not signal a reused process group
    }

    private final class TextBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value = ""
        func append(_ s: String) { lock.withLock { value += s } }
        var text: String { lock.withLock { value } }
    }

    private final class PidBox: @unchecked Sendable { var value: Int32 = 0 }
    private final class ExitBox: @unchecked Sendable { var value: Int32? }
}
