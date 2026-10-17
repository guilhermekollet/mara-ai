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
        GPTModel(id: "gpt-6-luna", name: "GPT-6 Luna", note: localized("Recomendado: rápido e natural"), inputPrice: 0.10, outputPrice: 0.50),
        GPTModel(id: "gpt-5-nano", name: "GPT-5 nano", note: localized("O mais barato; pode demorar um pouco mais"), inputPrice: 0.05, outputPrice: 0.40),
        GPTModel(id: "gpt-4.1-mini", name: "GPT-4.1 mini", note: localized("Equilibrado, para termos técnicos"), inputPrice: 0.40, outputPrice: 1.60),
        GPTModel(id: "gpt-4o-mini", name: "GPT-4o mini", note: localized("Clássico e estável"), inputPrice: 0.15, outputPrice: 0.60),
    ]
    static let customID = "custom"
}

struct SettingsView: View {
    /// Set to a tab's name ("summary", for example) to open Settings on that tab.
    static let requestedTabKey = "settingsTab"

    @EnvironmentObject private var model: CaptionModel
    @State private var tab = Tab.translation
    @AppStorage(SettingsView.requestedTabKey) private var requestedTab = ""
    /// The content has slid under the header: a hairline separates them, as under a macOS toolbar.
    @State private var scrolled = false
    /// There is more below: the bottom edge fades out.
    @State private var moreBelow = false

    /// Another part of the app asked for a tab: show it, then forget the request.
    private func showRequestedTab() {
        guard let match = Tab.allCases.first(where: { "\($0)" == requestedTab }) else { return }
        tab = match
        requestedTab = ""
    }

    private enum Tab: CaseIterable, Identifiable {
        case translation, summary, appearance, usage, glossary, general
        var id: Self { self }

        var title: String {
            switch self {
            case .translation: return localized("Tradução")
            case .summary: return localized("Resumo")
            case .appearance: return localized("Aparência")
            case .usage: return localized("Consumo")
            case .glossary: return localized("Glossário")
            case .general: return localized("Geral")
            }
        }

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
        .onAppear(perform: showRequestedTab)
        .onChange(of: requestedTab) { showRequestedTab() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(localized("Ajustes"))
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
                                Text(item.title)
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
                    .help(item.title)
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
            SettingsCard(localized("Idiomas"), hint: localized("Quando a reunião já é no idioma da legenda, a legenda é a própria transcrição, sem tradução. O resumo sai no idioma da legenda.")) {
                VStack(spacing: 8) {
                    languageRow(localized("Reunião em")) {
                        Picker(localized("Reunião em"), selection: $model.localeID) {
                            ForEach(model.locales, id: \.identifier) { locale in
                                Text(model.displayName(locale)).tag(locale.identifier)
                            }
                        }
                    }
                    languageRow(localized("Legenda em")) {
                        Picker(localized("Legenda em"), selection: $model.captionLanguageID) {
                            ForEach(CaptionLanguage.all) { language in
                                Text(language.name).tag(language.id)
                            }
                        }
                    }
                }
                .disabled(model.isRunning)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localized("Como traduzir"))
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 10) {
                    OptionCard(
                        symbol: "laptopcomputer",
                        title: localized("Só no Mac"),
                        text: localized("Grátis e privado. A Apple traduz no aparelho, sem internet."),
                        selected: !model.useGPT
                    ) { model.useGPT = false }
                    OptionCard(
                        symbol: "sparkles",
                        title: "Mac + GPT",
                        text: localized("Mais natural. A legenda aparece na hora e o GPT refina cada frase."),
                        selected: model.useGPT
                    ) { model.useGPT = true }
                }
            }

            if model.useGPT {
                SettingsCard(localized("Modelo do GPT"), hint: modelHint) {
                    Picker(localized("Modelo"), selection: selection) {
                        ForEach(GPTModel.catalog) { choice in
                            Text("\(choice.name) — \(choice.note)").tag(choice.id)
                        }
                        Divider()
                        Text(localized("Outro modelo…")).tag(GPTModel.customID)
                    }
                    .labelsHidden()

                    if model.apiKey.isEmpty {
                        Label(localized("O GPT usa a sua chave da OpenAI: adicione em Resumo."), systemImage: "exclamationmark.circle")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.accent)
                    }

                    if selection.wrappedValue == GPTModel.customID {
                        TextField(localized("Nome do modelo na OpenAI"), text: $model.model)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            priceField(localized("Entrada"), value: $model.inputPrice)
                            priceField(localized("Saída"), value: $model.outputPrice)
                        }
                    }
                }
            }

            ReadAloudCard()
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
        localized("US$ \(format(model.inputPrice)) de entrada e US$ \(format(model.outputPrice)) de saída por milhão de tokens. Uma hora de reunião costuma custar centavos.")
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

