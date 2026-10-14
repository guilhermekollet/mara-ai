import SwiftUI

/// Status and priority colors, the same as Linear's dark theme.
enum LinearPalette {
    static let backlog = Color(red: 0.58, green: 0.64, blue: 0.70)
    static let todo = Color(red: 0.89, green: 0.89, blue: 0.89)
    static let started = Color(red: 0.95, green: 0.79, blue: 0.30)
    static let review = Color(red: 0.30, green: 0.72, blue: 0.51)
    static let done = Color(red: 0.37, green: 0.42, blue: 0.82)
    static let urgent = Color(red: 0.98, green: 0.47, blue: 0.25)
    static let cardBorder = Color.white.opacity(0.08)
    static let card = Color.white.opacity(0.035)
    static let secondary = Color(red: 0.54, green: 0.56, blue: 0.60)
}

extension DemandStatus {
    var color: Color {
        switch self {
        case .backlog, .canceled: return LinearPalette.backlog
        case .todo: return LinearPalette.todo
        case .inProgress: return LinearPalette.started
        case .inReview: return LinearPalette.review
        case .done: return LinearPalette.done
        }
    }
}

/// Status icon drawn like Linear's: dashed circle (backlog), empty (to do), half filled
/// (in progress), three-quarters filled (in review), filled with a check mark (done)
/// and filled with an X (canceled).
struct StatusIcon: View {
    let status: DemandStatus
    var size: CGFloat = 14

    var body: some View {
        Canvas { context, canvas in
            let unit = canvas.width / 14
            let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            let ring = Path(ellipseIn: CGRect(x: unit, y: unit, width: 12 * unit, height: 12 * unit))
            let color = status.color

            switch status {
            case .backlog:
                context.stroke(ring, with: .color(color), style: StrokeStyle(lineWidth: 1.5 * unit, dash: [1.4 * unit, 1.74 * unit]))
            case .todo:
                context.stroke(ring, with: .color(color), lineWidth: 1.5 * unit)
            case .inProgress, .inReview:
                context.stroke(ring, with: .color(color), lineWidth: 1.5 * unit)
                var slice = Path()
                slice.move(to: center)
                slice.addArc(
                    center: center, radius: 3.5 * unit, startAngle: .degrees(-90),
                    endAngle: .degrees(status == .inProgress ? 90 : 180), clockwise: false
                )
                slice.closeSubpath()
                context.fill(slice, with: .color(color))
            case .done, .canceled:
                context.fill(Path(ellipseIn: CGRect(x: 0.25 * unit, y: 0.25 * unit, width: 13.5 * unit, height: 13.5 * unit)), with: .color(color))
                var mark = Path()
                if status == .done {
                    mark.move(to: CGPoint(x: 4.2 * unit, y: 7.2 * unit))
                    mark.addLine(to: CGPoint(x: 6.1 * unit, y: 9.1 * unit))
                    mark.addLine(to: CGPoint(x: 9.9 * unit, y: 5 * unit))
                } else {
                    mark.move(to: CGPoint(x: 4.8 * unit, y: 4.8 * unit))
                    mark.addLine(to: CGPoint(x: 9.2 * unit, y: 9.2 * unit))
                    mark.move(to: CGPoint(x: 9.2 * unit, y: 4.8 * unit))
                    mark.addLine(to: CGPoint(x: 4.8 * unit, y: 9.2 * unit))
                }
                context.stroke(mark, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 1.6 * unit, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Linear's priority icon: three bars (low, medium, high), three dashes (no priority)
/// or an orange square with an exclamation mark (urgent).
struct PriorityIcon: View {
    let priority: Int
    var size: CGFloat = 16

    var body: some View {
        Canvas { context, canvas in
            let unit = canvas.width / 16
            let light = Color(red: 0.89, green: 0.89, blue: 0.89)
            switch priority {
            case 1:
                let box = Path(roundedRect: CGRect(x: unit, y: unit, width: 14 * unit, height: 14 * unit), cornerRadius: 3 * unit)
                context.fill(box, with: .color(LinearPalette.urgent))
                var mark = Path()
                mark.move(to: CGPoint(x: 8 * unit, y: 4.2 * unit))
                mark.addLine(to: CGPoint(x: 8 * unit, y: 8.8 * unit))
                mark.move(to: CGPoint(x: 8 * unit, y: 11.4 * unit))
                mark.addLine(to: CGPoint(x: 8 * unit, y: 11.6 * unit))
                context.stroke(mark, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 1.8 * unit, lineCap: .round))
            case 2, 3, 4:
                // High lights all three bars, medium two, low one.
                let lit = 5 - priority
                for bar in 0..<3 {
                    let height = CGFloat(6 + bar * 3) * unit
                    let rect = CGRect(x: (1.5 + CGFloat(bar) * 5) * unit, y: 14 * unit - height, width: 3 * unit, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: unit), with: .color(light.opacity(bar < lit ? 1 : 0.3)))
                }
            default:
                for dash in 0..<3 {
                    let rect = CGRect(x: (1.5 + CGFloat(dash) * 5) * unit, y: 7.25 * unit, width: 3 * unit, height: 1.5 * unit)
                    context.fill(Path(roundedRect: rect, cornerRadius: 0.75 * unit), with: .color(light.opacity(0.55)))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// Round avatar with the assignee's initials; with no assignee, Linear's dashed outline.
struct AssigneeAvatar: View {
    let name: String
    var size: CGFloat = 18

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    /// Stable color per name, so the same person always gets the same avatar.
    private var tint: Color {
        let hues: [Double] = [0.72, 0.58, 0.45, 0.08, 0.95, 0.33]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Color(hue: hues[sum % hues.count], saturation: 0.45, brightness: 0.75)
    }

    var body: some View {
        if initials.isEmpty {
            Circle()
                .strokeBorder(LinearPalette.secondary, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: size, height: size)
                .overlay(Image(systemName: "person.fill").font(.system(size: size * 0.45)).foregroundStyle(LinearPalette.secondary))
        } else {
            Circle()
                .fill(tint)
                .frame(width: size, height: size)
                .overlay(Text(initials).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(Theme.ink))
        }
    }
}
