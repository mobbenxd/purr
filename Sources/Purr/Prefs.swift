import Foundation
import PurrCore

/// UserDefaults keys. Views bind with `@AppStorage(Prefs.x)`; services read
/// through the helpers below so both agree on defaults.
enum Prefs {
    static let notifyLowDisk = "notifyLowDisk"
    static let lowDiskGB = "lowDiskGB"
    static let notifyMemory = "notifyMemory"
    static let notifyProcess = "notifyProcess"
    static let notifyTaskDone = "notifyTaskDone"
    static let weeklySniff = "weeklySniff"
    static let sniffNotifyMB = "sniffNotifyMB"
    static let checkUpdates = "checkUpdates"
    static let purrSound = "purrSound"
    static let moodIcon = "moodIcon"
    static let language = "language"
    static let skippedVersion = "skippedVersion"

    // Internal state
    static let lastSniff = "lastSniff"
    static let lastSniffBytes = "lastSniffBytes"
    static let lastSniffAttempt = "lastSniffAttempt"
    static let lastUpdateCheck = "lastUpdateCheck"
    static let notifiedVersion = "notifiedVersion"
    static let alertTimes = "alertTimes"
    static let moleJustUpdated = "moleJustUpdated"
    static let purrJustUpdated = "purrJustUpdated"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            notifyLowDisk: true,
            lowDiskGB: 10,
            notifyMemory: true,
            notifyProcess: true,
            notifyTaskDone: true,
            weeklySniff: true,
            sniffNotifyMB: 1024,
            checkUpdates: true,
            purrSound: true,
            moodIcon: true,
            language: Language.thai.rawValue,
        ])
    }

    static var alertRules: AlertRules {
        let d = UserDefaults.standard
        var rules = AlertRules()
        rules.lowDisk = d.bool(forKey: notifyLowDisk)
        rules.lowDiskBytes = Int64(d.integer(forKey: lowDiskGB)) * 1_000_000_000
        rules.memoryPressure = d.bool(forKey: notifyMemory)
        rules.runawayProcess = d.bool(forKey: notifyProcess)
        return rules
    }
}

enum Language: String, CaseIterable, Identifiable {
    case thai = "th", english = "en", system

    var id: String { rawValue }

    /// Applied at launch, before any localized string is looked up.
    static func applySaved() {
        let d = UserDefaults.standard
        let saved = Language(rawValue: d.string(forKey: Prefs.language) ?? "") ?? .thai
        if saved == .system {
            d.removeObject(forKey: "AppleLanguages")
        } else {
            d.set([saved.rawValue], forKey: "AppleLanguages")
        }
    }
}

extension Int64 {
    var bytesText: String { ByteCountFormatter.string(fromByteCount: self, countStyle: .file) }
}
