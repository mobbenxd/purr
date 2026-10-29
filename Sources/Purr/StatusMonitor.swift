import Foundation
import PurrCore

/// Streams `mo status --watch` (fast while the panel is open, slow while it is
/// closed) and falls back to reading the kernel directly when Mole is missing.
@MainActor
final class StatusMonitor: ObservableObject {
    @Published private(set) var status: MoleStatus?
    @Published private(set) var cpu: Double = 0
    @Published private(set) var memory: Double = 0
    @Published private(set) var diskFree: Int64 = 0
    @Published private(set) var diskTotal: Int64 = 0

    /// Called for every Mole snapshot, e.g. to raise notifications.
    var onSnapshot: ((MoleStatus) -> Void)?

    private var moPath: String?
    private var visible = false
    private var stream: GroupProcess?
    /// Bumped on every restart so callbacks from an old stream are ignored.
    private var generation = 0
    private var pending = Data()
    private var fallbackTimer: Timer?
    private var retryTask: Task<Void, Never>?
    private var stats = SystemStats()

    var diskUsed: Double {
        diskTotal > 0 ? Double(diskTotal - diskFree) / Double(diskTotal) * 100 : 0
    }

    var health: Int {
        status?.healthScore ?? HealthLevel.fallbackScore(cpu: cpu, memory: memory, diskUsed: diskUsed)
    }

    var level: HealthLevel { HealthLevel(score: health) }

    private var interval: Int { visible ? 3 : 60 }

    func start(moPath: String?) {
        guard moPath != self.moPath || (stream == nil && fallbackTimer == nil) else { return }
        self.moPath = moPath
        restart()
    }

    func setVisible(_ visible: Bool) {
        guard visible != self.visible else { return }
        self.visible = visible
        restart()
    }

    func stop() {
        retryTask?.cancel()
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        generation += 1
        stream?.terminate(grace: 1)
        stream = nil
    }

    private func restart() {
        stop()
        guard let mo = moPath else { return startFallback() }

        let process = GroupProcess(executable: mo, arguments: ["status", "--watch", "--interval", "\(interval)s"],
                                   environment: MoleCLI.environment)
        process.lowPriority = !visible
        let current = generation
        process.onOutput = { [weak self] data in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.receive(data)
            }
        }
        process.onExit = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.streamDied()
            }
        }
        pending = Data()
        stream = process
        do {
            try process.start()
        } catch {
            streamDied()
        }
    }

    private func receive(_ data: Data) {
        pending.append(data)
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            let line = pending[pending.startIndex..<newline]
            pending = Data(pending[pending.index(after: newline)...])
            guard let snapshot = try? MoleStatus.decode(Data(line)) else { continue }
            apply(snapshot)
        }
    }

    private func apply(_ snapshot: MoleStatus) {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        status = snapshot
        if let usage = snapshot.cpu?.usage { cpu = usage }
        if let used = snapshot.memory?.usedPercent { memory = used }
        if let disk = snapshot.rootDisk, let free = disk.free, let total = disk.total {
            (diskFree, diskTotal) = (free, total)
        }
        onSnapshot?(snapshot)
    }

    /// Mole's stream stopped: read stats ourselves and try Mole again later.
    private func streamDied() {
        generation += 1
        stream = nil
        startFallback()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.restart()
        }
    }

    private func startFallback() {
        fallbackTimer?.invalidate()
        status = nil
        readFallback()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: visible ? 2 : 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.readFallback() }
        }
    }

    private func readFallback() {
        cpu = stats.cpuUsage()
        memory = stats.memoryUsage()
        (diskFree, diskTotal) = stats.disk()
    }
}
