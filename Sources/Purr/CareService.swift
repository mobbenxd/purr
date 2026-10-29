import Foundation
import PurrCore

/// The cat looking after the Mac on its own: health notifications from
/// Mole's snapshots, and a quiet weekly "ดมก่อน" (clean dry run).
@MainActor
final class CareService: ObservableObject {
    @Published private(set) var lastSniff: Date?
    @Published private(set) var lastSniffBytes: Int64?
    @Published private(set) var sniffing = false

    /// Provided by the app: whether a foreground task is running, and where `mo` is.
    var isBusy: () -> Bool = { false }
    var moPath: () -> String? = { nil }

    private var throttle: AlertThrottle
    private var timer: Timer?
    private var sniffTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    private static let sniffEvery: TimeInterval = 7 * 24 * 3600

    init() {
        let saved = defaults.dictionary(forKey: Prefs.alertTimes) as? [String: Date] ?? [:]
        throttle = AlertThrottle(lastFired: saved)
        lastSniff = defaults.object(forKey: Prefs.lastSniff) as? Date
        lastSniffBytes = (defaults.object(forKey: Prefs.lastSniffBytes) as? NSNumber)?.int64Value
        if lastSniff == nil {
            // First launch: wait about a day before the first background check.
            defaults.set(Date().addingTimeInterval(-Self.sniffEvery + 24 * 3600), forKey: Prefs.lastSniff)
        }
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sniffIfDue() }
        }
        Task {
            try? await Task.sleep(for: .seconds(120))
            sniffIfDue()
        }
    }

    // MARK: - Health alerts

    func handle(_ status: MoleStatus) {
        let alerts = Prefs.alertRules.evaluate(status)
        guard !alerts.isEmpty else { return }
        for alert in alerts where throttle.shouldFire(alert.key) {
            let (title, body) = Self.message(for: alert)
            Notifier.shared.post(id: alert.key, title: title, body: body)
        }
        defaults.set(throttle.lastFired, forKey: Prefs.alertTimes)
    }

    static func message(for alert: HealthAlert) -> (String, String) {
        switch alert.kind {
        case .lowDisk:
            return (String(localized: "ดิสก์ใกล้เต็มแล้ว 🙀"),
                    String(localized: "เหลือที่ว่างแค่ \(alert.bytes.bytesText) ลองกด \"ดมก่อน\" ดูว่าลบอะไรได้บ้าง"))
        case .memoryPressure:
            return (String(localized: "แรมตึงมาก 😿"),
                    String(localized: "ใช้แรม \(Int(alert.percent))% และ swap \(alert.bytes.bytesText) ลองปิดแอปที่ไม่ได้ใช้"))
        case .runawayProcess:
            return (String(localized: "\(alert.name) กิน CPU หนักมาก"),
                    String(localized: "ใช้ CPU \(Int(alert.percent))% ต่อเนื่องหลายนาทีแล้ว ถ้าไม่ได้ใช้อยู่ลองปิดดู"))
        }
    }

    // MARK: - Weekly sniff

    /// Called by the model when the user runs "ดมก่อน" themselves.
    func recordSniff(bytes: Int64) {
        lastSniff = Date()
        lastSniffBytes = bytes
        defaults.set(lastSniff, forKey: Prefs.lastSniff)
        defaults.set(NSNumber(value: bytes), forKey: Prefs.lastSniffBytes)
    }

    /// A foreground task is starting; Mole should not run twice at once.
    func cancelSniff() {
        sniffTask?.cancel()
    }

    func sniffIfDue() {
        guard defaults.bool(forKey: Prefs.weeklySniff), !sniffing, !isBusy(), let mo = moPath() else { return }
        // Failed attempts count too, so a broken run is not retried every hour.
        let last = [Prefs.lastSniff, Prefs.lastSniffAttempt].compactMap { defaults.object(forKey: $0) as? Date }.max() ?? .distantPast
        guard Date().timeIntervalSince(last) >= Self.sniffEvery else { return }
        defaults.set(Date(), forKey: Prefs.lastSniffAttempt)

        sniffing = true
        sniffTask = Task {
            defer { sniffing = false }
            guard let result = try? await MoleCLI.run(mo, ["clean", "--dry-run"], lowPriority: true, timeout: 900),
                  !Task.isCancelled,
                  let estimate = OutputParser.estimate(in: String(decoding: result.output, as: UTF8.self)) else { return }
            recordSniff(bytes: estimate.bytes)

            let minimum = Int64(defaults.integer(forKey: Prefs.sniffNotifyMB)) * 1_000_000
            if estimate.bytes >= minimum {
                Notifier.shared.post(id: "sniff", title: String(localized: "แมวดมเจอของให้ลบ 👃"),
                                     body: String(localized: "ลบแคชและล็อกได้ประมาณ \(estimate.bytes.bytesText) กด \"เลียขน\" ใน Purr เพื่อล้าง"))
            }
        }
    }
}
