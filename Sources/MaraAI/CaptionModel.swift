import AppKit
import Foundation
import Translation

@MainActor
final class CaptionModel: ObservableObject {
    struct Segment: Identifiable {
        let id = UUID()
        let date = Date()
        var original: String
        var translation: String?
        /// True when the translation is already GPT's final version (the local one doesn't overwrite it).
        var refined = false
    }

    @Published var segments: [Segment] = []
    @Published var volatile = ""
    @Published var volatileTranslation = ""
    /// Triggers the language download through Apple's UI when it isn't installed yet.
    @Published var translationDownload: TranslationSession.Configuration?
    @Published var isRunning = false
    @Published var isStarting = false
    @Published private(set) var summary: String?
    @Published private(set) var isSummarizing = false
    @Published private(set) var summaryError: String?
    /// Action items from the latest summary.
    @Published private(set) var meetingActions: [MeetingAction] = []

    @Published var status = ""
    @Published var locales: [Locale] = []
    @Published var localeID: String {
        didSet { UserDefaults.standard.set(localeID, forKey: "localeID") }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "openaiModel") }
    }
    @Published var apiKey: String
    /// Off, the app uses only Apple's local translation and sends nothing to OpenAI.
    @Published var useGPT: Bool {
        didSet { UserDefaults.standard.set(useGPT, forKey: "useGPT") }
    }
    /// Prices in dollars per million tokens, used to estimate the cost of each call.
    @Published var inputPrice: Double {
        didSet { UserDefaults.standard.set(inputPrice, forKey: "inputPrice") }
    }
    @Published var outputPrice: Double {
        didSet { UserDefaults.standard.set(outputPrice, forKey: "outputPrice") }
    }
    @Published private(set) var sessionStart: Date?
    let usage = UsageLedger()
    let menuBarAnimator = MenuBarAnimator()
    let audioMeter = AudioMeter()

    var gptEnabled: Bool { useGPT && !apiKey.isEmpty }

    @Published var hotKeysEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hotKeysEnabled, forKey: "hotKeysEnabled")
            applyHotKeys()
        }
    }
    /// Shortcuts the system rejected, usually because another app already uses them.
    @Published private(set) var unavailableHotKeys: [String] = []
    /// Opens the captions window; set by the UI, which is what can open windows.
    var openCaptions: (() -> Void)?

    /// Team names and terms, used in speech recognition, GPT translation and the summary.
    @Published var glossary: [GlossaryEntry] {
        didSet { GlossaryEntry.save(glossary) }
    }

    /// Seconds without audio before going on hold and before stopping on its own (0 disables the feature).
    @Published var idleAfter: Double {
        didSet { UserDefaults.standard.set(idleAfter, forKey: "idleAfter") }
    }
    @Published var autoStopAfter: Double {
        didSet { UserDefaults.standard.set(autoStopAfter, forKey: "autoStopAfter") }
    }
    /// On hold: the session stays open, but without transcribing, until sound comes back.
    @Published private(set) var isIdle = false
    private var gate: ActivityGate?
    private var idleTask: Task<Void, Never>?

    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    @Published var opacity: Double {
        didSet { UserDefaults.standard.set(opacity, forKey: "opacity") }
    }

    private var session: TranscriptionSession?
    // Apple's local translation: one session for the sentence in progress, another for finalized ones.
    private var localPartial: TranslationSession?
    private var localFinal: TranslationSession?
    private var isTranslatingVolatile = false
    private var volatileGeneration = 0
    private static let targetLanguage = Locale.Language(identifier: "pt-BR")
    private var transcriptURL: URL?
    private var transcriptTitle = ""

    static let transcriptsFolder = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Mara AI", isDirectory: true)

    init() {
        localeID = UserDefaults.standard.string(forKey: "localeID") ?? "en_US"
        model = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o-mini"
        apiKey = Keychain.loadAPIKey()
        useGPT = UserDefaults.standard.object(forKey: "useGPT") as? Bool ?? true
        inputPrice = UserDefaults.standard.object(forKey: "inputPrice") as? Double ?? 0.10
        outputPrice = UserDefaults.standard.object(forKey: "outputPrice") as? Double ?? 0.50
        hotKeysEnabled = UserDefaults.standard.object(forKey: "hotKeysEnabled") as? Bool ?? true
        glossary = GlossaryEntry.load()
        idleAfter = UserDefaults.standard.object(forKey: "idleAfter") as? Double ?? 30
        autoStopAfter = UserDefaults.standard.object(forKey: "autoStopAfter") as? Double ?? 300
        fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 17
        opacity = UserDefaults.standard.object(forKey: "opacity") as? Double ?? 0.55
        applyHotKeys()
        Self.forgetLinear()
    }

    /// Earlier versions connected to Linear. The integration is gone, so whatever it left on the Mac
    /// (the API key in the Keychain, the team and the cached numbers) is removed on launch.
    private static func forgetLinear() {
        Keychain.saveSecret("", account: "linear-api-key")
        for key in ["linearTeamID", "linearOnlyMine", "linearOverviewCache", "linearOverviewScope"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Languages offered, in menu order. For Spanish, the first variant the Mac supports.
    private static let offered: [[String]] = [["pt_BR"], ["en_US"], ["es_MX", "es_ES", "es_US"]]

    func loadLocales() async {
        let supported = await TranscriptionSession.supportedLocales()
        let normalized = { (locale: Locale) in locale.identifier.replacingOccurrences(of: "-", with: "_") }
        locales = Self.offered.compactMap { variants in
            variants.lazy.compactMap { wanted in supported.first { normalized($0) == wanted } }.first
        }
        if !locales.contains(where: { $0.identifier == localeID }) {
            localeID = locales.first(where: { $0.identifier.hasPrefix("en") })?.identifier
                ?? locales.first?.identifier ?? localeID
        }
    }

    func displayName(_ locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "pt": return "Português (Brasil)"
        case "en": return "Inglês (Estados Unidos)"
        case "es": return "Espanhol"
        default: return Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        }
    }

    /// Code of the current language, shown next to the language icon.
    var languageCode: String {
        (Locale(identifier: localeID).language.languageCode?.identifier ?? "").uppercased()
    }

    /// A meeting in Portuguese needs no translation: the caption is the transcription itself.
    private var translates: Bool { !localeID.hasPrefix("pt") }

    func saveAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.saveAPIKey(apiKey)
    }

    func toggle() {
        Task { isRunning ? await stop() : await start() }
    }

    // MARK: Global shortcuts and captions window

    private func applyHotKeys() {
        HotKeys.shared.unregisterAll()
        unavailableHotKeys = []
        guard hotKeysEnabled else { return }
        let bindings: [(HotKeys.Shortcut, () -> Void)] = [
            (HotKeys.toggleSession, { [weak self] in
                guard let self, !self.isStarting else { return }
                if !self.isRunning { self.showCaptions() }
                self.toggle()
            }),
            (HotKeys.toggleCaptions, { [weak self] in self?.toggleCaptionsWindow() }),
        ]
        for (shortcut, action) in bindings where !HotKeys.shared.register(shortcut, action: action) {
            unavailableHotKeys.append(shortcut.keys)
        }
    }

    private var captionsWindow: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue.contains(captionsWindowID) == true }
    }

    func showCaptions() {
        if let window = captionsWindow {
            window.orderFrontRegardless()
        } else {
            openCaptions?()
        }
    }

    func toggleCaptionsWindow() {
        if let window = captionsWindow, window.isVisible {
            window.orderOut(nil)
        } else {
            showCaptions()
        }
    }

    func copyTranscript() {
        let text = segments
            .map { [$0.translation == $0.original ? nil : $0.translation, $0.original].compactMap { $0 }.joined(separator: "\n") }
            .joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func start() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        status = "Preparando a transcrição…"

        let session = TranscriptionSession()
        let gate = ActivityGate()
        self.gate = gate
        do {
            try await session.start(
                locale: Locale(identifier: localeID),
                vocabulary: glossary.map { $0.term.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                gate: gate,
                onAudio: { [audioMeter] buffer in audioMeter.push(buffer) },
                onStatus: { [weak self] in self?.status = $0 },
                onResult: { [weak self] text, isFinal in self?.handle(text, isFinal: isFinal) },
                onError: { [weak self] error in
                    SessionLog.write("ERRO \(error.localizedDescription)")
                    self?.status = "Erro: \(error.localizedDescription)"
                    Task { await self?.stop(keepStatus: true) }
                }
            )
            self.session = session
            isRunning = true
            menuBarAnimator.setActive(true)
            audioMeter.setActive(true)
            beginTranscript()
            sessionStart = Date()
            SessionLog.begin()
            SessionLog.write("INICIO idioma=\(localeID) modelo=\(gptEnabled ? model : "sem GPT")")
            if translates {
                status = ""
                await prepareLocalTranslation()
            } else {
                status = ""
            }
            startIdleWatch()
        } catch {
            await session.stop()
            SessionLog.write("ERRO ao iniciar: \(error.localizedDescription)")
            status = "Não foi possível iniciar: \(error.localizedDescription). "
                + "Confira a permissão em Ajustes do Sistema > Privacidade e Segurança > Gravação de Tela e Áudio do Sistema."
        }
    }

    private func stop(keepStatus: Bool = false) async {
        guard let session else { return }
        self.session = nil
        isRunning = false
        isIdle = false
        idleTask?.cancel()
        idleTask = nil
        gate = nil
        menuBarAnimator.setActive(false)
        audioMeter.setActive(false)
        await session.stop()
        clearVolatile()
        SessionLog.write("PARADO")
        if !keepStatus {
            status = segments.isEmpty ? "Parado." : "Parado. Transcrição salva em Documentos/Mara AI."
        }
    }

    /// Tracks silence: goes on hold, resumes when there is sound, and stops after a long time.
    private func startIdleWatch() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            while !Task.isCancelled, let self, self.isRunning, let gate = self.gate {
                let quiet = gate.secondsSinceSound
                if self.autoStopAfter > 0, quiet >= self.autoStopAfter {
                    let minutes = max(1, Int((self.autoStopAfter / 60).rounded()))
                    SessionLog.write("DESLIGADA por \(Int(quiet))s sem áudio")
                    await self.stop(keepStatus: true)
                    self.status = "Desligada automaticamente após \(minutes) min sem áudio. A transcrição foi salva."
                    return
                }
                if self.isIdle {
                    // On hold: checks every 2 seconds whether sound has come back.
                    if quiet < 2.5 {
                        self.isIdle = false
                        gate.setPaused(false)
                        self.menuBarAnimator.setActive(true)
                        SessionLog.write("VOLTOU da espera")
                    }
                    try? await Task.sleep(for: .seconds(2))
                } else {
                    if self.idleAfter > 0, quiet >= self.idleAfter {
                        self.isIdle = true
                        gate.setPaused(true)
                        self.menuBarAnimator.setActive(false)
                        self.clearVolatile()
                        SessionLog.write("ESPERA após \(Int(quiet))s sem áudio")
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    private func handle(_ text: String, isFinal: Bool) {
        // Apple Speech sometimes delivers the previous sentence's punctuation at the start of the next one
        // (". Coisa linda…"). The mark goes back to the end of the sentence it belongs to.
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let leading = String(trimmed.prefix { ".,;:!?…".contains($0) })
        if !leading.isEmpty {
            trimmed = String(trimmed.dropFirst(leading.count)).trimmingCharacters(in: .whitespaces)
            if isFinal { attachPunctuation(leading) }
        }
        guard isFinal else {
            volatile = trimmed
            SessionLog.write("PARCIAL \(trimmed)")
            if translates {
                translateVolatile()
            } else {
                volatileTranslation = trimmed
            }
            return
        }
        // The provisional translation becomes the sentence's starting point, so the caption doesn't flicker.
        let draft = volatileTranslation
        clearVolatile()
        guard !trimmed.isEmpty else { return }
        SessionLog.write("FINAL \(trimmed)")
        let finalizedAt = Date()

        let context = segments.suffix(3).map(\.original)
        var segment = Segment(original: trimmed)
        guard translates else {
            segment.translation = trimmed
            segment.refined = true
            segments.append(segment)
            saveTranscript()
            return
        }
        segment.translation = draft.isEmpty ? nil : draft
        segments.append(segment)
        saveTranscript()

        let id = segment.id

        if let localFinal {
            Task {
                guard let response = try? await localFinal.translate(trimmed) else {
                    SessionLog.write("APPLE-FINAL falhou")
                    return
                }
                SessionLog.write("APPLE-FINAL \(SessionLog.ms(since: finalizedAt)) \(response.targetText)")
                setTranslation(response.targetText, for: id, refined: false)
            }
        }
        guard gptEnabled else { return }

        let translator = Translator(apiKey: apiKey, model: model, glossary: glossary)
        let language = Locale(identifier: "en").localizedString(forIdentifier: localeID) ?? localeID
        Task {
            do {
                let result = try await translator.translate(trimmed, from: language, context: context)
                let elapsed = recordUsage(result, model: translator.model, since: finalizedAt)
                SessionLog.write("GPT \(elapsed)ms in=\(result.inputTokens) out=\(result.outputTokens) \(result.text)")
                setTranslation(result.text, for: id, refined: true)
            } catch {
                SessionLog.write("GPT falhou: \(error.localizedDescription)")
                status = "Falha ao traduzir pelo GPT: \(error.localizedDescription)"
            }
        }
    }

    @discardableResult
    private func recordUsage(_ result: Translator.Result, model: String, since start: Date) -> Int {
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        usage.record(UsageEntry(
            date: Date(),
            model: model,
            inputTokens: result.inputTokens,
            cachedTokens: result.cachedTokens,
            outputTokens: result.outputTokens,
            reasoningTokens: result.reasoningTokens,
            milliseconds: elapsed,
            costUSD: (Double(result.inputTokens) * inputPrice + Double(result.outputTokens) * outputPrice) / 1_000_000
        ))
        return elapsed
    }

    // MARK: Meeting summary

    /// The summary is an explicit user request, so it only depends on having a key: it works
    /// even with GPT refinement turned off.
    var canSummarize: Bool { !isRunning && !segments.isEmpty && !apiKey.isEmpty && !isSummarizing }

    var summaryURL: URL? {
        transcriptURL.map { $0.deletingPathExtension().appendingPathExtension("resumo.txt") }
    }

    func summarize() {
        guard canSummarize else { return }
        isSummarizing = true
        summaryError = nil
        // The original is more faithful than the translation, and the timestamp helps the model follow the conversation.
        let transcript = segments
            .map { segment in
                "[\(segment.date.formatted(date: .omitted, time: .shortened))] \(segment.original)"
            }
            .joined(separator: "\n")
        let translator = Translator(apiKey: apiKey, model: model, glossary: glossary)
        let title = transcriptTitle
        let destination = summaryURL
        Task {
            defer { isSummarizing = false }
            let startedAt = Date()
            do {
                let today = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
                    + " (" + Date().formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "pt_BR"))) + ")"
                let result = try await translator.summarize(transcript, today: today)
                recordUsage(result, model: translator.model, since: startedAt)
                let parsed = MeetingSummary.parse(result.text)
                summary = parsed.text
                // Action items stay at hand, as a list to go through after the meeting.
                meetingActions = parsed.actions.map {
                    MeetingAction(title: $0.title, owner: $0.owner, due: $0.due, dueDate: $0.dueDate)
                }
                if let destination {
                    try? "Resumo — \(title)\n\n\(parsed.text)\n".write(to: destination, atomically: true, encoding: .utf8)
                }
            } catch {
                summaryError = error.localizedDescription
            }
        }
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copySummary() {
        guard let summary else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    /// Puts late-arriving punctuation at the end of the last utterance, if it doesn't already end in punctuation.
    private func attachPunctuation(_ marks: String) {
        guard let index = segments.indices.last else { return }
        let endsWithPunctuation = { (text: String) in text.last.map { ".,;:!?…".contains($0) } ?? true }
        // Without translation (meeting in Portuguese), the caption is the original itself: both change together.
        let sameText = segments[index].translation == segments[index].original
        if !endsWithPunctuation(segments[index].original) {
            segments[index].original += marks
        }
        if sameText {
            segments[index].translation = segments[index].original
            saveTranscript()
            return
        }
        // In the translation, only the period makes sense (commas and the like depend on the translated sentence).
        if let translation = segments[index].translation, !endsWithPunctuation(translation), marks.contains(where: { ".!?…".contains($0) }) {
            segments[index].translation = translation + String(marks.first { ".!?…".contains($0) }!)
        }
        saveTranscript()
    }

    private func setTranslation(_ translation: String, for id: UUID, refined: Bool) {
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return }
        if segments[index].refined && !refined { return }
        segments[index].translation = translation
        segments[index].refined = refined
        saveTranscript()
    }

    private func clearVolatile() {
        volatile = ""
        volatileTranslation = ""
        volatileGeneration += 1
    }

    /// Translates the sentence in progress. Only one translation runs at a time: when it finishes, it takes the latest text,
    /// so the pace adjusts itself to the translator's speed.
    private func translateVolatile() {
        guard let localPartial, !isTranslatingVolatile else { return }
        isTranslatingVolatile = true
        Task {
            defer { isTranslatingVolatile = false }
            while true {
                let text = volatile
                let generation = volatileGeneration
                guard !text.isEmpty else { break }
                let requestedAt = Date()
                let response = try? await localPartial.translate(text)
                if generation == volatileGeneration, let response {
                    volatileTranslation = response.targetText
                    SessionLog.write("APPLE-PARCIAL \(SessionLog.ms(since: requestedAt)) \(response.targetText)")
                }
                if text == volatile { break }
            }
        }
    }

    private func prepareLocalTranslation() async {
        localPartial = nil
        localFinal = nil
        let source = Locale(identifier: localeID).language
        switch await LanguageAvailability().status(from: source, to: Self.targetLanguage) {
        case .installed:
            makeLocalSessions(from: source)
        case .supported:
            status = "Confirme o download do idioma na janela da Apple para ativar a tradução instantânea."
            var download = TranslationSession.Configuration(source: source, target: Self.targetLanguage)
            if translationDownload == download {
                download = translationDownload ?? download
                download.invalidate()
            }
            translationDownload = download
        default:
            if !gptEnabled {
                status = "A Apple não traduz este idioma para português e o GPT está desligado: só o original aparece."
            }
        }
    }

    /// Called by the view when Apple delivers the session that can download the language.
    func finishLocalDownload(with session: TranslationSession) async {
        guard let source = session.sourceLanguage else { return }
        do {
            try await session.prepareTranslation()
            makeLocalSessions(from: source)
            if isRunning { status = "" }
        } catch {
            status = "Tradução local indisponível: \(error.localizedDescription)"
        }
    }

    private func makeLocalSessions(from source: Locale.Language) {
        localPartial = TranslationSession(installedSource: source, target: Self.targetLanguage)
        localFinal = TranslationSession(installedSource: source, target: Self.targetLanguage)
    }

    func openTranscriptsFolder() {
        try? FileManager.default.createDirectory(at: Self.transcriptsFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.transcriptsFolder)
    }

    /// Each session (Iniciar → Parar) becomes a new file.
    private func beginTranscript() {
        segments = []
        summary = nil
        summaryError = nil
        meetingActions = []
        let language = displayName(Locale(identifier: localeID))
        let now = Date()
        let fileStamp = now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            + " " + now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                .replacingOccurrences(of: ":", with: ".")
        transcriptTitle = "Reunião de \(now.formatted(date: .numeric, time: .shortened)) (\(language))"
        transcriptURL = Self.transcriptsFolder.appendingPathComponent("\(fileStamp) \(language).txt")
    }

    /// Rewrites the file on every sentence, so nothing is lost if the app closes mid-meeting.
    private func saveTranscript() {
        guard let transcriptURL, !segments.isEmpty else { return }
        let body = segments.map { segment in
            let time = segment.date.formatted(date: .omitted, time: .standard)
            let translation = segment.translation == segment.original ? nil : segment.translation
            return (["[\(time)]", translation, segment.original].compactMap { $0 }).joined(separator: "\n")
        }
        let text = transcriptTitle + "\n\n" + body.joined(separator: "\n\n") + "\n"
        do {
            try FileManager.default.createDirectory(at: Self.transcriptsFolder, withIntermediateDirectories: true)
            try text.write(to: transcriptURL, atomically: true, encoding: .utf8)
        } catch {
            status = "Não foi possível salvar a transcrição: \(error.localizedDescription)"
        }
    }
}

/// Log of the current session with millisecond timestamps, to measure the real delay of each stage.
/// Stays on the Mac only and is overwritten on every Iniciar.
@MainActor
enum SessionLog {
    static let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/MaraAI/sessao.log")
    private static var handle: FileHandle?
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func begin() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
    }

    static func write(_ message: String) {
        try? handle?.write(contentsOf: Data("\(clock.string(from: Date())) \(message)\n".utf8))
    }

    static func ms(since date: Date) -> String {
        "\(Int(Date().timeIntervalSince(date) * 1000))ms"
    }
}
