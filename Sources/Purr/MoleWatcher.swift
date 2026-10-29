import AppKit
import Foundation
import PurrCore

/// Notices when Mole is upgraded underneath Purr (`mo update` in Terminal,
/// or `brew upgrade` by hand) and relaunches Purr, so the status stream,
/// version banner and history all come from the new Mole.
@MainActor
final class MoleWatcher {
    /// Provided by the app: where `mo` is, and whether relaunching now would
    /// interrupt a task.
    var moPath: () -> String? = { nil }
    var isBusy: () -> Bool = { false }

    private var baseline: String?
    /// A new stamp is only trusted once it is seen twice in a row: Homebrew
    /// links the new version and removes the old one in separate steps.
    private var candidate: String?
    private var timer: Timer?
    private var fastUntil: Date?

    private var interval: TimeInterval { (fastUntil ?? .distantPast) > Date() ? 3 : 60 }

    func start() {
        baseline = moPath().flatMap(MoleCLI.installStamp)
        schedule()
        announceUpdateIfRelaunched()
    }

    /// Mole's updater was just opened in Terminal: look often for a while.
    func watchUpdate() {
        fastUntil = Date().addingTimeInterval(30 * 60)
        schedule()
    }

    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        defer { schedule() }
        guard let stamp = moPath().flatMap(MoleCLI.installStamp) else { return }
        guard let baseline else { self.baseline = stamp; return }  // Mole was just installed
        guard stamp != baseline else { candidate = nil; return }
        guard stamp == candidate else { candidate = stamp; return }
        guard !isBusy() else { return }  // try again after the task
        relaunch()
    }

    private func relaunch() {
        let bundle = Bundle.main.bundlePath
        // `swift run` builds have nothing to reopen; just start following the new Mole.
        guard bundle.hasSuffix(".app") else { baseline = candidate; return }
        UserDefaults.standard.set(true, forKey: Prefs.moleJustUpdated)
        // Waits for this process to exit, then opens the app again.
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        reopen.arguments = ["-c", "while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", bundle]
        do {
            try reopen.run()
            NSApp.terminate(nil)
        } catch {
            UserDefaults.standard.removeObject(forKey: Prefs.moleJustUpdated)
            baseline = candidate
        }
    }

    private func announceUpdateIfRelaunched() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Prefs.moleJustUpdated) else { return }
        defaults.removeObject(forKey: Prefs.moleJustUpdated)
        guard let mo = moPath() else { return }
        Task {
            let version = await MoleCLI.version(mo).map { "v\($0.description)" } ?? ""
            Notifier.shared.post(id: "mole-updated", title: String(localized: "อัปเดต Mole แล้ว 🐾"),
                                 body: String(localized: "Purr เปิดใหม่ให้แล้ว ตอนนี้ใช้ Mole \(version)"))
        }
    }
}
