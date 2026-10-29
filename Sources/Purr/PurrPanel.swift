import PurrCore
import SwiftUI

let catOrange = Color(red: 0.98, green: 0.62, blue: 0.29)

enum PanelPage: String {
    case home, history, settings
}

struct PurrPanel: View {
    let onVisibilityChange: (Bool) -> Void
    @State var page = PanelPage.home

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch page {
            case .home: HomePage(page: $page)
            case .history: HistoryPage(page: $page)
            case .settings: SettingsPage(page: $page)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(WindowVisibilityObserver(onChange: onVisibilityChange))
    }
}

private struct HomePage: View {
    @EnvironmentObject var model: PurrModel
    @EnvironmentObject var updates: UpdateChecker
    @Binding var page: PanelPage

    var body: some View {
        CatHeader()
        if updates.purrRelease != nil { UpdateBanner() }
        StatsSection()

        if model.moPath == nil {
            MissingMole()
        } else {
            if updates.moleUpdateAvailable { MoleUpdateRow() }

            SectionLabel("งานแมว")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(CatTasks.quick) { TaskButton(task: $0) }
            }
            if let followUp = model.followUp, !model.isRunning {
                FollowUpButton(task: followUp)
            }
            SniffNote()

            SectionLabel("เปิดใน Terminal")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(CatTasks.terminal) { TerminalChip(task: $0) }
            }

            if !model.logText.isEmpty { LogView() }
        }

        Footer(page: $page)
    }
}

// MARK: - Header

private struct CatHeader: View {
    @EnvironmentObject var model: PurrModel
    @EnvironmentObject var monitor: StatusMonitor
    @State private var blink = false
    @State private var wiggle = false
    @State private var patted = false

    private var face: CatMood {
        if model.isRunning { return .busy }
        if patted || model.justFinished { return .done }
        if blink { return .blink }
        switch monitor.level {
        case .good: return .happy
        case .fair: return .okay
        case .poor: return .sad
        }
    }

    private var mood: String {
        if let task = model.runningTask { return String(localized: "กำลัง\(task.title)… อย่าเพิ่งกวนนะ") }
        if model.justFinished { return String(localized: "สะอาดเอี่ยม ขอนอนก่อนนะ") }
        switch monitor.level {
        case .good: return String(localized: "เครื่องสบายดี แมวก็สบาย")
        case .fair: return String(localized: "เริ่มอึดอัดนิดหน่อย")
        case .poor: return String(localized: "ช่วยด้วย! พื้นที่/แรมใกล้เต็ม")
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            CatFace(mood: face)
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(model.isRunning ? (wiggle ? 7 : -7) : 0), anchor: .bottom)
                .offset(y: model.justFinished && wiggle ? -3 : 0)
                .padding(8)
                .background(catOrange.opacity(0.16), in: RoundedRectangle(cornerRadius: 20))
                .onTapGesture {
                    // A pat makes the cat purr (smile) for a moment.
                    patted = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        patted = false
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { wiggle = true }
                }
                .help("ลูบหัวแมว")
                .accessibilityElement()
                .accessibilityLabel(Text("แมว Purr"))
                .accessibilityValue(Text(mood))
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text("ลูบหัวแมว"))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: "Purr").font(.title2.bold())
                    Text(verbatim: "\(monitor.health)")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(healthColor(monitor.health).opacity(0.2), in: Capsule())
                        .foregroundStyle(healthColor(monitor.health))
                        .help("คะแนนสุขภาพเครื่อง (0–100)")
                        .accessibilityLabel(Text("คะแนนสุขภาพเครื่อง \(monitor.health) จาก 100"))
                }
                Text(mood).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .task {
            // Occasional slow blink, like a content cat.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 4...8)))
                blink = true
                try? await Task.sleep(for: .milliseconds(350))
                blink = false
            }
        }
    }
}

// MARK: - Updates

private struct UpdateBanner: View {
    @EnvironmentObject var updates: UpdateChecker

    var body: some View {
        if let release = updates.purrRelease, let version = release.version {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🎁 Purr v\(version.description) มาแล้ว!").font(.callout.bold())
                    Spacer()
                    Text(verbatim: AppInfo.versionText).font(.caption2).foregroundStyle(.secondary)
                }
                let notes = release.notesPreview()
                if !notes.isEmpty {
                    Text(verbatim: notes).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
                HStack {
                    Button("ดาวน์โหลด") { NSWorkspace.shared.open(release.zipAsset?.browserDownloadUrl ?? release.htmlUrl) }
                        .buttonStyle(.borderedProminent).tint(catOrange).controlSize(.small)
                    Button("ดูรายละเอียด") { NSWorkspace.shared.open(release.htmlUrl) }
                        .controlSize(.small)
                    Spacer()
                    Button("ข้ามเวอร์ชันนี้") { updates.skipCurrentRelease() }
                        .buttonStyle(.link).font(.caption)
                }
            }
            .padding(10)
            .background(catOrange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .contain)
        }
    }
}

