import SwiftUI

let settingsWindowID = "settings"

/// Suggested models for refining the translation, with the price in dollars per million tokens.
struct GPTModel: Identifiable {
    let id: String
    let name: String
    let note: String
    let inputPrice: Double
    let outputPrice: Double

    static let catalog = [
        GPTModel(id: "gpt-6-luna", name: "GPT-6 Luna", note: "Recomendado: rápido e natural", inputPrice: 0.10, outputPrice: 0.50),
        GPTModel(id: "gpt-5-nano", name: "GPT-5 nano", note: "O mais barato; pode demorar um pouco mais", inputPrice: 0.05, outputPrice: 0.40),
        GPTModel(id: "gpt-4.1-mini", name: "GPT-4.1 mini", note: "Equilibrado, para termos técnicos", inputPrice: 0.40, outputPrice: 1.60),
        GPTModel(id: "gpt-4o-mini", name: "GPT-4o mini", note: "Clássico e estável", inputPrice: 0.15, outputPrice: 0.60),
    ]
    static let customID = "custom"
}

struct SettingsView: View {
    @EnvironmentObject private var model: CaptionModel
    @State private var tab = Tab.translation
    /// The content has slid under the header: a hairline separates them, as under a macOS toolbar.
    @State private var scrolled = false
    /// There is more below: the bottom edge fades out.
    @State private var moreBelow = false

    private enum Tab: String, CaseIterable, Identifiable {
        case translation = "Tradução"
        case summary = "Resumo"
        case appearance = "Aparência"
        case usage = "Consumo"
        case glossary = "Glossário"
        case general = "Geral"
        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .translation: return "globe"
            case .summary: return "text.document"
            case .appearance: return "paintbrush"
            case .usage: return "chart.bar"
            case .glossary: return "text.book.closed"
            case .general: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding([.horizontal, .top], 22)
                .padding(.bottom, 14)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.paper.opacity(0.1))
                        .frame(height: 1)
                        .opacity(scrolled ? 1 : 0)
                }

            // The window has a fixed size and the content scrolls: resizing the window on every tab
            // switch crashed the app on macOS 26 (an AppKit exception during layout). The scroll view
            // spans the whole width, so its scroller sits at the window's edge.
            ScrollView {
                tabContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 22)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: [Bool].self) { geometry in
                let top = geometry.contentOffset.y + geometry.contentInsets.top
                let bottom = geometry.contentSize.height - top - geometry.containerSize.height
                return [top > 1, bottom > 1]
            } action: { _, edges in
                withAnimation(.easeOut(duration: 0.15)) {
                    scrolled = edges[0]
                    moreBelow = edges[1]
                }
            }
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .black.opacity(moreBelow ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 28)
                }
            }
            // Each tab starts at the top.
            .id(tab)
        }
        .frame(width: 460, height: 600, alignment: .topLeading)
        .background(Theme.ink)
        .foregroundStyle(Theme.paper)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task { await model.loadLocales() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Ajustes")
                .font(Theme.display(26))
            Spacer()
            // Icon tabs: only the active one shows its name, in lavender with dark text.
            HStack(spacing: 2) {
                ForEach(Tab.allCases) { item in
                    let active = tab == item
                    Button {
                        tab = item
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 16, height: 16)
                            if active {
                                Text(item.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .fixedSize()
                            }
                        }
                        .foregroundStyle(active ? Theme.ink : Theme.paper.opacity(0.75))
                        .padding(.horizontal, active ? 11 : 8)
                        .padding(.vertical, 5)
                        .background(active ? Theme.accent : .clear, in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(item.rawValue)
                }
            }
            .padding(3)
            .background(Theme.paper.opacity(0.07), in: Capsule())
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
            case .translation: TranslationSettings()
            case .summary: SummarySettings()
            case .appearance: AppearanceSettings()
            case .usage: UsageSettings(ledger: model.usage)
            case .glossary: GlossarySettings()
            case .general: GeneralSettings()
        }
    }
}

// MARK: Translation

private struct TranslationSettings: View {
    @EnvironmentObject private var model: CaptionModel
    @State private var customSelected = false

