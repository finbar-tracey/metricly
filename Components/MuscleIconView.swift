import SwiftUI

/// Custom anatomical muscle-group icons drawn with SwiftUI Canvas.
/// Each icon is designed to be readable from ~12pt upward.
struct MuscleIconView: View {
    let group: MuscleGroup
    var color: Color = .primary

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            ctx.translateBy(x: (size.width - s) / 2, y: (size.height - s) / 2)
            switch group {
            case .chest:      drawChest(ctx, s: s)
            case .back:       drawBack(ctx, s: s)
            case .shoulders:  drawShoulders(ctx, s: s)
            case .biceps:     drawBiceps(ctx, s: s)
            case .triceps:    drawTriceps(ctx, s: s)
            case .legs:       drawLegs(ctx, s: s)
            case .core:       drawCore(ctx, s: s)
            case .cardio:     drawCardio(ctx, s: s)
            case .other:      drawOther(ctx, s: s)
            }
        }
        .foregroundStyle(color)
    }

    // MARK: - Chest (two side-by-side pec arches)
    private func drawChest(_ ctx: GraphicsContext, s: CGFloat) {
        var ctx = ctx
        var left = Path()
        let cx = s * 0.5, cy = s * 0.52
        let rx = s * 0.28, ry = s * 0.38
        // Left pec — right half of an ellipse
        left.addArc(center: CGPoint(x: cx - s * 0.08, y: cy),
                    radius: rx, startAngle: .degrees(100), endAngle: .degrees(260), clockwise: false)
        left.closeSubpath()
        var right = Path()
        right.addArc(center: CGPoint(x: cx + s * 0.08, y: cy),
                     radius: rx, startAngle: .degrees(280), endAngle: .degrees(80), clockwise: false)
        right.closeSubpath()

        // Draw two overlapping filled ellipses clipped to each side
        let leftEllipse = Path(ellipseIn: CGRect(x: cx - s * 0.48, y: cy - ry, width: rx * 2, height: ry * 2))
        let rightEllipse = Path(ellipseIn: CGRect(x: cx - s * 0.08, y: cy - ry, width: rx * 2, height: ry * 2))
        ctx.fill(leftEllipse, with: .foreground)
        ctx.fill(rightEllipse, with: .foreground)

        // Central dividing notch — erase with background
        var notch = Path()
        notch.move(to: CGPoint(x: cx - s * 0.04, y: cy - ry * 0.6))
        notch.addLine(to: CGPoint(x: cx + s * 0.04, y: cy - ry * 0.6))
        notch.addLine(to: CGPoint(x: cx + s * 0.04, y: cy + ry * 0.6))
        notch.addLine(to: CGPoint(x: cx - s * 0.04, y: cy + ry * 0.6))
        notch.closeSubpath()
        ctx.blendMode = .clear
        ctx.fill(notch, with: .foreground)
        ctx.blendMode = .normal
    }

    // MARK: - Back (broad V-taper / lat spread)
    private func drawBack(_ ctx: GraphicsContext, s: CGFloat) {
        var ctx = ctx
        var path = Path()
        path.move(to: CGPoint(x: s * 0.10, y: s * 0.12))
        path.addLine(to: CGPoint(x: s * 0.90, y: s * 0.12))
        path.addCurve(to: CGPoint(x: s * 0.62, y: s * 0.88),
                      control1: CGPoint(x: s * 1.00, y: s * 0.50),
                      control2: CGPoint(x: s * 0.80, y: s * 0.88))
        path.addLine(to: CGPoint(x: s * 0.38, y: s * 0.88))
        path.addCurve(to: CGPoint(x: s * 0.10, y: s * 0.12),
                      control1: CGPoint(x: s * 0.20, y: s * 0.88),
                      control2: CGPoint(x: s * 0.00, y: s * 0.50))
        path.closeSubpath()
        ctx.fill(path, with: .foreground)

        // Spine line down the centre
        var spine = Path()
        spine.move(to: CGPoint(x: s * 0.5, y: s * 0.18))
        spine.addLine(to: CGPoint(x: s * 0.5, y: s * 0.82))
        ctx.blendMode = .clear
        ctx.stroke(spine, with: .foreground, lineWidth: s * 0.06)
        ctx.blendMode = .normal
    }

    // MARK: - Shoulders (three deltoid heads arranged in a curve)
    private func drawShoulders(_ ctx: GraphicsContext, s: CGFloat) {
        let r = s * 0.18
        let positions: [(CGFloat, CGFloat)] = [
            (0.18, 0.48),   // rear delt
            (0.50, 0.18),   // front delt (top)
            (0.82, 0.48),   // side delt
        ]
        for (fx, fy) in positions {
            let circle = Path(ellipseIn: CGRect(x: s * fx - r, y: s * fy - r, width: r * 2, height: r * 2))
            ctx.fill(circle, with: .foreground)
        }
        // Connecting arc
        var arc = Path()
        arc.move(to: CGPoint(x: s * 0.18, y: s * 0.48))
        arc.addCurve(to: CGPoint(x: s * 0.82, y: s * 0.48),
                     control1: CGPoint(x: s * 0.18, y: s * 0.10),
                     control2: CGPoint(x: s * 0.82, y: s * 0.10))
        ctx.stroke(arc, with: .foreground, lineWidth: s * 0.09)

        // Trapezius bar across top
        var trap = Path()
        trap.addRoundedRect(in: CGRect(x: s * 0.30, y: s * 0.68, width: s * 0.40, height: s * 0.20),
                            cornerSize: CGSize(width: s * 0.06, height: s * 0.06))
        ctx.fill(trap, with: .foreground)
    }

    // MARK: - Biceps (classic flex / mountain peak)
    private func drawBiceps(_ ctx: GraphicsContext, s: CGFloat) {
        var ctx = ctx
        // Outer arm silhouette
        var arm = Path()
        arm.move(to: CGPoint(x: s * 0.10, y: s * 0.90))
        arm.addCurve(to: CGPoint(x: s * 0.50, y: s * 0.12),
                     control1: CGPoint(x: s * 0.08, y: s * 0.55),
                     control2: CGPoint(x: s * 0.22, y: s * 0.12))
        arm.addCurve(to: CGPoint(x: s * 0.90, y: s * 0.90),
                     control1: CGPoint(x: s * 0.78, y: s * 0.12),
                     control2: CGPoint(x: s * 0.92, y: s * 0.55))
        arm.addLine(to: CGPoint(x: s * 0.73, y: s * 0.90))
        arm.addCurve(to: CGPoint(x: s * 0.27, y: s * 0.90),
                     control1: CGPoint(x: s * 0.73, y: s * 1.02),
                     control2: CGPoint(x: s * 0.27, y: s * 1.02))
        arm.closeSubpath()
        ctx.fill(arm, with: .foreground)

        // Highlight peak line
        var peak = Path()
        peak.move(to: CGPoint(x: s * 0.28, y: s * 0.52))
        peak.addCurve(to: CGPoint(x: s * 0.72, y: s * 0.52),
                      control1: CGPoint(x: s * 0.35, y: s * 0.28),
                      control2: CGPoint(x: s * 0.65, y: s * 0.28))
        ctx.blendMode = .clear
        ctx.stroke(peak, with: .foreground, lineWidth: s * 0.07)
        ctx.blendMode = .normal
    }

    // MARK: - Triceps (horseshoe / three heads)
    private func drawTriceps(_ ctx: GraphicsContext, s: CGFloat) {
        // Outer horseshoe shape
        var outer = Path()
        outer.move(to: CGPoint(x: s * 0.15, y: s * 0.15))
        outer.addLine(to: CGPoint(x: s * 0.15, y: s * 0.68))
        outer.addCurve(to: CGPoint(x: s * 0.85, y: s * 0.68),
                       control1: CGPoint(x: s * 0.15, y: s * 0.98),
                       control2: CGPoint(x: s * 0.85, y: s * 0.98))
        outer.addLine(to: CGPoint(x: s * 0.85, y: s * 0.15))
        outer.addLine(to: CGPoint(x: s * 0.70, y: s * 0.15))
        outer.addLine(to: CGPoint(x: s * 0.70, y: s * 0.62))
        outer.addCurve(to: CGPoint(x: s * 0.30, y: s * 0.62),
                       control1: CGPoint(x: s * 0.70, y: s * 0.82),
                       control2: CGPoint(x: s * 0.30, y: s * 0.82))
        outer.addLine(to: CGPoint(x: s * 0.30, y: s * 0.15))
        outer.closeSubpath()
        ctx.fill(outer, with: .foreground)
    }

    // MARK: - Legs (quad sweep — two teardrop shapes)
    private func drawLegs(_ ctx: GraphicsContext, s: CGFloat) {
        for side: CGFloat in [-1, 1] {
            let cx = s * 0.5 + side * s * 0.20
            var quad = Path()
            quad.move(to: CGPoint(x: cx, y: s * 0.08))
            quad.addCurve(to: CGPoint(x: cx + side * s * 0.16, y: s * 0.50),
                          control1: CGPoint(x: cx + side * s * 0.18, y: s * 0.08),
                          control2: CGPoint(x: cx + side * s * 0.22, y: s * 0.30))
            quad.addCurve(to: CGPoint(x: cx, y: s * 0.92),
                          control1: CGPoint(x: cx + side * s * 0.10, y: s * 0.72),
                          control2: CGPoint(x: cx + side * s * 0.04, y: s * 0.92))
            quad.addCurve(to: CGPoint(x: cx - side * s * 0.16, y: s * 0.50),
                          control1: CGPoint(x: cx - side * s * 0.04, y: s * 0.92),
                          control2: CGPoint(x: cx - side * s * 0.10, y: s * 0.72))
            quad.addCurve(to: CGPoint(x: cx, y: s * 0.08),
                          control1: CGPoint(x: cx - side * s * 0.22, y: s * 0.30),
                          control2: CGPoint(x: cx - side * s * 0.18, y: s * 0.08))
            quad.closeSubpath()
            ctx.fill(quad, with: .foreground)
        }
    }

    // MARK: - Core (six-pack grid of rounded rects)
    private func drawCore(_ ctx: GraphicsContext, s: CGFloat) {
        let cols = 2, rows = 3
        let gap: CGFloat = s * 0.08
        let w = (s - gap * 3) / CGFloat(cols)
        let h = (s - gap * 4) / CGFloat(rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let x = gap + CGFloat(col) * (w + gap)
                let y = gap + CGFloat(row) * (h + gap)
                let rect = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                                cornerRadius: s * 0.06)
                ctx.fill(rect, with: .foreground)
            }
        }
    }

    // MARK: - Cardio (heart shape)
    private func drawCardio(_ ctx: GraphicsContext, s: CGFloat) {
        var heart = Path()
        let cx = s * 0.5, ty = s * 0.28
        heart.move(to: CGPoint(x: cx, y: s * 0.88))
        heart.addCurve(to: CGPoint(x: s * 0.04, y: ty),
                       control1: CGPoint(x: s * 0.10, y: s * 0.72),
                       control2: CGPoint(x: s * 0.00, y: s * 0.45))
        heart.addArc(center: CGPoint(x: s * 0.27, y: ty),
                     radius: s * 0.23, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        heart.addArc(center: CGPoint(x: s * 0.73, y: ty),
                     radius: s * 0.23, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        heart.addCurve(to: CGPoint(x: cx, y: s * 0.88),
                       control1: CGPoint(x: s * 1.00, y: s * 0.45),
                       control2: CGPoint(x: s * 0.90, y: s * 0.72))
        ctx.fill(heart, with: .foreground)
    }

    // MARK: - Other (dumbbell)
    private func drawOther(_ ctx: GraphicsContext, s: CGFloat) {
        let bar = Path(roundedRect: CGRect(x: s * 0.18, y: s * 0.43, width: s * 0.64, height: s * 0.14),
                       cornerRadius: s * 0.04)
        ctx.fill(bar, with: .foreground)
        for side: CGFloat in [0, 1] {
            let x = side == 0 ? s * 0.04 : s * 0.68
            let plate = Path(roundedRect: CGRect(x: x, y: s * 0.22, width: s * 0.28, height: s * 0.56),
                             cornerRadius: s * 0.06)
            ctx.fill(plate, with: .foreground)
        }
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 24) {
        ForEach(MuscleGroup.allCases) { group in
            VStack(spacing: 6) {
                MuscleIconView(group: group, color: .accentColor)
                    .frame(width: 40, height: 40)
                Text(group.rawValue)
                    .font(.caption2)
            }
        }
    }
    .padding()
}
