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
            WorkBlock(openDeliveries: { open(deliveriesWindowID) }, openSettings: { open(settingsWindowID) })
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
            await model.refreshLinearOverview()
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

/// The summary's action items, each with a button to turn it into a Linear issue.
private struct MeetingActionsList: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pendências")
                .font(.system(size: 12, weight: .semibold))
            ForEach(model.meetingActions) { action in
                MeetingActionRow(action: action)
            }
            if !model.linearReady {
                Text("Conecte o Linear em Ajustes para transformar as pendências em issues.")
                    .font(.caption)
                    .foregroundStyle(Theme.paper.opacity(0.45))
            }
        }
    }
}

private struct MeetingActionRow: View {
    @EnvironmentObject private var model: CaptionModel
    let action: MeetingAction
    @State private var showingForm = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
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
                if let error = model.actionErrors[action.id] {
                    Text(error)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 4)
            if let identifier = action.linearIdentifier, let link = action.linearURL, let url = URL(string: link) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        LinearLogo(size: 10)
                        Text(identifier)
                    }
                }
                .buttonStyle(PillButtonStyle(prominent: false))
                .help("Abrir no Linear")
            } else if model.sendingActions.contains(action.id) {
                ProgressView().controlSize(.small)
            } else if model.linearReady {
                Button {
                    showingForm = true
                } label: {
                    HStack(spacing: 4) {
                        LinearLogo(size: 10)
                        Text("Enviar")
                    }
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(PillButtonStyle(prominent: false))
                .help("Criar uma issue no Linear a partir desta pendência")
                .popover(isPresented: $showingForm, arrowEdge: .trailing) {
                    LinearSendForm(action: action, isPresented: $showingForm)
                        .environmentObject(model)
                }
            }
        }
        .padding(8)
        .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Work in progress in Linear: the issue in focus, the count per status in the current cycle and
/// the team's deliveries over the last few days.
private struct WorkBlock: View {
    @EnvironmentObject private var model: CaptionModel
    let openDeliveries: () -> Void
    let openSettings: () -> Void

    var body: some View {
        if model.linearReady {
            content
        } else {
            // Without Linear there are no tasks: the block becomes an invitation to connect.
            Button(action: openSettings) {
                HStack(spacing: 8) {
                    LinearLogo(size: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conecte o Linear")
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("Veja sua cycle, a issue em foco e as entregas do time aqui.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(Theme.paper.opacity(0.35))
                }
                .padding(10)
                .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                LinearLogo(size: 11)
                Button(action: openDeliveries) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .contentTransition(.opacity)
                        Spacer()
                        Text("Entregas")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Theme.paper.opacity(0.35))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                RefreshControl(loading: model.isLoadingOverview || model.isLoadingDeliveries) {
                    Task {
                        async let overview: Void = model.refreshLinearOverview(force: true)
                        async let deliveries: Void = model.loadDeliveries(force: true)
                        _ = await (overview, deliveries)
                    }
                }
            }

            focusCard
                .transition(.opacity.combined(with: .offset(y: 6)))

            HStack(spacing: 6) {
                stat(counts?.open, "Abertas", .todo)
                stat(counts?.inProgress, "Progresso", .inProgress)
                stat(counts?.inReview, "Review", .inReview)
                stat(counts?.done, "Concluídas", .done)
            }

            DeliveriesMiniChart(action: openDeliveries)

            if model.linearReady, let error = model.linearOverviewError {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(error)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Button("Tentar de novo") {
                        Task { await model.refreshLinearOverview(force: true) }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: overview)
        .animation(.easeOut(duration: 0.25), value: model.linearOverviewError)
    }

    private var overview: LinearClient.Overview? { model.linearReady ? model.linearOverview : nil }

    /// First load: Linear is connected, but there are no numbers yet (not even cached).
    private var isFirstLoad: Bool { model.linearReady && overview == nil && model.linearOverviewError == nil }

    private var title: String {
        guard let overview else { return "Linear" }
        return overview.cycle ?? "Sem cycle ativa"
    }

    private var counts: (open: Int, inProgress: Int, inReview: Int, done: Int)? {
        overview.map { ($0.open, $0.inProgress, $0.inReview, $0.done) }
    }

    /// The highest-priority task in progress.
    @ViewBuilder
    private var focusCard: some View {
        if let focus = overview?.focus {
            focusRow(priority: focus.priority, identifier: focus.identifier, title: focus.title) {
                if let url = URL(string: focus.url) { NSWorkspace.shared.open(url) }
            }
            .id(focus.identifier)
        } else if isFirstLoad {
            // Skeleton with the same shape as the card, so the panel doesn't jump when the data arrives.
            VStack(alignment: .leading, spacing: 7) {
                SkeletonBar(width: 92, height: 9)
                SkeletonBar(width: 210, height: 11)
                SkeletonBar(width: 150, height: 11)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shimmer()
        } else {
            Text("Nada em progresso agora.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func focusRow(priority: Int, identifier: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    StatusIcon(status: .inProgress, size: 12)
                    PriorityIcon(priority: priority, size: 13)
                    Text(identifier)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text(DemandPriority.title(priority))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.muted)
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Theme.paper.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Em progresso com a maior prioridade")
    }

    /// Counter for one status. With no value yet, it shows a skeleton; when it changes, the digits roll.
    private func stat(_ value: Int?, _ label: String, _ status: DemandStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                StatusIcon(status: status, size: 10)
                if let value {
                    Text("\(value)")
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .contentTransition(.numericText(value: Double(value)))
                        .transition(.opacity)
                } else {
                    SkeletonBar(width: 16, height: 12)
                        .frame(height: 18)
                }
            }
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shimmer(active: value == nil)
    }
}

/// Linear logo that spins continuously while a fetch is in progress.
/// Refresh button that turns into the system's small spinner while Linear is being read, as in
/// Apple's own apps. Clicking it reads everything again.
private struct RefreshControl: View {
    let loading: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            if loading {
                ProgressView()
                    .controlSize(.mini)
                    .transition(.opacity)
            } else {
                Button(action: action) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.paper.opacity(0.45))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Atualizar do Linear")
                .transition(.opacity)
            }
        }
        .frame(width: 16, height: 16)
        .animation(.easeOut(duration: 0.2), value: loading)
    }
}

/// Gray bar that takes the place of a piece of text while it loads.
private struct SkeletonBar: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Theme.paper.opacity(0.12))
            .frame(width: width, height: height)
    }
}

/// Shimmer that sweeps across the content from left to right, indicating loading.
private struct Shimmer: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Theme.paper.opacity(0.10), .clear], startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .allowsHitTesting(false)
                    .onAppear {
                        phase = -0.6
                        withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) { phase = 1 }
                    }
                }
            }
    }
}

private extension View {
    func shimmer(active: Bool = true) -> some View { modifier(Shimmer(active: active)) }
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
