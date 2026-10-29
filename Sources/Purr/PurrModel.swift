import AppKit
import Foundation
import PurrCore

/// One thing the cat can do. `inApp` tasks stream into the log;
/// the rest are interactive TUIs and open in Terminal.
struct CatTask: Identifiable, Equatable {
    let id: String
    let emoji: String
    let title: String
    let subtitle: String
    let args: [String]
    var inApp = true
    var confirm: String? = nil

    /// Dry runs only report what could be removed.
    var isPreview: Bool { args.contains("--dry-run") }

    static func == (a: Self, b: Self) -> Bool { a.id == b.id && a.args == b.args }
}

enum CatTasks {
    static let quick: [CatTask] = [
        CatTask(id: "sniff", emoji: "👃", title: String(localized: "ดมก่อน"), subtitle: String(localized: "ดูว่าลบอะไรได้บ้าง"),
                args: ["clean", "--dry-run"]),
        CatTask(id: "groom", emoji: "🧹", title: String(localized: "เลียขน"), subtitle: String(localized: "ล้างแคช/ล็อก"),
                args: ["clean"],
                confirm: String(localized: "แคช ล็อก และถังขยะจะถูกลบถาวร (ไม่ผ่าน Trash)\nแนะนำให้กด \"ดมก่อน\" เพื่อดูรายการก่อน")),
        CatTask(id: "stretch", emoji: "🧘", title: String(localized: "ยืดเส้น"), subtitle: String(localized: "Optimize ระบบ"),
                args: ["optimize"],
                confirm: String(localized: "รีเฟรช DNS, QuickLook, ไอคอน และฐานข้อมูลระบบ")),
        CatTask(id: "dig", emoji: "📦", title: String(localized: "คุ้ยโปรเจกต์"), subtitle: String(localized: "หา node_modules ฯลฯ"),
                args: ["purge", "--dry-run"]),
    ]

    static let terminal: [CatTask] = [
        CatTask(id: "uninstall", emoji: "🗑️", title: String(localized: "ถอนแอป"), subtitle: "", args: ["uninstall"], inApp: false),
        CatTask(id: "analyze", emoji: "🔎", title: String(localized: "สำรวจดิสก์"), subtitle: "", args: ["analyze"], inApp: false),
        CatTask(id: "installer", emoji: "💿", title: String(localized: "ไฟล์ติดตั้ง"), subtitle: "", args: ["installer"], inApp: false),
        CatTask(id: "whitelist", emoji: "🛡️", title: String(localized: "ยกเว้น"), subtitle: "", args: ["clean", "--whitelist"], inApp: false),
        CatTask(id: "deep", emoji: "🔐", title: String(localized: "ล้างทั้งระบบ"), subtitle: "", args: ["clean"], inApp: false),
    ]

    /// Offered after "คุ้ยโปรเจกต์" finds something.
    static func purgeAll(estimate: OutputParser.Estimate) -> CatTask {
        CatTask(id: "purge", emoji: "🧺", title: String(localized: "ลบที่เจอทั้งหมด"),
                subtitle: estimate.bytes.bytesText, args: ["purge", "--yes"],
                confirm: String(localized: "จะลบโฟลเดอร์ build/dependency ที่เจอทั้งหมด (ประมาณ \(estimate.bytes.bytesText)) แบบถาวร\nติดตั้งกลับได้ด้วย npm install / build ใหม่"))
    }

    static func moleUpdate() -> CatTask {
        CatTask(id: "update", emoji: "⬆️", title: String(localized: "อัปเดต Mole"), subtitle: "", args: ["update"], inApp: false)
    }
}

struct RunSummary: Equatable {
    var text: String
    var good: Bool
}

@MainActor
final class PurrModel: ObservableObject {
    @Published private(set) var moPath: String?
    @Published private(set) var logText = ""
    @Published private(set) var runningTask: CatTask?
    @Published private(set) var summary: RunSummary?
    @Published private(set) var followUp: CatTask?
    @Published var justFinished = false
    @Published var panelVisible = false

    /// Fired with the dry-run estimate whenever "ดมก่อน" finishes.
    var onSniffResult: ((Int64) -> Void)?
    /// Fired before a task starts, so background work can step aside.
    var onTaskStart: (() -> Void)?
    /// Fired when a task is handed to Terminal.
    var onTerminalTask: ((CatTask) -> Void)?

    private var log = LogBuffer()
    private var flushScheduled = false
    private var process: GroupProcess?
    private var stoppedByUser = false
    private var followUpExpiry: Task<Void, Never>?

    var isRunning: Bool { runningTask != nil }

    init() {
        moPath = MoleCLI.find()
    }

    /// Picks up Mole installed (or removed) while Purr was running.
    func refreshMoPath() {
        let found = MoleCLI.find()
        if found != moPath { moPath = found }
    }

    // MARK: - Running Mole

    func perform(_ task: CatTask) {
        refreshMoPath()
        guard let mo = moPath, !isRunning else { return }
        if !task.inApp {
            openInTerminal(mo: mo, args: task.args)
            onTerminalTask?(task)
            return
        }
        if let message = task.confirm, !confirm(title: "\(task.emoji) \(task.title)?", message: message) {
            return
        }
        run(task, mo: mo)
    }

