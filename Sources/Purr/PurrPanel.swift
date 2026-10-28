import SwiftUI

private let catOrange = Color(red: 0.98, green: 0.62, blue: 0.29)

struct PurrPanel: View {
    @EnvironmentObject var model: PurrModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CatHeader()
            StatsRow()

            if model.moPath == nil {
                MissingMole()
            } else {
                SectionLabel("งานแมว")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CatTasks.quick) { TaskButton(task: $0) }
                }

                SectionLabel("เปิดใน Terminal")
                HStack(spacing: 6) {
                    ForEach(CatTasks.terminal) { TerminalChip(task: $0) }
                }

                if !model.log.isEmpty { LogView() }
            }

            Footer()
        }
        .padding(16)
        .frame(width: 360)
    }
}

// MARK: - Header

private struct CatHeader: View {
    @EnvironmentObject var model: PurrModel
    @State private var blink = false

    @State private var wiggle = false
    @State private var patted = false

    private var face: CatMood {
        if model.isRunning { return .busy }
        if patted { return .done }
        if model.justFinished { return .done }
        if blink { return .blink }
        switch model.health {
        case 80...: return .happy
        case 60..<80: return .okay
        default: return .sad
        }
    }

    private var mood: String {
        if let task = model.runningTask { return "กำลัง\(task.title)… อย่าเพิ่งกวนนะ" }
        if model.justFinished { return "สะอาดเอี่ยม ขอนอนก่อนนะ" }
        switch model.health {
        case 80...: return "เครื่องสบายดี แมวก็สบาย"
        case 60..<80: return "เริ่มอึดอัดนิดหน่อย"
        default: return "ช่วยด้วย! พื้นที่/แรมใกล้เต็ม"
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

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Purr").font(.title2.bold())
                    Text("\(model.health)")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(healthColor(model.health).opacity(0.2), in: Capsule())
                        .foregroundStyle(healthColor(model.health))
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

// MARK: - Stats

private struct StatsRow: View {
    @EnvironmentObject var model: PurrModel

    var body: some View {
        HStack(spacing: 8) {
            StatCard(label: "CPU", value: model.cpu, detail: String(format: "%.0f%%", model.cpu))
            StatCard(label: "แรม", value: model.memory, detail: String(format: "%.0f%%", model.memory))
            StatCard(label: "ดิสก์ว่าง", value: model.diskUsed,
                     detail: ByteCountFormatter.string(fromByteCount: model.diskFree, countStyle: .file))
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill").font(.caption2).foregroundStyle(catOrange)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(detail).font(.system(.body, design: .rounded).bold().monospacedDigit())
            ProgressView(value: min(value, 100), total: 100)
                .tint(healthColor(Int(100 - value)))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
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
                    Text(task.emoji).font(.title3).frame(width: 22)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title).font(.callout.bold())
                    Text(task.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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
    }
}

private struct TerminalChip: View {
    @EnvironmentObject var model: PurrModel
    let task: CatTask

    var body: some View {
        Button { model.perform(task) } label: {
            VStack(spacing: 2) {
                Text(task.emoji)
                Text(task.title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isRunning)
        .help("mo \(task.args.joined(separator: " "))")
    }
}

// MARK: - Log

private struct LogView: View {
    @EnvironmentObject var model: PurrModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = model.summary {
                Label {
                    Text(summary).font(.caption).textSelection(.enabled)
                } icon: {
                    Image(systemName: "pawprint.circle.fill").foregroundStyle(catOrange)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.log)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(height: 150)
                .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: model.log) { proxy.scrollTo("end", anchor: .bottom) }
            }

            HStack {
                if model.isRunning {
                    Button("หยุด", systemImage: "stop.fill") { model.stop() }
                        .controlSize(.small)
                }
                Spacer()
                if !model.isRunning {
                    Button("ล้างข้อความ") { model.log = ""; model.summary = nil }
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
            Text("ติดตั้ง Mole ก่อนด้วยคำสั่งนี้ แล้วเปิด Purr ใหม่").font(.caption).foregroundStyle(.secondary)
            Text("brew install mole")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
    }
}

private struct Footer: View {
    @EnvironmentObject var model: PurrModel

    var body: some View {
        HStack {
            Text("ขับเคลื่อนด้วย Mole CLI").font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Button("ออก") { NSApp.terminate(nil) }
                .buttonStyle(.link)
                .font(.caption)
                .keyboardShortcut("q")
        }
    }
}

private func healthColor(_ score: Int) -> Color {
    switch score {
    case 80...: return .green
    case 50..<80: return .orange
    default: return .red
    }
}
