import SwiftUI

let summaryWindowID = "summary"

/// The meeting summary in its own window: the kind of meeting, the overview, the topics as cards
/// and, when there are any, decisions, key points and open questions. It can be copied as
/// Markdown, saved, shared or found in Finder.
struct SummaryView: View {
    @EnvironmentObject private var model: CaptionModel
    /// Off only for the development tool: ImageRenderer doesn't draw a ScrollView's content.
    var scrolls = true

    var body: some View {
        Group {
            if let summary = model.summary {
                content(summary)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.document")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Theme.paper.opacity(0.35))
                    Text("Nenhum resumo ainda")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Ao fim de uma sessão, peça o resumo no painel da Mara.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 520, height: 640)
        .background(Theme.ink)
        .foregroundStyle(Theme.paper)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    private func content(_ summary: MeetingSummary) -> some View {
        VStack(spacing: 0) {
            scrolling {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            KindBadge(kind: summary.kind, label: summary.kindLabel)
                            if let details = model.summaryDetails {
                                Text(details)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        Text(summary.title)
                            .font(Theme.display(26))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(summary.overview)
                            .font(.system(size: 14))
                            .lineSpacing(3)
                            .foregroundStyle(Theme.paper.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !summary.topics.isEmpty {
                        SummarySection(title: summary.labels.topics, symbol: "text.bubble") {
                            VStack(spacing: 8) {
                                ForEach(Array(summary.topics.enumerated()), id: \.offset) { _, topic in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(topic.title)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(topic.summary)
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(Theme.paper.opacity(0.72))
                                            .lineSpacing(2)
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }
                    BulletSection(title: summary.labels.decisions, symbol: "checkmark.seal", items: summary.decisions)
                    BulletSection(title: summary.labels.keyPoints, symbol: "lightbulb", items: summary.keyPoints)
                    BulletSection(title: summary.labels.openQuestions, symbol: "questionmark.circle", items: summary.openQuestions)
                }
                .textSelection(.enabled)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Divider().overlay(Theme.paper.opacity(0.1))
            HStack(spacing: 8) {
                Button("Copiar") { model.copySummary() }
                    .buttonStyle(PillButtonStyle())
                Button("Salvar…") { model.saveSummaryAs() }
                    .buttonStyle(PillButtonStyle(prominent: false))
                if let markdown = model.summaryMarkdown {
                    ShareLink(item: markdown, subject: Text(summary.title)) {
                        Label("Compartilhar", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillButtonStyle(prominent: false))
                }
                Spacer()
                Button("Mostrar no Finder") { model.revealSummaryFile() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

extension SummaryView {
    /// Draws the window with a made-up conversation summary into a PNG (see `--render-summary`).
    @MainActor
    static func renderSample(to url: URL) {
        let model = CaptionModel()
        model.setSampleSummary(MeetingSummary(
            kind: .conversation,
            title: "Revisão do prazo e da demo",
            overview: "O time revisou o prazo da entrega e a apresentação para o cliente. Todos concordaram que a data atual é realista, e a proposta revisada sai antes da demo.",
            topics: [
                .init(title: "Prazo de entrega", summary: "Considerado realista pelo time; a data atual fica mantida."),
                .init(title: "Proposta revisada", summary: "Vai até quinta-feira, antes da demo para o cliente."),
                .init(title: "Números do trimestre", summary: "Ficaram para o fim da reunião, depois da demo."),
            ],
            decisions: ["Manter o prazo atual.", "Enviar a proposta antes da demo."],
            keyPoints: [],
            openQuestions: ["Quem apresenta a demo para o cliente?"]
        ))
        let renderer = ImageRenderer(content: SummaryView(scrolls: false).environmentObject(model))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}

extension SummaryView {
    @ViewBuilder
    fileprivate func scrolling<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if scrolls {
            ScrollView { content() }
        } else {
            content()
        }
    }
}

/// A labeled part of the summary, with an SF Symbol in the accent color.
private struct SummarySection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .labelStyle(AccentIconLabel())
            content
        }
    }
}

private struct BulletSection: View {
    let title: String
    let symbol: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            SummarySection(title: title, symbol: symbol) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            // Centered on the first line of 13 pt text.
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.paper.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct AccentIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(Theme.accent)
            configuration.title
        }
    }
}

/// "Conversation between several people" or "Presentation", as a small lavender capsule.
struct KindBadge: View {
    let kind: MeetingSummary.Kind
    let label: String

    var body: some View {
        Label(label, systemImage: kind == .conversation ? "person.2" : "person.wave.2")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Theme.accent.opacity(0.15), in: Capsule())
    }
}