    func stop() {
        stoppedByUser = true
        process?.terminate()
    }

    func clearLog() {
        log.reset()
        logText = ""
        summary = nil
        followUp = nil
    }

    func shutdown() {
        process?.terminate(grace: 0.5)
    }

    private func confirm(title: String, message: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: String(localized: "ลุยเลย 🐾"))
        alert.addButton(withTitle: String(localized: "ไม่เอาดีกว่า"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func run(_ task: CatTask, mo: String) {
        onTaskStart?()
        let process = GroupProcess(executable: mo, arguments: task.args, environment: MoleCLI.environment)
        process.onOutput = { [weak self] data in
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.append(text) }
        }
        let started = Date()
        process.onExit = { [weak self] status in
            Task { @MainActor in await self?.finish(task, status: status, started: started) }
        }

        log.reset("$ mo \(task.args.joined(separator: " "))")
        logText = log.text
        summary = nil
        followUp = nil
        justFinished = false
        stoppedByUser = false
        runningTask = task
        self.process = process
        do {
            try process.start()
        } catch {
            append(String(localized: "แมวสะดุด: \(error.localizedDescription)") + "\n")
            Task { await finish(task, status: -1, started: started) }
        }
    }

    private func append(_ text: String) {
        log.append(text)
        // Long runs print a lot; redraw at most ~8 times a second.
        guard !flushScheduled else { return }
        flushScheduled = true
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            flushScheduled = false
            logText = log.text
        }
    }

    private func finish(_ task: CatTask, status: Int32, started: Date) async {
        logText = log.text
        process = nil
        let output = log.text

        var result: RunSummary
        if stoppedByUser {
            result = RunSummary(text: String(localized: "หยุดแล้ว แมวพักก่อน"), good: false)
        } else if task.isPreview, let estimate = OutputParser.estimate(in: output) {
            result = RunSummary(text: Self.previewText(estimate), good: true)
            if task.id == "sniff" { onSniffResult?(estimate.bytes) }
            if task.id == "dig", estimate.bytes > 0 { offerFollowUp(CatTasks.purgeAll(estimate: estimate)) }
        } else if !task.isPreview, let mo = moPath,
                  let session = await MoleCLI.history(mo)?.session(for: task.args[0], startedAfter: started),
                  session.changedFiles {
            let removed = (session.actions?.removed ?? 0) + (session.actions?.trashed ?? 0)
            result = RunSummary(text: String(localized: "ได้พื้นที่คืน \(session.sizeBytes.bytesText) 🎉 (ลบ \(removed) รายการ)"), good: true)
        } else {
            let lines = OutputParser.resultLines(in: output)
            let fallback = status == 0 ? String(localized: "เสร็จแล้วเหมียว") : String(localized: "จบด้วยรหัส \(Int(status))")
            result = RunSummary(text: lines.isEmpty ? fallback : lines.joined(separator: "\n"), good: status == 0)
        }

        summary = result
        runningTask = nil
        justFinished = status == 0 && !stoppedByUser

        if justFinished, UserDefaults.standard.bool(forKey: Prefs.purrSound) {
            NSSound(named: "Purr")?.play()
        }
        if !panelVisible, UserDefaults.standard.bool(forKey: Prefs.notifyTaskDone) {
            Notifier.shared.post(id: "task", title: "\(task.emoji) \(task.title)", body: result.text)
        }
    }

    /// `mo purge --yes` removes whatever is eligible *now*, so the offer only
    /// stands while the dry-run result it quotes is fresh.
    private func offerFollowUp(_ task: CatTask) {
        followUp = task
        followUpExpiry?.cancel()
        followUpExpiry = Task {
            try? await Task.sleep(for: .seconds(600))
            guard !Task.isCancelled else { return }
            if followUp == task { followUp = nil }
        }
    }

    static func previewText(_ estimate: OutputParser.Estimate) -> String {
        if estimate.bytes == 0 { return String(localized: "สะอาดอยู่แล้ว ไม่มีอะไรให้ลบ") }
        if let items = estimate.items {
            return String(localized: "เจอของให้ลบได้ ~\(estimate.bytes.bytesText) (\(items) รายการ)")
        }
        return String(localized: "เจอของให้ลบได้ ~\(estimate.bytes.bytesText)")
    }

    // MARK: - Terminal

    func openInTerminal(args: [String]) {
        refreshMoPath()
        guard let mo = moPath else { return }
        openInTerminal(mo: mo, args: args)
    }

    private func openInTerminal(mo: String, args: [String]) {
        let command = ([mo] + args).map(Self.shellQuote).joined(separator: " ")
        let script = """
        #!/bin/zsh
        export PATH="\(MoleCLI.shellPath):$PATH"
        clear
        echo "🐱 Purr → mo \(args.joined(separator: " "))"
        echo
        \(command)
        echo
        echo "\(String(localized: "เสร็จแล้วเหมียว ปิดหน้าต่างนี้ได้เลย 🐾"))"
        """
        let name = "purr-" + args.joined(separator: "-").replacingOccurrences(of: "-", with: "") + ".command"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            NSWorkspace.shared.open(url)
        } catch {
            log.reset(String(localized: "เปิด Terminal ไม่ได้: \(error.localizedDescription)"))
            logText = log.text
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
