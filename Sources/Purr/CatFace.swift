import SwiftUI

enum CatMood {
    case happy, okay, sad, busy, done, blink
}

/// A round, chubby cat face drawn on a 100×100 grid.
struct CatFace: View {
    var mood: CatMood
    /// Single-colour silhouette for the menu bar (eyes and nose knocked out).
    var template = false

    private let fur = Color(red: 1.00, green: 0.76, blue: 0.48)
    private let furDark = Color(red: 0.96, green: 0.58, blue: 0.27)
    private let pink = Color(red: 1.00, green: 0.62, blue: 0.70)
    private let ink = Color(red: 0.24, green: 0.17, blue: 0.15)

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 100, y: size.height / 100)
            template ? drawTemplate(&ctx) : drawFull(&ctx)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Full colour

    private func drawFull(_ ctx: inout GraphicsContext) {
        // Ears
        ctx.fill(ear(left: true), with: .color(furDark))
        ctx.fill(ear(left: false), with: .color(furDark))
        ctx.fill(innerEar(left: true), with: .color(pink))
        ctx.fill(innerEar(left: false), with: .color(pink))

        // Head
        ctx.fill(head, with: .linearGradient(Gradient(colors: [fur, furDark.opacity(0.9)]),
                                             startPoint: CGPoint(x: 50, y: 25), endPoint: CGPoint(x: 50, y: 95)))
        // Lighter muzzle
        ctx.fill(Path(ellipseIn: CGRect(x: 32, y: 60, width: 36, height: 26)),
                 with: .color(.white.opacity(0.55)))

        // Forehead stripes
        for (x, h) in [(42.0, 9.0), (50.0, 12.0), (58.0, 9.0)] {
            var p = Path()
            p.move(to: CGPoint(x: x, y: 30))
            p.addLine(to: CGPoint(x: x, y: 30 + h))
            ctx.stroke(p, with: .color(furDark), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }

        // Cheeks
        let blush = mood == .sad ? 0.35 : 0.7
        ctx.fill(Path(ellipseIn: CGRect(x: 15, y: 63, width: 15, height: 9)), with: .color(pink.opacity(blush)))
        ctx.fill(Path(ellipseIn: CGRect(x: 70, y: 63, width: 15, height: 9)), with: .color(pink.opacity(blush)))

        drawEyes(&ctx)
        drawNoseAndMouth(&ctx)

        // Whiskers
        for side in [-1.0, 1.0] {
            for (i, dy) in [-3.0, 2.0].enumerated() {
                var p = Path()
                let x0 = 50 + side * 22
                p.move(to: CGPoint(x: x0, y: 70 + dy))
                p.addLine(to: CGPoint(x: 50 + side * (40 + Double(i) * 2), y: 66 + dy * 2.2))
                ctx.stroke(p, with: .color(ink.opacity(0.35)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
        }
    }

    private func drawEyes(_ ctx: inout GraphicsContext) {
        let centers = [CGPoint(x: 36, y: 54), CGPoint(x: 64, y: 54)]
        let line = StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)

        switch mood {
        case .happy, .done:
            // ^ ^ smiling eyes
            for c in centers {
                var p = Path()
                p.move(to: CGPoint(x: c.x - 6, y: c.y + 2))
                p.addQuadCurve(to: CGPoint(x: c.x + 6, y: c.y + 2), control: CGPoint(x: c.x, y: c.y - 8))
                ctx.stroke(p, with: .color(ink), style: line)
            }
        case .blink:
            for c in centers {
                var p = Path()
                p.move(to: CGPoint(x: c.x - 6, y: c.y))
                p.addQuadCurve(to: CGPoint(x: c.x + 6, y: c.y), control: CGPoint(x: c.x, y: c.y + 6))
                ctx.stroke(p, with: .color(ink), style: line)
            }
        case .okay, .sad, .busy:
            let shift: CGFloat = mood == .busy ? 2 : 0
            for c in centers {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 8, width: 14, height: 16)), with: .color(ink))
                // Sparkly highlights
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 1 + shift, y: c.y - 6, width: 6, height: 6)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4 + shift, y: c.y + 2, width: 3, height: 3)), with: .color(.white.opacity(0.9)))
            }
            if mood == .sad {
                // Worried brows and a tear
                for (c, dir) in zip(centers, [1.0, -1.0]) {
                    var b = Path()
                    b.move(to: CGPoint(x: c.x - 6 * dir, y: c.y - 12))
                    b.addLine(to: CGPoint(x: c.x + 5 * dir, y: c.y - 16))
                    ctx.stroke(b, with: .color(ink.opacity(0.7)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
                var tear = Path()
                tear.move(to: CGPoint(x: 70, y: 62))
                tear.addQuadCurve(to: CGPoint(x: 70, y: 72), control: CGPoint(x: 76, y: 70))
                tear.addQuadCurve(to: CGPoint(x: 70, y: 62), control: CGPoint(x: 64, y: 70))
                ctx.fill(tear, with: .color(Color(red: 0.45, green: 0.72, blue: 1.0)))
            }
            if mood == .busy {
                sparkle(&ctx, at: CGPoint(x: 86, y: 30), size: 7)
            }
        }
        if mood == .done {
            sparkle(&ctx, at: CGPoint(x: 14, y: 32), size: 6)
            sparkle(&ctx, at: CGPoint(x: 87, y: 28), size: 8)
        }
    }

    private func drawNoseAndMouth(_ ctx: inout GraphicsContext) {
        var nose = Path()
        nose.move(to: CGPoint(x: 46.5, y: 63))
        nose.addQuadCurve(to: CGPoint(x: 53.5, y: 63), control: CGPoint(x: 50, y: 61))
        nose.addQuadCurve(to: CGPoint(x: 50, y: 67.5), control: CGPoint(x: 53, y: 66))
        nose.addQuadCurve(to: CGPoint(x: 46.5, y: 63), control: CGPoint(x: 47, y: 66))
        ctx.fill(nose, with: .color(pink))

        let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        var mouth = Path()
        if mood == .sad {
            mouth.move(to: CGPoint(x: 45, y: 75))
            mouth.addQuadCurve(to: CGPoint(x: 55, y: 75), control: CGPoint(x: 50, y: 70))
            ctx.stroke(mouth, with: .color(ink), style: style)
            return
        }
        // ω
        mouth.move(to: CGPoint(x: 43, y: 69.5))
        mouth.addQuadCurve(to: CGPoint(x: 50, y: 68), control: CGPoint(x: 46, y: 75))
        mouth.addQuadCurve(to: CGPoint(x: 57, y: 69.5), control: CGPoint(x: 54, y: 75))
        ctx.stroke(mouth, with: .color(ink), style: style)

        if mood == .happy || mood == .done || mood == .busy {
            // Tiny open mouth with tongue
            let m = Path(ellipseIn: CGRect(x: 46.5, y: 71, width: 7, height: mood == .busy ? 7 : 5))
            ctx.fill(m, with: .color(Color(red: 0.55, green: 0.2, blue: 0.22)))
            ctx.fill(Path(ellipseIn: CGRect(x: 47.5, y: mood == .busy ? 74.5 : 73.5, width: 5, height: 3)), with: .color(pink))
        }
    }

    private func sparkle(_ ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat) {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s))
        p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: c)
        ctx.fill(p, with: .color(Color(red: 1.0, green: 0.82, blue: 0.2)))
    }

    // MARK: Menu bar silhouette

    private func drawTemplate(_ ctx: inout GraphicsContext) {
        ctx.fill(ear(left: true), with: .color(.black))
        ctx.fill(ear(left: false), with: .color(.black))
        ctx.fill(head, with: .color(.black))

        ctx.blendMode = .destinationOut
        let style = StrokeStyle(lineWidth: 7, lineCap: .round)
        for x in [36.0, 64.0] {
            if mood == .busy {
                var p = Path()
                p.move(to: CGPoint(x: x - 7, y: 58))
                p.addQuadCurve(to: CGPoint(x: x + 7, y: 58), control: CGPoint(x: x, y: 47))
                ctx.stroke(p, with: .color(.black), style: style)
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: x - 7, y: 46, width: 14, height: 17)), with: .color(.black))
            }
        }
        ctx.fill(Path(ellipseIn: CGRect(x: 44, y: 64, width: 12, height: 8)), with: .color(.black))
    }

    // MARK: Shapes

    private var head: Path {
        Path(roundedRect: CGRect(x: 8, y: 24, width: 84, height: 70), cornerRadius: 36)
    }

    private func ear(left: Bool) -> Path {
        let flip: (CGFloat) -> CGFloat = { left ? $0 : 100 - $0 }
        var p = Path()
        p.move(to: CGPoint(x: flip(12), y: 46))
        p.addQuadCurve(to: CGPoint(x: flip(20), y: 6), control: CGPoint(x: flip(8), y: 18))
        p.addQuadCurve(to: CGPoint(x: flip(46), y: 28), control: CGPoint(x: flip(30), y: 10))
        p.closeSubpath()
        return p
    }

    private func innerEar(left: Bool) -> Path {
        let flip: (CGFloat) -> CGFloat = { left ? $0 : 100 - $0 }
        var p = Path()
        p.move(to: CGPoint(x: flip(18), y: 38))
        p.addQuadCurve(to: CGPoint(x: flip(22), y: 14), control: CGPoint(x: flip(16), y: 22))
        p.addQuadCurve(to: CGPoint(x: flip(38), y: 28), control: CGPoint(x: flip(30), y: 16))
        p.closeSubpath()
        return p
    }
}

extension CatFace {
    /// Menu bar icon rendered as a template image so it follows light/dark menu bars.
    @MainActor static func menuBarImage(busy: Bool) -> NSImage {
        let renderer = ImageRenderer(content: CatFace(mood: busy ? .busy : .okay, template: true).frame(width: 18, height: 18))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "cat.fill", accessibilityDescription: nil)!
        image.isTemplate = true
        return image
    }
}