/// Reading the captions aloud: on or off, the voices' download, which voice for whom, speed and volume.
private struct ReadAloudCard: View {
    @EnvironmentObject private var model: CaptionModel
    @ObservedObject private var store = VoiceModelStore.shared

    var body: some View {
        let engine = model.readoutEngine
        SettingsCard(
            localized("Ler em voz alta"),
            hint: localized("A Mara lê cada frase traduzida com uma voz neural que roda no Mac: grátis, sem internet depois do download. A voz acompanha quem fala: voz grave é lida com a voz masculina, aguda com a feminina, e com Identificar quem fala (Ajustes › Geral) cada pessoa ganha a sua voz. Com alto-falantes, o seu microfone pausa enquanto ela fala; com fone, não precisa. ⌃⌥V liga e desliga.")
        ) {
            Toggle(localized("Ler as legendas em voz alta"), isOn: Binding(
                get: { model.readAloud },
                set: { model.setReadAloud($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            if !model.translates {
                Label(localized("Só lê reuniões traduzidas: agora a reunião e a legenda estão no mesmo idioma."), systemImage: "info.circle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
            }

            let megabytes = engine.model.megabytes
            ModelDownloadRow(
                model: engine.model,
                missing: localized("Vozes em \(model.captionLanguage.name): \(megabytes) MB, baixadas uma vez."),
                ready: localized("Vozes em \(model.captionLanguage.name) prontas"),
                freeing: localized("Libera \(megabytes) MB. Para ler de novo, as vozes são baixadas outra vez.")
            )

            if store.state(engine.model) == .ready {
                voiceRow(.female)
                voiceRow(.male)
                sliderRow(localized("Velocidade"), value: $model.readoutSpeed, range: 0.8...1.4, step: 0.05,
                          label: model.readoutSpeed.formatted(.number.precision(.fractionLength(2))) + "×")
                sliderRow(localized("Volume"), value: $model.readoutVolume, range: 0.2...1, step: 0.05,
                          label: "\(Int(model.readoutVolume * 100))%")
            }
        }
    }

    private func voiceRow(_ gender: VoiceGender) -> some View {
        let options = ReadoutCatalog.voices(for: model.captionLanguage.code, gender: gender)
        let title = gender == .female ? localized("Voz feminina") : localized("Voz masculina")
        return HStack {
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            Picker(title, selection: Binding(
                get: { model.readoutVoice(gender).id },
                set: { id in
                    if let voice = options.first(where: { $0.id == id }) { model.setReadoutVoice(voice) }
                }
            )) {
                ForEach(options) { voice in
                    Text(voice.name).tag(voice.id)
                }
            }
            .labelsHidden()
            .fixedSize()
            Button(localized("Ouvir")) { model.previewVoice(model.readoutVoice(gender)) }
                .buttonStyle(PillButtonStyle(prominent: false))
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, label: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12.5))
                .frame(width: 80, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(label)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Theme.muted)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: Summary

private struct SummarySettings: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The key is here because the summary always needs it; the GPT translation uses it too.
            SettingsCard(localized("Resumo"), hint: localized("Feito pelo GPT com a sua chave, só quando você pede ao fim da sessão. A transcrição vai para a OpenAI; o áudio, nunca.")) {
                Picker(localized("Modelo do resumo"), selection: $model.summaryModel) {
                    ForEach(GPTModel.catalog) { choice in
                        Text("\(choice.name) — \(choice.note)").tag(choice.id)
                    }
                }
                .labelsHidden()
            }

            SettingsCard(localized("Chave da OpenAI"), hint: localized("Fica guardada no Keychain do macOS. Só o texto transcrito é enviado; o áudio nunca sai do Mac.")) {
                OpenAIKeyField(missingHint: localized("Sem chave, a tradução fica só no Mac e não há resumo."))
            }
        }
    }
}

// MARK: Appearance

private struct AppearanceSettings: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            preview

            SettingsCard(localized("Tamanho da legenda")) {
                sliderRow(value: $model.fontSize, range: 12...40, step: 1, label: "\(Int(model.fontSize)) pt")
            }
            SettingsCard(
                localized("Fundo da janela"),
                hint: localized("Com pouca opacidade e sem desfoque, a reunião aparece nítida atrás da legenda; a sombra mantém o texto legível.")
            ) {
                labeledSlider(localized("Opacidade"), value: $model.opacity)
                labeledSlider(localized("Desfoque"), value: $model.blur)
                Toggle(localized("Sombra nas letras"), isOn: $model.textShadow)
                    .font(.system(size: 12.5))
            }
            SettingsCard(
                localized("Quando não há áudio"),
                hint: localized("Em espera, a Mara para de transcrever e confere a cada 2 segundos se o som voltou. Desligar encerra a sessão e salva a transcrição.")
            ) {
                durationPicker(localized("Entrar em espera após"), selection: $model.idleAfter, options: [
                    (15, localized("15 segundos")), (30, localized("30 segundos")), (60, localized("1 minuto")), (120, localized("2 minutos")), (0, localized("Nunca")),
                ])
                durationPicker(localized("Desligar após"), selection: $model.autoStopAfter, options: [
                    (60, localized("1 minuto")), (300, localized("5 minutos")), (600, localized("10 minutos")), (1800, localized("30 minutos")), (0, localized("Nunca")),
                ])
            }
            SettingsCard(
                localized("Sons"),
                hint: localized("Tons curtos e suaves ao iniciar, parar, entrar em espera, voltar e quando o resumo fica pronto. A Mara não capta os próprios sons.")
            ) {
                HStack {
                    Toggle(localized("Tocar avisos sonoros"), isOn: $model.soundCuesEnabled)
                        .font(.system(size: 12.5))
                    Spacer()
                    Button(localized("Ouvir")) { model.soundCues.play(.start, evenIfDisabled: true) }
                        .buttonStyle(PillButtonStyle(prominent: false))
                }
            }
        }
    }