private struct MoleUpdateRow: View {
    @EnvironmentObject var model: PurrModel
    @EnvironmentObject var updates: UpdateChecker

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill").foregroundStyle(catOrange)
            Text("Mole \(updates.moleLatest?.description ?? "") มาแล้ว (เครื่องนี้ \(updates.moleInstalled?.description ?? "?"))")
                .font(.caption)
            Spacer()
            Button("อัปเดต") { model.perform(CatTasks.moleUpdate()) }
                .controlSize(.small)
                .help(Text(verbatim: "mo update"))
        }
        .padding(8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Stats

private struct StatsSection: View {
    @EnvironmentObject var monitor: StatusMonitor
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    StatCard(label: "CPU", value: monitor.cpu, detail: String(format: "%.0f%%", monitor.cpu))
                    StatCard(label: "แรม", value: monitor.memory, detail: String(format: "%.0f%%", monitor.memory))
                    StatCard(label: "ดิสก์ว่าง", value: monitor.diskUsed, detail: monitor.diskFree.bytesText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(expanded ? "ซ่อนรายละเอียด" : "ดูรายละเอียดเพิ่ม")
            .accessibilityHint(Text(expanded ? "ซ่อนรายละเอียด" : "ดูรายละเอียดเพิ่ม"))

            if expanded {
                if let status = monitor.status {
                    DetailsView(status: status)
                } else {
                    Text("รายละเอียดเพิ่มเติมต้องใช้ Mole").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct StatCard: View {
    let label: LocalizedStringKey
    let value: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill").font(.caption2).foregroundStyle(catOrange)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(verbatim: detail).font(.system(.body, design: .rounded).bold().monospacedDigit())
            ProgressView(value: min(value, 100), total: 100)
                .tint(healthColor(Int(100 - value)))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(verbatim: detail))
    }
}

private struct DetailsView: View {
    let status: MoleStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                if let mem = status.memory, let swap = mem.swapUsed {
                    row("Swap", swap.bytesText + (mem.swapTotal.map { " / " + $0.bytesText } ?? ""))
                }
                if let battery = status.battery, let percent = battery.percent {
                    row("แบตเตอรี่", batteryText(battery, percent: percent))
                }
                if let temp = status.thermal?.cpuTemp, temp > 0 {
                    row("CPU", String(format: "%.0f°C", temp))
                } else if let temp = status.thermal?.batteryTemp, temp > 0 {
                    row("อุณหภูมิแบต", String(format: "%.0f°C", temp))
                }
                if let purgeable = status.rootDisk?.purgeable, purgeable > 0 {
                    row("macOS คืนได้เอง", purgeable.bytesText)
                }
                if let trash = status.trashSize, trash > 0 {
                    row("ถังขยะ", trash.bytesText)
                }
                if let uptime = status.uptime {
                    row("เปิดเครื่องมา", uptime)
                }
            }
            .font(.caption)

            if let alerts = status.processAlerts, !alerts.isEmpty {
                ForEach(alerts, id: \.pid) { alert in
                    Label {
                        Text("\(alert.name ?? "?") ใช้ CPU \(Int(alert.cpu ?? 0))% นานแล้ว")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .font(.caption)
                }
            }

            if let processes = status.topProcesses, !processes.isEmpty {
                Text("กิน CPU มากสุด").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(processes.prefix(5)) { process in
                    HStack {
                        Text(verbatim: process.name ?? "pid \(process.pid)").lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(verbatim: String(format: "%.0f%%", process.cpu ?? 0)).monospacedDigit()
                        Text(verbatim: (process.memoryBytes ?? 0).bytesText)
                            .monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .trailing)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(verbatim: value).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func batteryText(_ battery: MoleStatus.Battery, percent: Double) -> String {
        var parts = [String(format: "%.0f%%", percent)]
        if let capacity = battery.capacity { parts.append(String(localized: "ความจุ \(Int(capacity))%")) }
        if let cycles = battery.cycleCount { parts.append(String(localized: "\(cycles) รอบ")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Actions

private struct TaskButton: View {
    @EnvironmentObject var model: PurrModel
    let task: CatTask

    var body: some View {
        let active = model.runningTask?.id == task.id
        Button { model.perform(task) } label: {
            HStack(spacing: 8) {
                if active {
                    ProgressView().controlSize(.small).frame(width: 22)
                } else {
                    Text(verbatim: task.emoji).font(.title3).frame(width: 22).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: task.title).font(.callout.bold())
                    Text(verbatim: task.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(active ? catOrange.opacity(0.25) : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isRunning)
        .opacity(model.isRunning && !active ? 0.5 : 1)
        .help(Text(verbatim: "mo \(task.args.joined(separator: " "))"))
        .accessibilityLabel(Text(verbatim: task.title))
        .accessibilityHint(Text(verbatim: task.subtitle))
    }
}

private struct FollowUpButton: View {
    @EnvironmentObject var model: PurrModel
    let task: CatTask

    var body: some View {
        Button { model.perform(task) } label: {
            HStack {
                Text(verbatim: task.emoji).accessibilityHidden(true)
                Text(verbatim: task.title).bold()
                Spacer()
                Text(verbatim: task.subtitle).monospacedDigit()
            }
            .font(.callout)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(catOrange.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: "mo \(task.args.joined(separator: " "))"))
    }
}

/// When the last "ดมก่อน" ran, whether by hand or the weekly check.
private struct SniffNote: View {
    @EnvironmentObject var care: CareService

    var body: some View {
        if care.sniffing {
            Label("แมวกำลังแอบดมเงียบๆ (เช็กประจำสัปดาห์)", systemImage: "nose")
                .font(.caption2).foregroundStyle(.secondary)
        } else if let date = care.lastSniff, let bytes = care.lastSniffBytes {
            Text("ดมล่าสุด \(date, format: .relative(presentation: .named)) · ลบได้ ~\(bytes.bytesText)")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct TerminalChip: View {
    @EnvironmentObject var model: PurrModel
    let task: CatTask

    var body: some View {
        Button { model.perform(task) } label: {
            VStack(spacing: 2) {
                Text(verbatim: task.emoji).accessibilityHidden(true)
                Text(verbatim: task.title).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isRunning)
        .help(Text(verbatim: "mo \(task.args.joined(separator: " "))"))
        .accessibilityLabel(Text(verbatim: task.title))
        .accessibilityHint(Text("เปิดใน Terminal"))
    }
}

// MARK: - Log

private struct LogView: View {
    @EnvironmentObject var model: PurrModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = model.summary {
                Label {
                    Text(verbatim: summary.text).font(.caption).textSelection(.enabled)
                } icon: {
                    Image(systemName: summary.good ? "pawprint.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(summary.good ? catOrange : .orange)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(verbatim: model.logText)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(height: 150)
                .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: model.logText) { proxy.scrollTo("end", anchor: .bottom) }
                .accessibilityLabel(Text("ผลลัพธ์จาก Mole"))
            }

            HStack {
                if model.isRunning {
                    Button("หยุด", systemImage: "stop.fill") { model.stop() }
                        .controlSize(.small)
                }
                Spacer()
                if !model.isRunning {
                    Button("ล้างข้อความ") { model.clearLog() }
                        .controlSize(.small)
                        .buttonStyle(.link)
                }
            }
        }
    }
}

// MARK: - Misc

private struct MissingMole: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("(=ｘェｘ=) หา `mo` ไม่เจอ").font(.callout.bold())
            Text("ติดตั้ง Mole ก่อนด้วยคำสั่งนี้ แล้วเปิดแผงนี้ใหม่").font(.caption).foregroundStyle(.secondary)
            Text(verbatim: "brew install mole")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct SectionLabel: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text).font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct Footer: View {
    @Binding var page: PanelPage

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: AppInfo.versionText).font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Button { page = .history } label: { Image(systemName: "clock.arrow.circlepath") }
                .help("ประวัติ")
                .accessibilityLabel(Text("ประวัติ"))
            Button { page = .settings } label: { Image(systemName: "gearshape") }
                .help("ตั้งค่า")
                .accessibilityLabel(Text("ตั้งค่า"))
                .keyboardShortcut(",")
            Button("ออก") { NSApp.terminate(nil) }
                .font(.caption)
                .keyboardShortcut("q")
        }
        .buttonStyle(.link)
    }
}

/// Header for the history and settings pages.
struct SubpageHeader: View {
    let title: LocalizedStringKey
    @Binding var page: PanelPage

    var body: some View {
        HStack {
            Button { page = .home } label: {
                Label("กลับ", systemImage: "chevron.left")
            }
            .buttonStyle(.link)
            .keyboardShortcut(.cancelAction)
            Spacer()
            Text(title).font(.headline)
            Spacer()
            CatFace(mood: .okay).frame(width: 22, height: 22).accessibilityHidden(true)
        }
    }
}

func healthColor(_ score: Int) -> Color {
    switch HealthLevel(score: score) {
    case .good: return .green
    case .fair: return .orange
    case .poor: return .red
    }
}

/// Reports when the menu bar panel is shown or hidden, so polling can slow
/// down while nobody is looking.
private struct WindowVisibilityObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView { ObserverView(onChange: onChange) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ObserverView: NSView {
        let onChange: (Bool) -> Void
        private var token: NSObjectProtocol?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token) }
            guard let window else { return }
            token = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                                           object: window, queue: .main) { [weak self] note in
                guard let window = note.object as? NSWindow else { return }
                self?.onChange(window.occlusionState.contains(.visible))
            }
            onChange(window.occlusionState.contains(.visible) || window.isVisible)
        }
    }
}
