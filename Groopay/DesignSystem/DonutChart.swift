import SwiftUI

struct DonutChart: View {
    struct Segment: Identifiable, Equatable {
        let id = UUID()
        let color: Color
        let label: String
        let value: Int
    }

    let segments: [Segment]
    let centerText: String
    @Binding var selectedSegment: Int?

    private let chartSize: CGFloat = 200
    private let lineWidth: CGFloat = 28

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - lineWidth
                let total = max(segments.reduce(0) { $0 + $1.value }, 1)
                var startAngle = Angle.degrees(-90)

                for index in segments.indices {
                    let segment = segments[index]
                    let sweep = Angle.degrees(Double(segment.value) / Double(total) * 360)
                    let endAngle = startAngle + sweep
                    let midAngle = startAngle + Angle.degrees(sweep.degrees / 2)
                    let isSelected = selectedSegment == index
                    let offset = isSelected ? CGFloat(8) : 0
                    let offsetCenter = CGPoint(
                        x: center.x + cos(midAngle.radians) * offset,
                        y: center.y + sin(midAngle.radians) * offset
                    )

                    var path = Path()
                    path.addArc(
                        center: offsetCenter,
                        radius: radius,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: false
                    )
                    context.stroke(
                        path,
                        with: .color(segment.color),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                    startAngle = endAngle
                }
            }
            .frame(width: chartSize, height: chartSize)

            Circle()
                .fill(Color.surface)
                .frame(width: 108, height: 108)
                .purpleTintedShadow(radius: 8, y: 3)

            VStack(spacing: 3) {
                Text("Toplam")
                    .font(.body(11, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                Text(centerText)
                    .font(.display(17, weight: .extraBold))
                    .foregroundStyle(Color.textPrimary)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)
            }
            .frame(width: 92)
        }
        .frame(width: chartSize, height: chartSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    selectSegment(at: value.location)
                }
        )
        .animation(.spring(response: 0.35), value: selectedSegment)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Harcama Dağılımı"))
    }

    private func selectSegment(at point: CGPoint) {
        let center = CGPoint(x: chartSize / 2, y: chartSize / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance >= 44, distance <= chartSize / 2 + 10 else {
            selectedSegment = nil
            return
        }

        let total = max(segments.reduce(0) { $0 + $1.value }, 1)
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += .pi * 2 }
        let tappedDegrees = angle * 180 / .pi
        var current: Double = 0

        for index in segments.indices {
            let sweep = Double(segments[index].value) / Double(total) * 360
            if tappedDegrees >= current && tappedDegrees <= current + sweep {
                selectedSegment = selectedSegment == index ? nil : index
                return
            }
            current += sweep
        }
    }
}

#Preview {
    DonutChartPreview()
}

private struct DonutChartPreview: View {
    @State private var selected: Int?

    var body: some View {
        DonutChart(
            segments: [
                .init(color: .primaryTheme, label: "Market", value: 42),
                .init(color: .credit, label: "Yemek", value: 24),
                .init(color: .warning, label: "Ulaşım", value: 14)
            ],
            centerText: "₺2.180",
            selectedSegment: $selected
        )
        .padding()
        .background(Color.background)
    }
}