    /// The captions window over a wallpaper, with this window's tint, blur and text shadow, so each
    /// setting can be judged as it changes.
    private var preview: some View {
        let box = RoundedRectangle(cornerRadius: 14, style: .continuous)
        // The captions window as a strip over the lower part of the screen, as it usually sits.
        let window = EdgeInsets(top: 58, leading: 14, bottom: 12, trailing: 14)
        return ZStack {
            PreviewWallpaper()
            // The wallpaper blurred only inside the window, as its frosted glass does.
            PreviewWallpaper()
                .blur(radius: 16 * model.blur)
                .mask { box.padding(window) }
            box.fill(Theme.ink.opacity(model.opacity))
                .padding(window)
            VStack(spacing: 3) {
                Text(localized("Podemos revisar o contrato na quinta."))
                    .foregroundStyle(Theme.paper)
                Text(localized("E acho que o prazo de entrega"))
                    .foregroundStyle(Theme.accent)
            }
            .font(.system(size: model.fontSize, weight: .medium))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .modifier(CaptionShadow(on: model.textShadow))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(window)
        }
        .frame(height: 170)
        .clipShape(box)
    }

    private func labeledSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12.5))
                .frame(width: 74, alignment: .leading)
            sliderRow(value: value, range: 0...1, step: 0.05, label: "\(Int((value.wrappedValue * 100).rounded()))%")
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

/// What the appearance preview shows behind the captions window: a desktop wallpaper, like the one
/// the window floats over. Without the image, a gradient in its colors.
private struct PreviewWallpaper: View {
    private static let image = Interface.resources.url(forResource: "PreviewWallpaper", withExtension: "jpg").flatMap(NSImage.init(contentsOf:))

