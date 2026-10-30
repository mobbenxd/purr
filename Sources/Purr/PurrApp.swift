import AppKit
import SwiftUI

@main
enum Main {
    static func main() {
        let args = CommandLine.arguments
        // Used by build.sh to draw the app icon from the same code as the cat.
        if let i = args.firstIndex(of: "--export-icon"), i + 1 < args.count {
            _ = NSApplication.shared
            MainActor.assumeIsolated {
                do {
                    try CatFace.exportIconSet(to: URL(fileURLWithPath: args[i + 1]))
                    exit(0)
                } catch {
                    FileHandle.standardError.write(Data("export-icon: \(error)\n".utf8))
                    exit(1)
                }
            }
        }
        Prefs.registerDefaults()
        Language.applySaved()
        PurrApp.main()
    }
}

struct PurrApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        MenuBarExtra {
            PurrPanel(onVisibilityChange: services.panelVisibilityChanged)
                .environmentObject(services.model)
                .environmentObject(services.monitor)
                .environmentObject(services.care)
                .environmentObject(services.updates)
        } label: {
            MenuBarLabel(model: services.model, monitor: services.monitor, runner: services.runner)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Owns the long-lived services and wires them together.
@MainActor
final class AppServices: ObservableObject {
    let model = PurrModel()
    let monitor = StatusMonitor()
    let care = CareService()
    let updates = UpdateChecker()
    let moleWatcher = MoleWatcher()
    let runner = CatRunner()

    init() {
        Notifier.shared.setUp()
        let model = model
        care.isBusy = { [weak model] in model?.isRunning ?? false }
        care.moPath = { [weak model] in model?.moPath }
        updates.moPath = { [weak model] in model?.moPath }
        model.onSniffResult = { [weak care] in care?.recordSniff(bytes: $0) }
        model.onTaskStart = { [weak care] in care?.cancelSniff() }
        monitor.onSnapshot = { [weak care] in care?.handle($0) }
        moleWatcher.moPath = { [weak model] in model?.moPath }
        moleWatcher.isBusy = { [weak model] in model?.isRunning ?? false }
        runner.isBusy = { [weak model] in model?.isRunning ?? false }
        updates.isBusy = { [weak model] in model?.isRunning ?? false }
        model.onTaskLaunched = { [weak moleWatcher] task in
            if task.id == CatTasks.moleUpdate().id { moleWatcher?.watchUpdate() }
        }

        monitor.start(moPath: model.moPath)
        care.start()
        updates.start()
        moleWatcher.start()
        runner.start()

        // `kill`, logout and Ctrl-C should still stop Mole's helpers via the
        // normal quit path below.
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }

        if CommandLine.arguments.contains("--window") {
            DispatchQueue.main.async { self.showPanelWindow() }
        }

        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.model.shutdown()
                self?.monitor.stop()
                self?.care.cancelSniff()
            }
        }
    }

    func panelVisibilityChanged(_ visible: Bool) {
        model.panelVisible = visible
        if visible {
            model.refreshMoPath()
            monitor.start(moPath: model.moPath)
        }
        monitor.setVisible(visible)
    }

    /// Developer aid (`--window [home|history|settings]`): the panel in an
    /// ordinary window, for screenshots and debugging without the menu bar.
    private func showPanelWindow() {
        let args = CommandLine.arguments
        let page = args.firstIndex(of: "--window").flatMap { args.indices.contains($0 + 1) ? PanelPage(rawValue: args[$0 + 1]) : nil }
        let panel = PurrPanel(onVisibilityChange: panelVisibilityChanged, page: page ?? .home)
            .environmentObject(model)
            .environmentObject(monitor)
            .environmentObject(care)
            .environmentObject(updates)
        let window = NSWindow(contentViewController: NSHostingController(rootView: panel))
        window.title = "Purr"
        window.setFrameOrigin(NSPoint(x: 80, y: 120))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panelWindow = window
    }

    private var panelWindow: NSWindow?
    private var signalSources: [DispatchSourceSignal] = []
}

private struct MenuBarLabel: View {
    @ObservedObject var model: PurrModel
    @ObservedObject var monitor: StatusMonitor
    @ObservedObject var runner: CatRunner
    @AppStorage(Prefs.moodIcon) private var moodIcon = true

    private var mood: CatMood {
        if model.isRunning { return .busy }
        guard moodIcon else { return .okay }
        switch monitor.level {
        case .good: return .happy
        case .fair: return .okay
        case .poor: return .sad
        }
    }

    var body: some View {
        Image(nsImage: RunningCat.menuBarImage(frame: runner.frame, mood: mood))
            .accessibilityLabel(Text("Purr \(monitor.health)"))
    }
}
