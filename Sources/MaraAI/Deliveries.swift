import Charts
import SwiftUI

let deliveriesWindowID = "deliveries"

/// A delivery: a task or issue completed by someone on a given day.
struct Delivery: Equatable {
    let date: Date
    let memberID: String
    let memberName: String
}

/// Chart series colors, in the palette's fixed order (validated for color blindness and contrast
/// against the app's dark background). The ninth person onwards goes into "Outros", in gray.
enum SeriesPalette {
    static let colors: [Color] = [
        Color(red: 0.22, green: 0.53, blue: 0.90), // blue
        Color(red: 0.85, green: 0.35, blue: 0.15), // orange
        Color(red: 0.10, green: 0.62, blue: 0.44), // aqua
        Color(red: 0.79, green: 0.52, blue: 0.00), // yellow
        Color(red: 0.84, green: 0.32, blue: 0.51), // magenta
        Color(red: 0.00, green: 0.51, blue: 0.00), // green
        Color(red: 0.56, green: 0.52, blue: 0.91), // violet
        Color(red: 0.90, green: 0.40, blue: 0.40), // red
    ]
    static let other = Color(red: 0.45, green: 0.47, blue: 0.50)
    static let otherID = "outros"
}

/// A person in the chart, with their fixed color and their total for the period.
struct DeliveryMember: Identifiable {
    let id: String
    let name: String
    let color: Color
    let total: Int
}

/// How many deliveries a person made in a period (day or week).
struct DeliveryCell: Identifiable {
    let bucket: Date
    let member: DeliveryMember
    let count: Int
    var id: String { "\(bucket.timeIntervalSince1970)-\(member.id)" }
}

/// Groups deliveries by period and by person. Used by the Deliveries window and by the panel's
/// small chart, so both show the same colors for the same people.
struct DeliveryBreakdown {
    let deliveries: [Delivery]
    let byWeek: Bool
    let periods: Int

    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // weeks start on Monday
        return calendar
    }

    func bucket(for date: Date) -> Date {
        let calendar = Self.calendar
        return byWeek ? (calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date) : calendar.startOfDay(for: date)
    }

    /// The periods shown, from oldest to newest, including empty ones.
    var buckets: [Date] {
        let now = bucket(for: Date())
        return (0..<periods).reversed().compactMap {
            Self.calendar.date(byAdding: byWeek ? .weekOfYear : .day, value: -$0, to: now)
        }
    }

    private var visible: [Delivery] {
        guard let first = buckets.first else { return [] }
        return deliveries.filter { $0.date >= first }
    }

    /// Everyone in the loaded history, in alphabetical order: this order determines each person's
    /// color, so the color follows the person and does not change with the selected period.
    private var ordered: [(key: String, value: String)] {
        var names: [String: String] = [:]
        for delivery in deliveries { names[delivery.memberID] = delivery.memberName }
        return names.sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
    }

    private func slot(for memberID: String, in ordered: [(key: String, value: String)]) -> String {
        let index = ordered.firstIndex { $0.key == memberID } ?? Int.max
        return index < SeriesPalette.colors.count ? memberID : SeriesPalette.otherID
    }

    var members: [DeliveryMember] {
        let ordered = ordered
        var totals: [String: Int] = [:]
        for delivery in visible { totals[slot(for: delivery.memberID, in: ordered), default: 0] += 1 }
        var result = ordered.prefix(SeriesPalette.colors.count).enumerated().map { index, entry in
            DeliveryMember(id: entry.key, name: entry.value, color: SeriesPalette.colors[index], total: totals[entry.key] ?? 0)
        }
        if ordered.count > SeriesPalette.colors.count {
            result.append(DeliveryMember(id: SeriesPalette.otherID, name: "Outros", color: SeriesPalette.other, total: totals[SeriesPalette.otherID] ?? 0))
        }
        return result
    }

    var cells: [DeliveryCell] {
        let ordered = ordered
        let members = members
        var counts: [Date: [String: Int]] = [:]
        for delivery in visible {
            counts[bucket(for: delivery.date), default: [:]][slot(for: delivery.memberID, in: ordered), default: 0] += 1
        }
        return buckets.flatMap { bucket in
            members.compactMap { member in
                let count = counts[bucket]?[member.id] ?? 0
                return count > 0 ? DeliveryCell(bucket: bucket, member: member, count: count) : nil
            }
        }
    }
}

/// Miniature of the team's daily deliveries, for the menu bar panel: stacked bars for the
/// last 14 days, one color per person, with a legend of the top contributors. Clicking opens the window.
struct DeliveriesMiniChart: View {
    @EnvironmentObject private var model: CaptionModel
    let action: () -> Void

