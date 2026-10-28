import AppKit
import Foundation

/// One thing the cat can do. `inApp` tasks stream into the log;
/// the rest are interactive TUIs and open in Terminal.
struct CatTask: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let subtitle: String
    let args: [String]
    var inApp = true
    var confirm: String? = nil
}

enum CatTasks {
    static let quick: [CatTask] = [
        CatTask(id: "sniff", emoji: "👃", title: "ดมก่อน", subtitle: "ดูว่าลบอะไรได้บ้าง",
                args: ["clean", "--dry-run"]),
        CatTask(id: "groom", emoji: "🧹", title: "เลียขน", subtitle: "ล้างแคช/ล็อก",
                args: ["clean"],
                confirm: "แคช ล็อก และถังขยะจะถูกลบถาวร (ไม่ผ่าน Trash)\nแนะนำให้กด \"ดมก่อน\" เพื่อดูรายการก่อน"),
        CatTask(id: "stretch", emoji: "🧘", title: "ยืดเส้น", subtitle: "Optimize ระบบ",
                args: ["optimize"],
                confirm: "รีเฟรช DNS, QuickLook, ไอคอน และฐานข้อมูลระบบ"),
        CatTask(id: "dig", emoji: "📦", title: "คุ้ยโปรเจกต์", subtitle: "หา node_modules ฯลฯ",
                args: ["purge", "--dry-run"]),
    ]

    static let terminal: [CatTask] = [
        CatTask(id: "uninstall", emoji: "🗑️", title: "ถอนแอป", subtitle: "", args: ["uninstall"], inApp: false),
        CatTask(id: "analyze", emoji: "🔎", title: "สำรวจดิสก์", subtitle: "", args: ["analyze"], inApp: false),
        CatTask(id: "installer", emoji: "💿", title: "ไฟล์ติดตั้ง", subtitle: "", args: ["installer"], inApp: false),
        CatTask(id: "history", emoji: "📜", title: "ประวัติ", subtitle: "", args: ["history"], inApp: false),
    ]
}

@MainActor
final class PurrModel: ObservableObject {
    @Published var cpu: Double = 0
    @Published var memory: Double = 0
    @Published var diskFree: Int64 = 0
    @Published var diskTotal: Int64 = 0
    @Published var log = ""
    @Published var runningTask: CatTask?
    @Published var summary: String?
    @Published var justFinished = false

    let moPath: String?
    private var stats = SystemStats()
    private var timer: Timer?
    private var process: Process?

    var isRunning: Bool { runningTask != nil }

    var diskUsed: Double {
        diskTotal > 0 ? Double(diskTotal - diskFree) / Double(diskTotal) * 100 : 0
    }

    /// Rough 0–100 score: lower load and more free disk keep the cat happy.
    var health: Int {
        let penalty = max(0, cpu - 50) * 0.4 + max(0, memory - 60) * 0.5 + max(0, diskUsed - 75) * 1.2
        return max(0, min(100, Int(100 - penalty)))
    }

    init() {
        moPath = Self.findMo()
        refreshStats()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStats() }
        }
    }

    private static func findMo() -> String? {
        let candidates = ["/opt/homebrew/bin/mo", "/usr/local/bin/mo",
                          NSHomeDirectory() + "/.local/bin/mo", "/run/current-system/sw/bin/mo"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static var shellPath: String {
        "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    func refreshStats() {
        cpu = stats.cpuUsage()
        memory = stats.memoryUsage()
        (diskFree, diskTotal) = stats.disk()
    }

    // MARK: - Running Mole

    func perform(_ task: CatTask) {
        guard let mo = moPath, !isRunning else { return }
        if !task.inApp {
            openInTerminal(mo: mo, args: task.args)
            return
        }
        if let message = task.confirm, !confirm(title: "\(task.emoji) \(task.title)?", message: message) {
            return
        }
        run(task, mo: mo)
    }

    private func confirm(title: String, message: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "ลุยเลย 🐾")
        alert.addButton(withTitle: "ไม่เอาดีกว่า")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func run(_ task: CatTask, mo: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mo)
        process.arguments = task.args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.shellPath
        env["NO_COLOR"] = "1"
        env["TERM"] = "dumb"
        process.environment = env
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.append(text) }
        }

        process.terminationHandler = { proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            let rest = pipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor [weak self] in
                if let text = String(data: rest, encoding: .utf8) { self?.append(text) }
                self?.finish(status: proc.terminationStatus)
            }
        }

        log = "$ mo \(task.args.joined(separator: " "))\n"
        summary = nil
        justFinished = false
        runningTask = task
        self.process = process
        do {
            try process.run()
        } catch {
            append("แมวสะดุด: \(error.localizedDescription)\n")
            finish(status: -1)
        }
    }

    func stop() {
        process?.terminate()
    }

    private func append(_ raw: String) {
        log += Self.clean(raw)
        if log.count > 60_000 { log = String(log.suffix(50_000)) }
    }

    private func finish(status: Int32) {
        let lines = log.split(separator: "\n").map(String.init)
        let keys = ["Potential space", "Tracked cleanup", "Free space", "complete", "Nothing to"]
        let picked = lines.filter { line in keys.contains { line.contains($0) } }.suffix(3)
        summary = picked.isEmpty
            ? (status == 0 ? "เสร็จแล้วเหมียว" : "จบด้วยรหัส \(status)")
            : picked.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        runningTask = nil
        process = nil
        justFinished = status == 0
        refreshStats()
    }

    /// Strips ANSI escapes and spinner carriage returns that Mole may still emit.
    private static func clean(_ text: String) -> String {
        var out = text.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: "\r\n", with: "\n")
        out = out.replacingOccurrences(of: "[^\n]*\r", with: "", options: .regularExpression)
        return out
    }

    private func openInTerminal(mo: String, args: [String]) {
        let script = """
        #!/bin/zsh
        export PATH="\(Self.shellPath):$PATH"
        clear
        echo "🐱 Purr → mo \(args.joined(separator: " "))"
        echo
        "\(mo)" \(args.joined(separator: " "))
        echo
        echo "เสร็จแล้วเหมียว ปิดหน้าต่างนี้ได้เลย 🐾"
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("purr-\(args[0]).command")
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            NSWorkspace.shared.open(url)
        } catch {
            log = "เปิด Terminal ไม่ได้: \(error.localizedDescription)\n"
        }
    }
}