    var body: some View {
        if let image = Self.image {
            // Filled into exactly the space it is given: on its own, a filling image would grow
            // past it and push the caption strip off its place.
            Color.clear
                .overlay {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.35, blue: 0.95), Color(red: 0.95, green: 0.55, blue: 0.2), Color(red: 0.7, green: 0.45, blue: 0.95)],
                startPoint: .leading, endPoint: .trailing
            )
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
            SettingsCard(localized("Uso do GPT"), hint: localized("Os tokens são os informados pela OpenAI. O custo é uma estimativa com o preço do modelo no momento de cada chamada; a fatura da OpenAI é a referência final.")) {
                VStack(spacing: 0) {
                    if model.isRunning, let start = model.sessionStart {
                        row(localized("Sessão atual"), ledger.totals(since: start))
                    }
                    row(localized("Hoje"), ledger.totals(since: calendar.startOfDay(for: now)))
                    row(localized("Este mês"), ledger.totals(since: calendar.dateInterval(of: .month, for: now)?.start))
                    row(localized("Total"), ledger.totals(since: nil), last: true)
                }
            }
            if let error = ledger.writeError {
                Label(localized("O registro em disco falhou (\(error)); o histórico pode estar incompleto."), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
            }
            if ledger.entries.isEmpty {
                Text(localized("Nenhuma chamada ao GPT até agora. A tradução feita no Mac não tem custo."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            } else {
                Button(localized("Mostrar o registro no Finder")) {
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
                    Text(localized("\(totals.calls) chamadas · \((totals.inputTokens + totals.outputTokens).formatted()) tokens"))
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
                localized("Termos da sua equipe"),
                hint: localized("Nomes de pessoas, empresas e produtos. Deixe o segundo campo vazio para manter o termo como está, ou diga como ele deve aparecer na legenda.")
            ) {
                if model.glossary.isEmpty {
                    Text(localized("Nenhum termo ainda."))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                VStack(spacing: 6) {
                        ForEach($model.glossary) { $entry in
                            HStack(spacing: 6) {
                                TextField(localized("Termo (ex.: Kubernetes)"), text: $entry.term)
                                    .textFieldStyle(.roundedBorder)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.muted)
                                TextField(localized("Como aparece (opcional)"), text: $entry.rendering)
                                    .textFieldStyle(.roundedBorder)
                                IconButton(symbol: "minus.circle", help: localized("Remover o termo")) {
                                    model.glossary.removeAll { $0.id == entry.id }
                                }
                            }
                        }
                }
                Button {
                    model.glossary.append(GlossaryEntry())
                } label: {
                    Label(localized("Adicionar termo"), systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(prominent: false))
            }
            SettingsCard(localized("Onde o glossário é usado")) {
                VStack(alignment: .leading, spacing: 6) {
                    usage("waveform", localized("No reconhecimento de fala, para acertar os nomes."))
                    usage("sparkles", localized("Na tradução refinada pelo GPT e no resumo da reunião."))
                    usage("laptopcomputer", localized("A tradução feita só no Mac não segue o glossário."))
                }
            }
            if model.isRunning {
                Text(localized("Mudanças no reconhecimento de fala valem a partir da próxima sessão."))
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
            MicrophoneCard()
            SpeakersCard()
            SettingsCard(localized("Atalhos globais"), hint: localized("Funcionam com qualquer aplicativo em primeiro plano, sem tirar o foco da reunião.")) {
                Toggle(localized("Ativar os atalhos de teclado"), isOn: $model.hotKeysEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            SettingsCard(localized("Teclas")) {
                ShortcutList()
                    .opacity(model.hotKeysEnabled ? 1 : 0.4)
            }
            if !model.unavailableHotKeys.isEmpty {
                Label(
                    localized("O macOS recusou \(model.unavailableHotKeys.joined(separator: ", ")): outro aplicativo já usa essa combinação."),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.system(size: 11.5))
                .foregroundStyle(.orange)
            }
            SettingsCard(localized("Introdução"), hint: localized("A apresentação da primeira vez: a permissão de áudio, o idioma da reunião e a chave para o resumo.")) {
                Button(localized("Ver a introdução")) {
                    UserDefaults.standard.set(0, forKey: Onboarding.stepKey)
                    present(onboardingWindowID, using: openWindow)
                }
                .buttonStyle(PillButtonStyle(prominent: false))
            }
        }
    }
}

/// Whether what you say goes into the transcript and the summary too.
private struct MicrophoneCard: View {
    @EnvironmentObject private var model: CaptionModel
    @State private var denied = MicrophonePermission.wasDenied

    var body: some View {
        SettingsCard(
            localized("Seu microfone"),
            hint: localized("Ligado, o que você diz entra na transcrição como seu, e o resumo sabe quem disse o quê. A Mara não sabe se você está mudo na reunião: desligue quando não quiser ser transcrito, aqui, na janela de legendas ou com ⌃⌥M. Sem fone, a Mara descarta o eco dos outros saindo pelos alto-falantes.")
        ) {
            Toggle(localized("Transcrever o meu microfone"), isOn: Binding(
                get: { model.microphoneOn },
                set: { on in Task { await model.setMicrophone(on); denied = MicrophonePermission.wasDenied } }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            if denied {
                HStack(spacing: 8) {
                    Text(localized("O macOS não deu acesso ao microfone."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.orange)
                    Spacer()
                    Button(localized("Abrir Ajustes do Sistema")) { MicrophonePermission.openSystemSettings() }
                        .buttonStyle(PillButtonStyle(prominent: false))
                }
            }
        }
        // Granted in System Settings while this is open: the warning goes away on its own.
        .task {
            while !Task.isCancelled {
                denied = MicrophonePermission.wasDenied
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

/// A downloadable model's state, with the button that fits: download, cancel, delete or retry.
private struct ModelDownloadRow: View {
    @EnvironmentObject private var session: CaptionModel
    @ObservedObject private var store = VoiceModelStore.shared
    let model: VoiceModel
    let missing: String
    let ready: String
    let freeing: String

    var body: some View {
        HStack(spacing: 8) {
            switch store.state(model) {
            case .missing:
                Text(missing)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button(localized("Baixar")) { store.download(model) }
                    .buttonStyle(PillButtonStyle(prominent: false))
            case .downloading(let fraction):
                ProgressView(value: fraction)
                    .controlSize(.small)
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .frame(width: 36, alignment: .trailing)
                Button(localized("Cancelar")) { store.cancel(model) }
                    .buttonStyle(PillButtonStyle(prominent: false))
            case .ready:
                Label(ready, systemImage: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button(localized("Apagar")) { store.remove(model) }
                    .buttonStyle(PillButtonStyle(prominent: false))
                    .disabled(session.isRunning)
                    .help(freeing)
            case .failed(let message):
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(localized("Tentar de novo")) { store.download(model) }
                    .buttonStyle(PillButtonStyle(prominent: false))
            }
        }
    }
}

/// Telling the meeting's speakers apart by their voices.
private struct SpeakersCard: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        SettingsCard(
            localized("Identificar quem fala"),
            hint: localized("A Mara reconhece as pessoas da reunião pela voz, no Mac. Na transcrição e no resumo, cada uma aparece como Pessoa 1, Pessoa 2…; na leitura em voz alta, cada uma ganha a sua voz (até duas por gênero, para manter a qualidade). Pode errar com áudio ruim ou vozes parecidas.")
        ) {
            Toggle(localized("Distinguir as pessoas pela voz"), isOn: Binding(
                get: { model.identifySpeakers },
                set: { model.setIdentifySpeakers($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            if model.identifySpeakers {
                let megabytes = VoiceModel.speakers.megabytes
                ModelDownloadRow(
                    model: .speakers,
                    missing: localized("Modelo de vozes: \(megabytes) MB, baixado uma vez."),
                    ready: localized("Modelo de vozes pronto"),
                    freeing: localized("Libera \(megabytes) MB. Para identificar de novo, o modelo é baixado outra vez.")
                )
            }
        }
    }
}

/// Automatic updates: on or off, where they stand, and a way to check right away.
private struct UpdateCard: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        SettingsCard(
            localized("Atualizações"),
            hint: localized("Uma vez por dia, a Mara procura uma versão nova no GitHub. Ela é baixada em segundo plano, conferida pela assinatura do projeto e instalada quando você fecha a Mara.")
        ) {
            Toggle(localized("Baixar e instalar atualizações automaticamente"), isOn: $updater.automatic)
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
                Button(localized("Verificar agora")) { Task { await updater.check() } }
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
            return localized("As atualizações automáticas valem para o app baixado das releases.")
        }
        let version = updater.currentVersion
        switch updater.state {
        case .idle: return localized("Versão \(version).")
        case .checking: return localized("Procurando atualizações…")
        case .upToDate:
            guard let lastCheck = updater.lastCheck else { return localized("Versão \(version), a mais recente.") }
            let when = lastCheck.formatted(.relative(presentation: .named).locale(Interface.locale))
            return localized("Versão \(version), a mais recente. Verificado \(when).")
        case .downloading(let next): return localized("Baixando a versão \(next)…")
        case .ready(let next, _): return localized("A versão \(next) instala quando você fechar a Mara.")
        case .failed(let message): return localized("Não foi possível atualizar: \(message)")
        }
    }
}

// MARK: Components

/// The OpenAI key, saved to the Keychain when submitted, with a link to create one. Used in
/// Settings and in the introduction; `missingHint` says what happens without a key.
struct OpenAIKeyField: View {
    /// OpenAI's page for creating API keys.
    static let keysPage = URL(string: "https://platform.openai.com/api-keys")!

    let missingHint: String
    /// Off where the page shows its own, larger way to create a key.
    var linksToKeysPage = true
    @EnvironmentObject private var model: CaptionModel
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SecureField("sk-…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                if draft != model.apiKey {
                    Button(localized("Salvar"), action: save)
                        .buttonStyle(PillButtonStyle())
                }
            }
            HStack(spacing: 6) {
                Image(systemName: model.apiKey.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(model.apiKey.isEmpty ? Theme.muted : Theme.accent)
                Text(model.apiKey.isEmpty ? missingHint : localized("Chave salva no Keychain."))
                    .foregroundStyle(Theme.muted)
                Spacer()
                if linksToKeysPage {
                    Link(localized("Criar uma chave"), destination: Self.keysPage)
                        .foregroundStyle(Theme.accent)
                }
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
