import AppKit
import Combine
import PurrCore
import SwiftUI

/// An orange cat running in profile, drawn on a 100×64 grid. `phase` (0..<1)
/// is one stride; the menu bar steps through `RunningCat.frameCount` of them.
struct RunningCat: View {
    var phase: Double
    var mood: CatMood = .okay

    static let frameCount = 6

    private let fur = Color(red: 0.98, green: 0.56, blue: 0.16)
    private let stripe = Color(red: 0.80, green: 0.34, blue: 0.06)
    private let pink = Color(red: 1.00, green: 0.62, blue: 0.70)
    private let ink = Color(red: 0.24, green: 0.17, blue: 0.15)

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 100, y: size.height / 64)
            draw(&ctx)
        }
    }

    private func draw(_ ctx: inout GraphicsContext) {
        let a = phase * 2 * .pi
        // The body bobs twice per stride, highest mid-flight.
        let bob = -2.5 * abs(sin(a))
        ctx.translateBy(x: 0, y: bob)

        let limb = StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)

        // Tail sways opposite to the bob.
        var tail = Path()
        tail.move(to: CGPoint(x: 26, y: 28))
        tail.addQuadCurve(to: CGPoint(x: 6, y: 12 + 6 * sin(a)), control: CGPoint(x: 8, y: 32))
        ctx.stroke(tail, with: .color(fur), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        // Gallop: back and front pairs swing in opposite phase, the far leg of
        // each pair slightly behind and darker.
        let swing = 0.75
        for (hip, offset, far) in [(CGPoint(x: 32, y: 38), 0.0, true), (CGPoint(x: 66, y: 38), .pi, true),
                                   (CGPoint(x: 34, y: 38), 0.7, false), (CGPoint(x: 68, y: 38), .pi + 0.7, false)] {
            let angle = swing * sin(a + offset)
            let knee = CGPoint(x: hip.x + 12 * sin(angle), y: hip.y + 12 * cos(angle))
            let bend = angle * 0.6 + (hip.x < 50 ? -0.4 : 0.4)
            let paw = CGPoint(x: knee.x + 11 * sin(bend), y: knee.y + 11 * cos(bend))
            var leg = Path()
            leg.move(to: hip)
            leg.addLine(to: knee)
            leg.addLine(to: paw)
            ctx.stroke(leg, with: .color(far ? stripe : fur), style: limb)
        }

        // Body
        ctx.fill(Path(roundedRect: CGRect(x: 22, y: 22, width: 54, height: 24), cornerRadius: 12), with: .color(fur))
        for x in [36.0, 46.0, 56.0] {
            var p = Path()
            p.move(to: CGPoint(x: x, y: 23))
            p.addLine(to: CGPoint(x: x - 3, y: 31))
            ctx.stroke(p, with: .color(stripe), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }

        // Head with ears
        for (base, tip, end) in [(CGPoint(x: 70, y: 16), CGPoint(x: 72, y: 1), CGPoint(x: 81, y: 11)),
                                 (CGPoint(x: 82, y: 11), CGPoint(x: 92, y: 2), CGPoint(x: 93, y: 17))] {
            var ear = Path()
            ear.move(to: base)
            ear.addLine(to: tip)
            ear.addLine(to: end)
            ear.closeSubpath()
            ctx.fill(ear, with: .color(fur))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: 66, y: 8, width: 32, height: 28)), with: .color(fur))
        ctx.fill(Path(ellipseIn: CGRect(x: 84, y: 22, width: 13, height: 9)), with: .color(.white.opacity(0.6)))

        // Eye
        switch mood {
        case .happy, .done:
            var p = Path()
            p.move(to: CGPoint(x: 82, y: 20))
            p.addQuadCurve(to: CGPoint(x: 90, y: 20), control: CGPoint(x: 86, y: 14))
            ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        case .busy, .blink:
            var p = Path()
            p.move(to: CGPoint(x: 82, y: 19))
            p.addLine(to: CGPoint(x: 90, y: 19))
            ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        case .okay, .sad:
            ctx.fill(Path(ellipseIn: CGRect(x: 83, y: 14, width: 7, height: 9)), with: .color(ink))
            ctx.fill(Path(ellipseIn: CGRect(x: 86, y: 15, width: 3, height: 3)), with: .color(.white))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: 94, y: 22, width: 5, height: 4)), with: .color(pink))

        if mood == .sad {
            // Sweat drop behind the head
            var drop = Path()
            drop.move(to: CGPoint(x: 64, y: 4))
            drop.addQuadCurve(to: CGPoint(x: 64, y: 16), control: CGPoint(x: 71, y: 14))
            drop.addQuadCurve(to: CGPoint(x: 64, y: 4), control: CGPoint(x: 57, y: 14))
            ctx.fill(drop, with: .color(Color(red: 0.45, green: 0.72, blue: 1.0)))
        }
    }
}

extension RunningCat {
    private struct Key: Hashable { var frame: Int; var mood: CatMood }
    private static var cache: [Key: NSImage] = [:]

    /// One frame of the run for the menu bar. Full colour, so not a template.
    @MainActor static func menuBarImage(frame: Int, mood: CatMood) -> NSImage {
        let key = Key(frame: frame, mood: mood)
        if let cached = cache[key] { return cached }
        let view = RunningCat(phase: Double(frame) / Double(frameCount), mood: mood).frame(width: 28, height: 18)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "cat.fill", accessibilityDescription: nil)!
        image.accessibilityDescription = "Purr"
        cache[key] = image
        return image
    }
}

/// Drives the menu bar cat like RunCat: the busier the CPU, the faster it runs.
/// Samples the kernel directly every few seconds because `StatusMonitor` only
/// updates once a minute while the panel is closed.
@MainActor
final class CatRunner: ObservableObject {
    @Published private(set) var frame = 0
    /// Forces at least a brisk trot, e.g. while a task is running.
    var isBusy: () -> Bool = { false }

    private var stats = SystemStats()
    private var cpu: Double = 0
    private var frameTimer: Timer?
    private var sampleTimer: Timer?
    private var interval: TimeInterval = 0

    func start() {
        _ = stats.cpuUsage()
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        sample()
    }

    func stop() {
        frameTimer?.invalidate()
        sampleTimer?.invalidate()
        frameTimer = nil
        sampleTimer = nil
    }

    private func sample() {
        cpu = stats.cpuUsage()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            frameTimer?.invalidate()
            frameTimer = nil
            interval = 0
            frame = 0
            return
        }
        var load = min(max(cpu, 0), 100) / 100
        if isBusy() { load = max(load, 0.5) }
        // 0% → a lazy 0.2 s per frame, 100% → 0.03 s.
        let next = 0.2 - 0.17 * load
        guard abs(next - interval) > 0.01 else { return }
        interval = next
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: next, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.frame = (self.frame + 1) % RunningCat.frameCount
            }
        }
    }
}