    private var selection: Binding<String> {
        Binding(
            get: {
                customSelected || !GPTModel.catalog.contains { $0.id == model.model } ? GPTModel.customID : model.model
            },
            set: { id in
                guard let choice = GPTModel.catalog.first(where: { $0.id == id }) else {
                    customSelected = true
                    return
                }
                customSelected = false
                model.model = choice.id
                model.inputPrice = choice.inputPrice
                model.outputPrice = choice.outputPrice
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard("Idiomas", hint: "Quando a reunião já é no idioma da legenda, a legenda é a própria transcrição, sem tradução. O resumo sai no idioma da legenda.") {
                VStack(spacing: 8) {
                    languageRow("Reunião em") {
                        Picker("Reunião em", selection: $model.localeID) {
                            ForEach(model.locales, id: \.identifier) { locale in
                                Text(model.displayName(locale)).tag(locale.identifier)
                            }
                        }
                    }
                    languageRow("Legenda em") {
                        Picker("Legenda em", selection: $model.captionLanguageID) {
                            ForEach(CaptionLanguage.all) { language in
                                Text(language.name).tag(language.id)
                            }
                        }
                    }
                }
                .disabled(model.isRunning)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Como traduzir")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 10) {
                    OptionCard(
                        symbol: "laptopcomputer",
                        title: "Só no Mac",
                        text: "Grátis e privado. A Apple traduz no aparelho, sem internet.",
                        selected: !model.useGPT
                    ) { model.useGPT = false }
                    OptionCard(
                        symbol: "sparkles",
                        title: "Mac + GPT",
                        text: "Mais natural. A legenda aparece na hora e o GPT refina cada frase.",
                        selected: model.useGPT
                    ) { model.useGPT = true }
                }
            }

            if model.useGPT {
                SettingsCard("Modelo do GPT", hint: modelHint) {
                    Picker("Modelo", selection: selection) {
                        ForEach(GPTModel.catalog) { choice in
                            Text("\(choice.name) — \(choice.note)").tag(choice.id)
                        }
                        Divider()
                        Text("Outro modelo…").tag(GPTModel.customID)
                    }
                    .labelsHidden()

                    if model.apiKey.isEmpty {
                        Label("O GPT usa a sua chave da OpenAI: adicione em Resumo.", systemImage: "exclamationmark.circle")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.accent)
                    }

                    if selection.wrappedValue == GPTModel.customID {
                        TextField("Nome do modelo na OpenAI", text: $model.model)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            priceField("Entrada", value: $model.inputPrice)
                            priceField("Saída", value: $model.outputPrice)
                        }
                    }
                }
            }
        }
    }

    private func languageRow<Content: View>(_ title: String, @ViewBuilder picker: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            picker()
                .labelsHidden()
                .fixedSize()
        }
    }

    private var modelHint: String {
        let price = "US$ \(format(model.inputPrice)) de entrada e US$ \(format(model.outputPrice)) de saída por milhão de tokens"
        return "\(price). Uma hora de reunião costuma custar centavos."
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func priceField(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.muted)
            TextField("US$", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: Summary

private struct SummarySettings: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The key is here because the summary always needs it; the GPT translation uses it too.
            SettingsCard("Resumo", hint: "Feito pelo GPT com a sua chave, só quando você pede ao fim da sessão. A transcrição vai para a OpenAI; o áudio, nunca.") {
                Picker("Modelo do resumo", selection: $model.summaryModel) {
                    ForEach(GPTModel.catalog) { choice in
                        Text("\(choice.name) — \(choice.note)").tag(choice.id)
                    }
                }
                .labelsHidden()
            }

            SettingsCard("Chave da OpenAI", hint: "Fica guardada no Keychain do macOS. Só o texto transcrito é enviado; o áudio nunca sai do Mac.") {
                OpenAIKeyField(missingHint: "Sem chave, a tradução fica só no Mac e não há resumo.")
            }
        }
    }
}

// MARK: Appearance

