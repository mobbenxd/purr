import PurrCore
import ServiceManagement
import SwiftUI

// MARK: - History

struct HistoryPage: View {
    @EnvironmentObject var model: PurrModel
    @Binding var page: PanelPage
    @State private var history: MoleHistory?
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        SubpageHeader(title: "ประวัติ", page: $page)

        if loading {
            HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }.frame(height: 120)
        } else if let history, !history.sessions.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(catOrange)
                Text("แมวช่วยคืนพื้นที่ไปแล้ว \(history.totalFreed.bytesText)").font(.callout.bold())
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(history.sessions) { HistoryRow(session: $0) }
                }
            }
            // The menu bar window sizes to fit, and a ScrollView has no natural height.
            .frame(height: min(CGFloat(history.sessions.count) * 60, 360))

            if let path = history.logs?.deletions, FileManager.default.fileExists(atPath: path) {
                Button("เปิดรายการไฟล์ที่ถูกลบ") { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
                    .buttonStyle(.link).font(.caption)
            }
        } else {
            Text("ยังไม่มีประวัติ ลองกด \"ดมก่อน\" ดูสิ").font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 100)
        }
    }

    private func load() async {
        loading = true
        if let mo = model.moPath { history = await MoleCLI.history(mo) }
        loading = false
    }
}

private struct HistoryRow: View {
    let session: MoleHistory.Session

    private var emoji: String {
        switch session.command {
        case "clean": return "🧹"
        case "purge": return "📦"
        case "optimize": return "🧘"
        case "uninstall": return "🗑️"
        case "installer": return "💿"
        default: return "🐾"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: emoji).font(.title3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "mo \(session.command)").font(.callout.bold())
                if let date = session.startedDate {
                    Text(date, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: session.sizeBytes > 0 ? session.sizeBytes.bytesText : "–").font(.callout.monospacedDigit())
                if session.changedFiles {
                    let removed = (session.actions?.removed ?? 0) + (session.actions?.trashed ?? 0)
                    Text("ลบ \(removed) รายการ").font(.caption2).foregroundStyle(.green)
                } else {
                    Text("ดูอย่างเดียว").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Settings

struct SettingsPage: View {
    @EnvironmentObject var updates: UpdateChecker
    @Binding var page: PanelPage

    @AppStorage(Prefs.notifyLowDisk) private var notifyLowDisk = true
    @AppStorage(Prefs.lowDiskGB) private var lowDiskGB = 10
    @AppStorage(Prefs.notifyMemory) private var notifyMemory = true
    @AppStorage(Prefs.notifyProcess) private var notifyProcess = true
    @AppStorage(Prefs.notifyTaskDone) private var notifyTaskDone = true
    @AppStorage(Prefs.weeklySniff) private var weeklySniff = true
    @AppStorage(Prefs.sniffNotifyMB) private var sniffNotifyMB = 1024
    @AppStorage(Prefs.checkUpdates) private var checkUpdates = true
    @AppStorage(Prefs.purrSound) private var purrSound = true
    @AppStorage(Prefs.moodIcon) private var moodIcon = true
    @AppStorage(Prefs.language) private var language = Language.thai.rawValue
    @State private var launchedLanguage = UserDefaults.standard.string(forKey: Prefs.language) ?? Language.thai.rawValue

    var body: some View {
        SubpageHeader(title: "ตั้งค่า", page: $page)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsGroup("แจ้งเตือน") {
                    Toggle("ดิสก์ใกล้เต็ม", isOn: $notifyLowDisk)
                    if notifyLowDisk {
                        Stepper(value: $lowDiskGB, in: 5...100, step: 5) {
                            Text("เตือนเมื่อเหลือน้อยกว่า \(lowDiskGB) GB").font(.caption)
                        }
                        .padding(.leading, 20)
                    }
                    Toggle("แรมตึง (ใช้ swap เยอะ)", isOn: $notifyMemory)
                    Toggle("โปรแกรมกิน CPU นานผิดปกติ", isOn: $notifyProcess)
                    Toggle("งานเสร็จตอนปิดแผงอยู่", isOn: $notifyTaskDone)
                }

                SettingsGroup("ดูแลอัตโนมัติ") {
                    Toggle("แอบดมทุกสัปดาห์ (mo clean --dry-run)", isOn: $weeklySniff)
                    if weeklySniff {
                        Picker("เตือนเมื่อลบได้เกิน", selection: $sniffNotifyMB) {
                            Text(verbatim: "500 MB").tag(500)
                            Text(verbatim: "1 GB").tag(1024)
                            Text(verbatim: "2 GB").tag(2048)
                            Text(verbatim: "5 GB").tag(5120)
                        }
                        .font(.caption)
                        .padding(.leading, 20)
                    }
                }

                SettingsGroup("หน้าตา") {
                    Toggle("หน้าแมวบนแถบเมนูเปลี่ยนตามสุขภาพเครื่อง", isOn: $moodIcon)
                    Toggle("เสียงครางเมื่องานเสร็จ", isOn: $purrSound)
                    Picker("ภาษา", selection: $language) {
                        Text(verbatim: "ไทย").tag(Language.thai.rawValue)
                        Text(verbatim: "English").tag(Language.english.rawValue)
                        Text("ตามระบบ").tag(Language.system.rawValue)
                    }
                    if language != launchedLanguage {
                        HStack {
                            Text("เปลี่ยนภาษาแล้ว ต้องเปิด Purr ใหม่").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("เปิดใหม่เลย") { relaunch() }.controlSize(.small)
                        }
                    }
                }

                SettingsGroup("ระบบ") {
                    LoginItemToggle()
                    Toggle("เช็กเวอร์ชันใหม่วันละครั้ง", isOn: $checkUpdates)
                    HStack {
                        Button("เช็กเลย") { Task { await updates.check(manual: true) } }
                            .controlSize(.small)
                            .disabled(updates.checking)
                        if updates.checking {
                            ProgressView().controlSize(.mini)
                        } else if let result = updates.lastResult {
                            Text(verbatim: result).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text(verbatim: "Purr \(AppInfo.versionText)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Link(destination: AppInfo.repositoryURL) { Text(verbatim: "GitHub") }.font(.caption)
                    }
                }
            }
            .toggleStyle(TrailingSwitch())
            .controlSize(.small)
        }
        .frame(height: 440)
    }

    private func relaunch() {
        let path = Bundle.main.bundlePath
        guard path.hasSuffix(".app") else { return NSApp.terminate(nil) }
        let opener = Process()
        opener.executableURL = URL(fileURLWithPath: "/bin/sh")
        opener.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? opener.run()
        NSApp.terminate(nil)
    }
}

/// Label on the left, switch on the right edge, like System Settings.
private struct TrailingSwitch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Toggle(configuration).toggleStyle(.switch).labelsHidden()
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Open at login via SMAppService; only available from a real `.app`.
private struct LoginItemToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        if Bundle.main.bundlePath.hasSuffix(".app") {
            Toggle("เปิด Purr อัตโนมัติเมื่อเข้าเครื่อง", isOn: Binding(get: { enabled }, set: set))
            if let error {
                Text(verbatim: error).font(.caption2).foregroundStyle(.red)
            }
        }
    }

    private func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        enabled = SMAppService.mainApp.status == .enabled
    }
}
