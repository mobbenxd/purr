import Foundation
import Testing
@testable import PurrCore

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct StatusTests {
    @Test func decodesSnapshot() throws {
        let status = try MoleStatus.decode(fixture("status.json"))
        #expect(status.healthScore == 84)
        #expect(status.memory?.swapUsed == 10_674_372_608)
        #expect(status.rootDisk?.free == Int64(18_355_941_215))
        #expect(status.battery?.cycleCount == 169)
        #expect(status.topProcesses?.first?.name == "WindowServer")
        #expect(status.processAlerts?.first?.pid == 999)
    }

    @Test func toleratesMissingFields() throws {
        let status = try MoleStatus.decode(Data(#"{"cpu":{"usage":3}}"#.utf8))
        #expect(status.cpu?.usage == 3)
        #expect(status.healthScore == nil)
        #expect(status.rootDisk == nil)
    }
}

@Suite struct HistoryTests {
    @Test func decodesSessions() throws {
        let history = try MoleHistory.decode(fixture("history.json"))
        #expect(history.sessions.count == 4)
        #expect(history.sessions[0].sizeBytes == 375_900_000)
        #expect(history.sessions[1].changedFiles == false)
        #expect(history.sessions[2].changedFiles == true)
        #expect(history.totalFreed == 804_200_000 + 1_640_000_000)
    }

    @Test func findsSessionForRun() throws {
        let history = try MoleHistory.decode(fixture("history.json"))
        let start = try #require(MoleHistory.parseDate("2026-10-29 17:44:00"))
        #expect(history.session(for: "clean", startedAfter: start)?.startedAt == "2026-10-29 17:47:45")
        #expect(history.session(for: "optimize", startedAfter: start) == nil)
    }

    @Test(arguments: [("1.64GB", 1_640_000_000), ("375.9MB", 375_900_000), ("475KB", 475_000), ("0B", 0), ("12 GB", 12_000_000_000)] as [(String, Int64)])
    func parsesByteSizes(text: String, bytes: Int64) {
        #expect(ByteSize.parse(text) == bytes)
    }

    @Test func rejectsGarbageSize() {
        #expect(ByteSize.parse("lots") == nil)
        #expect(ByteSize.parse("3 parsecs") == nil)
    }
}

@Suite struct OutputTests {
    @Test func cleanEstimate() throws {
        let text = String(decoding: try fixture("clean-dryrun.txt"), as: UTF8.self)
        #expect(OutputParser.estimate(in: text) == .init(bytes: 70_500_000, items: 16))
    }

    @Test func purgeEstimate() throws {
        let text = String(decoding: try fixture("purge-dryrun.txt"), as: UTF8.self)
        #expect(OutputParser.estimate(in: text) == .init(bytes: 375_900_000, items: 9))
    }

    @Test func noEstimate() {
        #expect(OutputParser.estimate(in: "Optimization complete") == nil)
        #expect(OutputParser.resultLines(in: "a\n  Optimization complete  \nb") == ["Optimization complete"])
    }
}

@Suite struct LogBufferTests {
    @Test func stripsAnsiAndJoinsChunks() {
        var log = LogBuffer()
        log.append("\u{1B}[32mhel")
        log.append("lo\u{1B}[0m\nwor")
        log.append("ld\n")
        #expect(log.lines == ["hello", "world"])
    }

    @Test func collapsesSpinnerFrames() {
        var log = LogBuffer()
        log.append("⠋ scanning\r⠙ scan")
        log.append("ning\r✓ done\n")
        #expect(log.text == "✓ done")
        log.append("⠋ next\r")
        #expect(log.text == "✓ done\n⠋ next")
    }

    @Test func keepsOnlyTail() {
        var log = LogBuffer(maxLines: 3)
        for i in 1...5 { log.append("\(i)\n") }
        #expect(log.lines == ["3", "4", "5"])
    }

    @Test func resetWithHeader() {
        var log = LogBuffer()
        log.append("old\n")
        log.reset("$ mo clean")
        #expect(log.text == "$ mo clean")
    }
}
