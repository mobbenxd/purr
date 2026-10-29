import Foundation

public enum HealthLevel: Sendable {
    case good, fair, poor

    public init(score: Int) {
        switch score {
        case 80...: self = .good
        case 60..<80: self = .fair
        default: self = .poor
        }
    }

    /// Rough 0–100 score used when Mole's own `health_score` is unavailable:
    /// lower load and more free disk keep the cat happy.
    public static func fallbackScore(cpu: Double, memory: Double, diskUsed: Double) -> Int {
        let penalty = max(0, cpu - 50) * 0.4 + max(0, memory - 60) * 0.5 + max(0, diskUsed - 75) * 1.2
        return max(0, min(100, Int(100 - penalty)))
    }
}

/// Something worth a notification, keyed so it is not repeated too often.
public struct HealthAlert: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case lowDisk, memoryPressure, runawayProcess
    }

    public var kind: Kind
    /// Throttle key; process alerts include the pid so each process is reported once.
    public var key: String
    public var bytes: Int64 = 0
    public var percent: Double = 0
    public var name: String = ""
}

public struct AlertRules: Sendable {
    public var lowDisk = true
    public var lowDiskBytes: Int64 = 10_000_000_000
    public var memoryPressure = true
    public var memoryPercent: Double = 90
    public var swapBytes: Int64 = 4_000_000_000
    public var runawayProcess = true

    public init() {}

    public func evaluate(_ status: MoleStatus) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        if lowDisk, let free = status.rootDisk?.free, free < lowDiskBytes {
            alerts.append(HealthAlert(kind: .lowDisk, key: "lowDisk", bytes: free))
        }
        if memoryPressure, let mem = status.memory, let used = mem.usedPercent,
           used >= memoryPercent, (mem.swapUsed ?? 0) >= swapBytes {
            alerts.append(HealthAlert(kind: .memoryPressure, key: "memory", bytes: mem.swapUsed ?? 0, percent: used))
        }
        if runawayProcess {
            for alert in status.processAlerts ?? [] where alert.status != "resolved" {
                alerts.append(HealthAlert(kind: .runawayProcess, key: "process:\(alert.pid)",
                                          percent: alert.cpu ?? 0, name: alert.name ?? "pid \(alert.pid)"))
            }
        }
        return alerts
    }
}

/// Remembers when each alert last fired so notifications stay rare.
public struct AlertThrottle: Sendable {
    public var lastFired: [String: Date]
    public var cooldown: TimeInterval

    public init(lastFired: [String: Date] = [:], cooldown: TimeInterval = 6 * 3600) {
        self.lastFired = lastFired
        self.cooldown = cooldown
    }

    public mutating func shouldFire(_ key: String, now: Date = Date()) -> Bool {
        if let last = lastFired[key], now.timeIntervalSince(last) < cooldown { return false }
        lastFired[key] = now
        // Forget stale entries so per-process keys do not pile up.
        lastFired = lastFired.filter { now.timeIntervalSince($0.value) < cooldown * 4 }
        return true
    }
}
