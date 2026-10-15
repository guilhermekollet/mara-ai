import SwiftUI

/// Panel that opens when the menu bar icon is clicked. From top to bottom: the captions
/// session, the meeting summary (when there is one) and the work in progress.
struct MenuBarPanel: View {
    @EnvironmentObject private var model: CaptionModel
    @Environment(\.openWindow) private var openWindow
    /// The summary's details take part in the layout…
    @State private var summaryExpanded = false
    /// …and fade in and out on their own, so the menu bar window never resizes during an animation
    /// (animated window resizing has crashed AppKit on macOS 26; see SettingsView).
    @State private var detailsShown = false
    @AppStorage(Onboarding.doneKey) private var onboardingDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !onboardingDone && !model.isRunning {
                setupCard
            }
            if model.isRunning || !model.segments.isEmpty || !model.status.isEmpty {
                liveCard
            }
            if !model.segments.isEmpty && !model.isRunning {
                summarySection
            }
            Divider().overlay(Theme.paper.opacity(0.12))
            footer
        }
        .padding(14)
        .frame(width: 300)
        .background(Theme.ink)
        .foregroundStyle(Theme.paper)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task {
            await model.loadLocales()
        }
    }

    /// Logo, session state and the main controls on a single row.
    private var header: some View {
        HStack(spacing: 6) {
            Image(nsImage: Theme.menuBarIcon)
                .renderingMode(.template)
            // During a session the name gives way to the timer, so everything fits on one row.
            if !model.isRunning {
                Text("Mara")
                    .font(Theme.display(19))
            }
            if model.isRunning, let start = model.sessionStart {
                Text(start, style: .timer)
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                if model.isIdle {
                    IdleBadge()
                } else {
                    SoundBars(meter: model.audioMeter, height: 11)
                }
            }
            Spacer(minLength: 4)
            LanguageMenu()
            ChipToggle(symbol: "sparkles", help: "Refinar a tradução com o GPT", isOn: $model.useGPT)
            Button(model.isRunning ? "Parar" : "Iniciar") {
                if !model.isRunning { showCaptions() }
                model.toggle()
            }
            .buttonStyle(PillButtonStyle(prominent: !model.isRunning))
            .disabled(model.isStarting)
        }
    }

    /// Shown until the introduction is finished, to pick it up where it stopped.
    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Termine a configuração")
                .font(.system(size: 13, weight: .semibold))
            Text("Falta pouco: a permissão de áudio e o idioma da reunião.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Button("Continuar") { open(onboardingWindowID) }
                .buttonStyle(PillButtonStyle())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// The latest utterance, to follow the meeting without opening the captions window.
    private var liveCard: some View {
        let provisional = !model.volatileTranslation.isEmpty
        let confirmed = model.segments.last.map { $0.translation ?? $0.original }
        let text = provisional ? model.volatileTranslation : (model.volatile.isEmpty ? confirmed : model.volatile)
        return VStack(alignment: .leading, spacing: 6) {
            if let text {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(provisional ? Theme.accent : Theme.paper)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.isIdle {
                IdleBadge(large: true)
            } else if model.isRunning {
                SoundBars(meter: model.audioMeter, height: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(Theme.paper.opacity(0.45))
                    .lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// After a session: the button to summarize it, and then the summary at a glance, with the
    /// full version in its own window.
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = model.summary {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(summary.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                }
                KindBadge(kind: summary.kind, label: summary.kindLabel)
                Text(summary.overview)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.paper.opacity(0.8))
                    .lineLimit(summaryExpanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
                if summaryExpanded {
                    SummaryDetails(summary: summary)
                        .opacity(detailsShown ? 1 : 0)
                        .offset(y: detailsShown ? 0 : -6)
                }
                HStack(spacing: 8) {
                    Button("Abrir resumo") { open(summaryWindowID) }
                        .buttonStyle(PillButtonStyle())
                    Button("Copiar") { model.copySummary() }
                        .buttonStyle(PillButtonStyle(prominent: false))
                    Spacer(minLength: 0)
                    Button {
                        setSummaryExpanded(!summaryExpanded)
                    } label: {
                        HStack(spacing: 4) {
                            Text(summaryExpanded ? "Mostrar menos" : "Mostrar mais")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .rotationEffect(.degrees(detailsShown ? 180 : 0))
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(summaryExpanded ? "Ocultar os detalhes do resumo" : "Mostrar os assuntos, as decisões e as perguntas em aberto")
                }
            } else if model.isSummarizing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Resumindo a reunião…")
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Button("Resumir reunião") {
                    model.openSummary = { present(summaryWindowID, using: openWindow) }
                    model.summarize()
                }
                .buttonStyle(PillButtonStyle())
                .disabled(!model.canSummarize)
                Text(model.apiKey.isEmpty
                    ? "O resumo usa o GPT: adicione sua chave da OpenAI em Ajustes."
                    : "Envia a transcrição desta sessão à OpenAI.")
                    .font(.caption)
                    .foregroundStyle(Theme.paper.opacity(0.45))
            }
            if let error = model.summaryError {
                Text("Não foi possível resumir: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    /// Expanding makes room for the details in one step and then fades them in, sliding down a
    /// little; collapsing fades them out first and only then gives the room back.
    private func setSummaryExpanded(_ expand: Bool) {
        if expand {
            summaryExpanded = true
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { detailsShown = true }
            }
        } else {
            withAnimation(.easeIn(duration: 0.16)) {
                detailsShown = false
            } completion: {
                summaryExpanded = false
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            link("Legendas") { showCaptions() }
            link("Arquivos") { model.openTranscriptsFolder() }
            link("Ajustes") { open(settingsWindowID) }
            Spacer()
            if model.gptEnabled {
                UsageLine(ledger: model.usage)
            }
            link("Sair") { NSApp.terminate(nil) }
        }
        .font(.system(size: 11.5))
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(Theme.muted)
    }

    private func open(_ window: String) {
        present(window, using: openWindow)
    }

    private func showCaptions() {
        model.openCaptions = { openWindow(id: captionsWindowID) }
        model.showCaptions()
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Icon-shaped toggle: lavender when on.
private struct ChipToggle: View {
    let symbol: String
    let help: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(isOn ? Theme.ink : Theme.paper.opacity(0.6))
                .frame(width: 22, height: 22)
                .background(isOn ? Theme.accent : Theme.paper.opacity(0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help + (isOn ? " (ligado)" : " (desligado)"))
    }
}

/// The summary's details inside the menu bar panel: the topics, then decisions, key points and open
/// questions when there are any. The summary window has the full version.
private struct SummaryDetails: View {
    let summary: MeetingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !summary.topics.isEmpty {
                group("Assuntos", symbol: "text.bubble") {
                    ForEach(Array(summary.topics.enumerated()), id: \.offset) { _, topic in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topic.title)
                                .font(.system(size: 12, weight: .semibold))
                            Text(topic.summary)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.paper.opacity(0.7))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            bullets("Decisões", symbol: "checkmark.seal", items: summary.decisions)
            bullets("Ideias principais", symbol: "lightbulb", items: summary.keyPoints)
            bullets("Perguntas em aberto", symbol: "questionmark.circle", items: summary.openQuestions)
        }
    }

    private func group<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .foregroundStyle(Theme.muted)
            }
            .font(.system(size: 11, weight: .semibold))
            content()
        }
    }

    @ViewBuilder
    private func bullets(_ title: String, symbol: String, items: [String]) -> some View {
        if !items.isEmpty {
            group(title, symbol: symbol) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 4, height: 4)
                            .padding(.top, 5)
                        Text(item)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.paper.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// Estimated GPT cost for the day, read straight from the on-disk log.
private struct UsageLine: View {
    @ObservedObject var ledger: UsageLedger

    var body: some View {
        let today = ledger.totals(since: Calendar.current.startOfDay(for: Date()))
        Text("US$ \(String(format: "%.3f", today.costUSD))")
            .monospacedDigit()
            .foregroundStyle(Theme.paper.opacity(0.45))
            .help("Custo estimado do GPT hoje, em \(today.calls) chamadas")
    }
}
