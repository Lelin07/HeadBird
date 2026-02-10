import SwiftUI

struct MotionHistoryGraph: View {
    enum GraphStyle: String, CaseIterable, Identifiable {
        case lines = "Lines"
        case area = "Area"
        case dots = "Dots"

        var id: String { rawValue }
    }

    let samples: [MotionHistorySample]
    let sensitivity: Double
    let style: GraphStyle
    let showGrid: Bool

    private let maxDegrees: Double = 35
    private let pitchColor = Color.blue
    private let rollColor = Color.orange
    private let yawColor = Color.green

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                if showGrid {
                    drawGrid(in: &context, size: size)
                }
                guard samples.count > 1 else { return }

                let pitchPath = path(for: samples, size: size) { normalized($0.pose.pitch) }
                let rollPath = path(for: samples, size: size) { normalized($0.pose.roll) }
                let yawPath = path(for: samples, size: size) { normalized($0.pose.yaw) }

                switch style {
                case .lines:
                    context.stroke(pitchPath, with: .color(pitchColor.opacity(0.9)), lineWidth: 1.6)
                    context.stroke(rollPath, with: .color(rollColor.opacity(0.85)), lineWidth: 1.4)
                    context.stroke(yawPath, with: .color(yawColor.opacity(0.8)), lineWidth: 1.4)
                case .area:
                    fillArea(path: pitchPath, in: &context, size: size, color: pitchColor)
                    fillArea(path: rollPath, in: &context, size: size, color: rollColor)
                    fillArea(path: yawPath, in: &context, size: size, color: yawColor)
                case .dots:
                    drawDots(for: samples, in: &context, size: size, color: pitchColor) { normalized($0.pose.pitch) }
                    drawDots(for: samples, in: &context, size: size, color: rollColor) { normalized($0.pose.roll) }
                    drawDots(for: samples, in: &context, size: size, color: yawColor) { normalized($0.pose.yaw) }
                }
            }
        }
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private func path(for samples: [MotionHistorySample], size: CGSize, value: (MotionHistorySample) -> Double) -> Path {
        var path = Path()
        let count = samples.count
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) / CGFloat(max(count - 1, 1)) * size.width
            let y = size.height / 2 - CGFloat(value(sample)) * (size.height / 2)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }

    private func normalized(_ radians: Double) -> Double {
        let degrees = radians * sensitivity * 180.0 / .pi
        let clamped = max(-maxDegrees, min(maxDegrees, degrees))
        return clamped / maxDegrees
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        let lines: Int = 3
        for i in 1..<lines {
            let y = CGFloat(i) / CGFloat(lines) * size.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
        }

        let columns: Int = 4
        for i in 1..<columns {
            let x = CGFloat(i) / CGFloat(columns) * size.width
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(.secondary.opacity(0.12)), lineWidth: 1)
        }
    }

    private func fillArea(path: Path, in context: inout GraphicsContext, size: CGSize, color: Color) {
        var area = path
        area.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        area.addLine(to: CGPoint(x: 0, y: size.height / 2))
        area.closeSubpath()
        context.fill(area, with: .color(color.opacity(0.18)))
        context.stroke(path, with: .color(color.opacity(0.75)), lineWidth: 1.3)
    }

    private func drawDots(
        for samples: [MotionHistorySample],
        in context: inout GraphicsContext,
        size: CGSize,
        color: Color,
        value: (MotionHistorySample) -> Double
    ) {
        let count = samples.count
        guard count > 1 else { return }
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) / CGFloat(max(count - 1, 1)) * size.width
            let y = size.height / 2 - CGFloat(value(sample)) * (size.height / 2)
            let rect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.85)))
        }
    }
}