private struct AppearanceSettings: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Live preview: shows how the caption looks over a meeting.
            ZStack {
                LinearGradient(colors: [Color(red: 0.91, green: 0.89, blue: 0.99), Color(red: 0.72, green: 0.64, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 3) {
                    Text("Podemos revisar o contrato na quinta.")
                        .foregroundStyle(Theme.paper)
                    Text("E acho que o prazo de entrega")
                        .foregroundStyle(Theme.accent)
                }
                .font(.system(size: model.fontSize, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.ink.opacity(model.opacity), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(14)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            SettingsCard("Tamanho da legenda") {
                sliderRow(value: $model.fontSize, range: 12...40, step: 1, label: "\(Int(model.fontSize)) pt")
            }
            SettingsCard("Opacidade do fundo", hint: "Mais baixa deixa ver melhor o que está atrás da janela.") {
                sliderRow(value: $model.opacity, range: 0.2...1, step: 0.05, label: "\(Int(model.opacity * 100))%")
            }
            SettingsCard(
                "Quando não há áudio",
                hint: "Em espera, a Mara para de transcrever e confere a cada 2 segundos se o som voltou. Desligar encerra a sessão e salva a transcrição."
            ) {
                durationPicker("Entrar em espera após", selection: $model.idleAfter, options: [
                    (15, "15 segundos"), (30, "30 segundos"), (60, "1 minuto"), (120, "2 minutos"), (0, "Nunca"),
                ])
                durationPicker("Desligar após", selection: $model.autoStopAfter, options: [
                    (60, "1 minuto"), (300, "5 minutos"), (600, "10 minutos"), (1800, "30 minutos"), (0, "Nunca"),
                ])
            }
            SettingsCard(
                "Sons",
                hint: "Tons curtos e suaves ao iniciar, parar, entrar em espera, voltar e quando o resumo fica pronto. A Mara não capta os próprios sons."
            ) {
                HStack {
                    Toggle("Tocar avisos sonoros", isOn: $model.soundCuesEnabled)
                        .font(.system(size: 12.5))
                    Spacer()
                    Button("Ouvir") { model.soundCues.play(.start, evenIfDisabled: true) }
                        .buttonStyle(PillButtonStyle(prominent: false))
                }
            }
        }
    }

    private func durationPicker(_ title: String, selection: Binding<Double>, options: [(Double, String)]) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private func sliderRow(value: Binding<Double>, range: ClosedRange<Double>, step: Double, label: String) -> some View {
        HStack(spacing: 10) {
            Slider(value: value, in: range, step: step)
            Text(label)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Theme.muted)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: Usage

private struct UsageSettings: View {
    @EnvironmentObject private var model: CaptionModel
    @ObservedObject var ledger: UsageLedger

    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard("Uso do GPT", hint: "Os tokens são os informados pela OpenAI. O custo é uma estimativa com o preço do modelo no momento de cada chamada; a fatura da OpenAI é a referência final.") {
                VStack(spacing: 0) {
                    if model.isRunning, let start = model.sessionStart {
                        row("Sessão atual", ledger.totals(since: start))
                    }
                    row("Hoje", ledger.totals(since: calendar.startOfDay(for: now)))
                    row("Este mês", ledger.totals(since: calendar.dateInterval(of: .month, for: now)?.start))
                    row("Total", ledger.totals(since: nil), last: true)
                }
            }
            if let error = ledger.writeError {
                Label("O registro em disco falhou (\(error)); o histórico pode estar incompleto.", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
            }
            if ledger.entries.isEmpty {
                Text("Nenhuma chamada ao GPT até agora. A tradução feita no Mac não tem custo.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            } else {
                Button("Mostrar o registro no Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([UsageLedger.url])
                }
                .buttonStyle(PillButtonStyle(prominent: false))
            }
        }
    }

    private func row(_ title: String, _ totals: UsageTotals, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text("\(totals.calls) chamadas · \((totals.inputTokens + totals.outputTokens).formatted()) tokens")
                        .font(.system(size: 11.5).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Text("US$ \(String(format: "%.4f", totals.costUSD))")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
            }
            .padding(.vertical, 8)
            if !last {
                Divider().overlay(Theme.paper.opacity(0.1))
            }
        }
    }
}

// MARK: Glossary

private struct GlossarySettings: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(
                "Termos da sua equipe",
                hint: "Nomes de pessoas, empresas e produtos. Deixe o segundo campo vazio para manter o termo como está, ou diga como ele deve aparecer na legenda."
            ) {
                if model.glossary.isEmpty {
                    Text("Nenhum termo ainda.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                VStack(spacing: 6) {
                        ForEach($model.glossary) { $entry in
                            HStack(spacing: 6) {
                                TextField("Termo (ex.: Kubernetes)", text: $entry.term)
                                    .textFieldStyle(.roundedBorder)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.muted)
                                TextField("Como aparece (opcional)", text: $entry.rendering)
                                    .textFieldStyle(.roundedBorder)
                                IconButton(symbol: "minus.circle", help: "Remover o termo") {
                                    model.glossary.removeAll { $0.id == entry.id }
                                }
                            }
                        }
                }
                Button {
                    model.glossary.append(GlossaryEntry())
                } label: {
                    Label("Adicionar termo", systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(prominent: false))
            }
            SettingsCard("Onde o glossário é usado") {
                VStack(alignment: .leading, spacing: 6) {
                    usage("waveform", "No reconhecimento de fala, para acertar os nomes.")
                    usage("sparkles", "Na tradução refinada pelo GPT e no resumo da reunião.")
                    usage("laptopcomputer", "A tradução feita só no Mac não segue o glossário.")
                }
            }
            if model.isRunning {
                Text("Mudanças no reconhecimento de fala valem a partir da próxima sessão.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func usage(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
        }
    }
}

// MARK: Shortcuts

private struct GeneralSettings: View {
    @EnvironmentObject private var model: CaptionModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            UpdateCard()
            SettingsCard("Atalhos globais", hint: "Funcionam com qualquer aplicativo em primeiro plano, sem tirar o foco da reunião.") {
                Toggle("Ativar os atalhos de teclado", isOn: $model.hotKeysEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            SettingsCard("Teclas") {
                ShortcutList()
                    .opacity(model.hotKeysEnabled ? 1 : 0.4)
            }
            if !model.unavailableHotKeys.isEmpty {
                Label(
                    "O macOS recusou \(model.unavailableHotKeys.joined(separator: ", ")): outro aplicativo já usa essa combinação.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.system(size: 11.5))
                .foregroundStyle(.orange)
            }
            SettingsCard("Introdução", hint: "A apresentação da primeira vez: a permissão de áudio, o idioma da reunião e a chave para o resumo.") {
                Button("Ver a introdução") {
                    UserDefaults.standard.set(0, forKey: Onboarding.stepKey)
                    present(onboardingWindowID, using: openWindow)
                }
                .buttonStyle(PillButtonStyle(prominent: false))
            }
        }
    }
}

/// Automatic updates: on or off, where they stand, and a way to check right away.
private struct UpdateCard: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        SettingsCard(
            "Atualizações",
            hint: "Uma vez por dia, a Mara procura uma versão nova no GitHub. Ela é baixada em segundo plano, conferida pela assinatura do projeto e instalada quando você fecha a Mara."
        ) {
            Toggle("Baixar e instalar atualizações automaticamente", isOn: $updater.automatic)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!updater.isAvailable)
                .onChange(of: updater.automatic) { _, on in
                    if on { Task { await updater.check() } }
                }
            HStack(spacing: 8) {
                Text(status)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("Verificar agora") { Task { await updater.check() } }
                    .buttonStyle(PillButtonStyle(prominent: false))
                    .disabled(!updater.isAvailable || busy)
            }
        }
    }

    private var busy: Bool {
        switch updater.state {
        case .checking, .downloading, .ready: return true
        default: return false
        }
    }

    private var status: String {
        guard updater.isAvailable else {
            return "As atualizações automáticas valem para o app baixado das releases."
        }
        let version = "Versão \(updater.currentVersion)"
        switch updater.state {
        case .idle: return "\(version)."
        case .checking: return "Procurando atualizações…"
        case .upToDate:
            let when = updater.lastCheck.map { " Verificado \($0.formatted(.relative(presentation: .named)))." } ?? ""
            return "\(version), a mais recente.\(when)"
        case .downloading(let next): return "Baixando a versão \(next)…"
        case .ready(let next, _): return "A versão \(next) instala quando você fechar a Mara."
        case .failed(let message): return "Não foi possível atualizar: \(message)"
        }
    }
}

// MARK: Components

/// The OpenAI key, saved to the Keychain when submitted, with a link to create one. Used in
/// Settings and in the introduction; `missingHint` says what happens without a key.
struct OpenAIKeyField: View {
    let missingHint: String
    @EnvironmentObject private var model: CaptionModel
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SecureField("sk-…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                if draft != model.apiKey {
                    Button("Salvar", action: save)
                        .buttonStyle(PillButtonStyle())
                }
            }
            HStack(spacing: 6) {
                Image(systemName: model.apiKey.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(model.apiKey.isEmpty ? Theme.muted : Theme.accent)
                Text(model.apiKey.isEmpty ? missingHint : "Chave salva no Keychain.")
                    .foregroundStyle(Theme.muted)
                Spacer()
                Link("Criar uma chave", destination: URL(string: "https://platform.openai.com/api-keys")!)
            }
            .font(.system(size: 11.5))
        }
        .onAppear { draft = model.apiKey }
    }

    private func save() {
        model.saveAPIKey(draft)
        draft = model.apiKey
    }
}

/// The global shortcuts, each with its keys in a key cap.
struct ShortcutList: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(HotKeys.all, id: \.id) { shortcut in
                HStack {
                    Text(shortcut.title)
                        .font(.system(size: 13))
                    Spacer()
                    Text(shortcut.keys)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.paper.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .padding(.vertical, 7)
            }
        }
    }
}

/// Block with a title, content and a short explanation underneath.
private struct SettingsCard<Content: View>: View {
    let title: String
    let hint: String?
    @ViewBuilder let content: Content

    init(_ title: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            content
            if let hint {
                Text(hint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Large clickable option, for choosing between two alternatives.
private struct OptionCard: View {
    let symbol: String
    let title: String
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 15))
                        .foregroundStyle(selected ? Theme.accent : Theme.muted)
                        .frame(height: 18)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Theme.accent : Theme.paper.opacity(0.25))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(text)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.paper.opacity(selected ? 0.08 : 0.04), in: shape)
            .overlay(shape.strokeBorder(selected ? Theme.accent : Theme.paper.opacity(0.08), lineWidth: selected ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}