    var body: some View {
        let breakdown = DeliveryBreakdown(deliveries: model.deliveries, byWeek: false, periods: 14)
        let cells = breakdown.cells
        let leaders = breakdown.members.filter { $0.total > 0 }.sorted { $0.total > $1.total }
        let today = cells.filter { $0.bucket == breakdown.buckets.last }.reduce(0) { $0 + $1.count }

        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Entregas por dia")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("hoje \(today)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                if cells.isEmpty {
                    Text(model.isLoadingDeliveries ? "Carregando as entregas…" : "Nenhuma entrega nos últimos 14 dias.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.paper.opacity(0.4))
                        .frame(maxWidth: .infinity, minHeight: 58, alignment: .center)
                } else {
                    Chart(cells) { cell in
                        BarMark(
                            x: .value("Dia", cell.bucket, unit: .day, calendar: DeliveryBreakdown.calendar),
                            y: .value("Entregas", cell.count),
                            width: .ratio(0.66)
                        )
                        .foregroundStyle(cell.member.color)
                    }
                    .chartXScale(domain: (breakdown.buckets.first ?? Date())...(Calendar.current.date(byAdding: .day, value: 1, to: breakdown.buckets.last ?? Date()) ?? Date()))
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .frame(height: 58)
                    .animation(.easeOut(duration: 0.3), value: cells.map(\.count))
                    // Legend: the four people who delivered the most in the period.
                    HStack(spacing: 10) {
                        ForEach(leaders.prefix(4)) { member in
                            HStack(spacing: 4) {
                                Circle().fill(member.color).frame(width: 6, height: 6)
                                Text(member.name.split(separator: " ").first.map(String.init) ?? member.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.paper.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                        if leaders.count > 4 {
                            Text("+\(leaders.count - 4)")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(10)
            .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Abrir as entregas por pessoa, por dia e por semana")
    }
}

/// Deliveries per person, by day or by week, as stacked bars: each person is one color.
struct DeliveriesView: View {
    @EnvironmentObject private var model: CaptionModel
    @State private var byWeek = false
    @State private var selected: Date?

    private typealias Member = DeliveryMember
    private typealias Cell = DeliveryCell

    private var breakdown: DeliveryBreakdown {
        DeliveryBreakdown(deliveries: model.deliveries, byWeek: byWeek, periods: byWeek ? 8 : 14)
    }
    private var calendar: Calendar { DeliveryBreakdown.calendar }
    private func bucket(for date: Date) -> Date { breakdown.bucket(for: date) }
    private var buckets: [Date] { breakdown.buckets }
    private var members: [Member] { breakdown.members }
    private var cells: [Cell] { breakdown.cells }

    var body: some View {
        let members = members
        let cells = cells
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Entregas")
                    .font(Theme.display(26))
                Spacer()
                if model.isLoadingDeliveries {
                    ProgressView().controlSize(.small)
                }
                // Period filter, on a row above the chart.
                HStack(spacing: 2) {
                    period("Por dia", active: !byWeek) { byWeek = false }
                    period("Por semana", active: byWeek) { byWeek = true }
                }
                .padding(3)
                .background(Theme.paper.opacity(0.07), in: Capsule())
            }

            Text(model.linearReady
                ? "Issues concluídas no Linear por pessoa, \(byWeek ? "nas últimas 8 semanas" : "nos últimos 14 dias")."
                : "Conecte o Linear em Ajustes para ver as entregas do time.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)

            if let error = model.deliveriesError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
            }

            if cells.isEmpty {
                Text(model.isLoadingDeliveries ? "Carregando as entregas…" : "Nenhuma entrega neste período.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                chart(cells: cells, members: members)
                    .frame(height: 250)
            }

            // Always-visible legend, in two columns, with each person's total: it also works
            // as a table. Hovering over a bar replaces the total with that period's count.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible())], spacing: 0) {
                ForEach(members.filter { $0.total > 0 }) { member in
                    let inSelection = selected.map { bucket in
                        cells.first { $0.bucket == bucket && $0.member.id == member.id }?.count ?? 0
                    }
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(member.color)
                            .frame(width: 11, height: 11)
                        Text(member.name)
                            .font(.system(size: 12.5))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(inSelection ?? member.total)")
                            .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(inSelection == 0 ? Theme.muted : Theme.paper)
                    }
                    .padding(.vertical, 7)
                    .overlay(alignment: .bottom) { Divider().overlay(Theme.paper.opacity(0.08)) }
                }
            }
            Text(selected.map { "Entregas em \(label($0))\(byWeek ? " (semana)" : "")." } ?? "Total no período. Passe o mouse numa barra para ver um \(byWeek ? "semana" : "dia") só.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.paper.opacity(0.45))
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(width: 560, height: 600, alignment: .topLeading)
        .background(Theme.ink)
        .foregroundStyle(Theme.paper)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task { await model.loadDeliveries(force: true) }
        .onChange(of: byWeek) { selected = nil }
    }

    private func chart(cells: [Cell], members: [Member]) -> some View {
        Chart {
            ForEach(cells) { cell in
                BarMark(
                    x: .value("Período", cell.bucket, unit: byWeek ? .weekOfYear : .day, calendar: calendar),
                    y: .value("Entregas", cell.count),
                    width: .ratio(0.62)
                )
                .foregroundStyle(cell.member.color)
                .opacity(selected == nil || selected == cell.bucket ? 1 : 0.35)
            }
            // A hairline in the background color separates the stacked segments, so two neighboring
            // colors never touch.
            ForEach(seams(in: cells), id: \.id) { seam in
                RuleMark(
                    xStart: .value("Início", seam.bucket),
                    xEnd: .value("Fim", calendar.date(byAdding: byWeek ? .weekOfYear : .day, value: 1, to: seam.bucket) ?? seam.bucket),
                    y: .value("Entregas", seam.level)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Theme.ink)
            }
            if let selected {
                // Hover tooltip: the period's total; the per-person breakdown appears in the legend.
                RuleMark(x: .value("Período", selected, unit: byWeek ? .weekOfYear : .day, calendar: calendar))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        let total = cells.filter { $0.bucket == selected }.reduce(0) { $0 + $1.count }
                        Text("\(label(selected)) · \(total) \(total == 1 ? "entrega" : "entregas")")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.paper.opacity(0.14), in: Capsule())
                    }
            }
        }
        .chartXScale(domain: (buckets.first ?? Date())...(calendar.date(byAdding: byWeek ? .weekOfYear : .day, value: 1, to: buckets.last ?? Date()) ?? Date()))
        .chartXAxis {
            AxisMarks(values: buckets) { value in
                if let date = value.as(Date.self), byWeek || calendar.component(.day, from: date) % 2 == 0 {
                    AxisValueLabel(centered: true) {
                        Text(label(date))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Theme.paper.opacity(0.08))
                AxisValueLabel {
                    if let count = value.as(Int.self) {
                        Text("\(count)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            guard let plot = proxy.plotFrame else { return }
                            let x = location.x - geometry[plot].origin.x
                            if let date: Date = proxy.value(atX: x) {
                                let hovered = bucket(for: date)
                                selected = buckets.contains(hovered) ? hovered : nil
                            }
                        case .ended:
                            selected = nil
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.25), value: byWeek)
    }

    /// Heights at which one segment ends and the next begins, in each bar.
    private func seams(in cells: [Cell]) -> [(id: String, bucket: Date, level: Int)] {
        var result: [(id: String, bucket: Date, level: Int)] = []
        for bucket in buckets {
            var level = 0
            let stack = cells.filter { $0.bucket == bucket }
            for cell in stack.dropLast() {
                level += cell.count
                result.append(("\(bucket.timeIntervalSince1970)-\(level)", bucket, level))
            }
        }
        return result
    }

    private func label(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.twoDigits).locale(Locale(identifier: "pt_BR")))
    }

    private func period(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Theme.ink : Theme.paper.opacity(0.75))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(active ? Theme.accent : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension DeliveriesView {
    /// Draws the window with made-up deliveries from ten people (to exercise "Outros").
    @MainActor
    static func renderSample(to url: URL) {
        let names = ["Ana Lima", "Bruno Reis", "Carla Dias", "Diego Faro", "Elisa Mota", "Fábio Nunes", "Gabi Prado", "Hugo Sá", "Iara Luz", "João Vaz"]
        var sample: [Delivery] = []
        var seed: UInt64 = 42
        func next(_ bound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 33) % UInt64(bound))
        }
        for day in 0..<56 {
            guard let date = Calendar.current.date(byAdding: .day, value: -day, to: Date()) else { continue }
            if Calendar.current.isDateInWeekend(date) { continue }
            for (index, name) in names.enumerated() {
                for _ in 0..<next(index < 4 ? 4 : 2) {
                    sample.append(Delivery(date: date, memberID: name, memberName: name))
                }
            }
        }
        let model = CaptionModel()
        model.setSampleDeliveries(sample)
        let renderer = ImageRenderer(content: DeliveriesView().environmentObject(model))
        renderer.scale = 2
        write(renderer.nsImage, to: url)
        // The panel's small chart, at the panel's width and on the same background.
        let mini = ImageRenderer(content: DeliveriesMiniChart(action: {}).environmentObject(model)
            .frame(width: 272).padding(14).background(Theme.ink).foregroundStyle(Theme.paper).preferredColorScheme(.dark))
        mini.scale = 2
        write(mini.nsImage, to: url.deletingPathExtension().appendingPathExtension("mini.png"))
    }

    private static func write(_ image: NSImage?, to url: URL) {
        guard let image, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
