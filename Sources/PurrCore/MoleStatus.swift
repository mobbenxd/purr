import Foundation

/// One snapshot from `mo status --json` / `--watch`. Every field is optional so
/// a Mole update that renames or drops something degrades instead of failing.
public struct MoleStatus: Decodable, Equatable, Sendable {
    public struct CPU: Decodable, Equatable, Sendable {
        public var usage: Double?
        public var load1: Double?
    }

    public struct Memory: Decodable, Equatable, Sendable {
        public var used: Int64?
        public var total: Int64?
        public var usedPercent: Double?
        public var swapUsed: Int64?
        public var swapTotal: Int64?
    }

    public struct Disk: Decodable, Equatable, Sendable {
        public var mount: String?
        public var used: Int64?
        public var total: Int64?
        public var usedPercent: Double?
        public var external: Bool?
        public var purgeable: Int64?

        public var free: Int64? {
            guard let used, let total else { return nil }
            return max(0, total - used)
        }
    }

    public struct Battery: Decodable, Equatable, Sendable {
        public var percent: Double?
        public var status: String?
        public var health: String?
        public var cycleCount: Int?
        public var capacity: Double?
    }

    public struct Thermal: Decodable, Equatable, Sendable {
        public var cpuTemp: Double?
        public var batteryTemp: Double?
    }

    public struct Process: Decodable, Equatable, Sendable, Identifiable {
        public var pid: Int
        public var name: String?
        public var cpu: Double?
        public var memoryBytes: Int64?
        public var id: Int { pid }
    }

    public struct ProcessAlert: Decodable, Equatable, Sendable {
        public var pid: Int
        public var name: String?
        public var cpu: Double?
        public var threshold: Double?
        public var window: String?
        public var status: String?
    }

    public var healthScore: Int?
    public var healthScoreMsg: String?
    public var uptime: String?
    public var cpu: CPU?
    public var memory: Memory?
    public var disks: [Disk]?
    public var batteries: [Battery]?
    public var thermal: Thermal?
    public var trashSize: Int64?
    public var topProcesses: [Process]?
    public var processAlerts: [ProcessAlert]?

    public var rootDisk: Disk? {
        disks?.first { $0.mount == "/" } ?? disks?.first { $0.external != true }
    }

    public var battery: Battery? { batteries?.first }

    public static func decode(_ data: Data) throws -> MoleStatus {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MoleStatus.self, from: data)
    }
}
