import SwiftUI

/// Panel that opens when the menu bar icon is clicked. From top to bottom: the captions
/// session, the meeting summary (when there is one) and the work in progress.
struct MenuBarPanel: View {
    @EnvironmentObject private var model: CaptionModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
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

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = model.summary {
                Text("Resumo da reunião")
                    .font(.callout.weight(.semibold))
                ScrollView {
                    Text(summary)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                if !model.meetingActions.isEmpty {
                    MeetingActionsList()
                }
                HStack(spacing: 8) {
                    Button("Copiar") { model.copySummary() }
                        .buttonStyle(PillButtonStyle())
                    if let url = model.summaryURL {
                        Button("Abrir arquivo") { NSWorkspace.shared.open(url) }
                            .buttonStyle(PillButtonStyle(prominent: false))
                    }
                }
            } else if model.isSummarizing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Resumindo a reunião…")
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Button("Resumir reunião") { model.summarize() }
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
        openWindow(id: window)
        NSApp.activate(ignoringOtherApps: true)
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

/// The summary's action items: what to do, and who and when, when the meeting said so.
private struct MeetingActionsList: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pendências")
                .font(.system(size: 12, weight: .semibold))
            ForEach(model.meetingActions) { action in
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 12, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    let details = [action.owner, action.due].filter { !$0.isEmpty }.joined(separator: " · ")
                    if !details.isEmpty {
                        Text(details)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
