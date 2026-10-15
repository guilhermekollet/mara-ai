import AppKit
import Foundation
import Translation

@MainActor
final class CaptionModel: ObservableObject {
    struct Segment: Identifiable, Sendable {
        let id = UUID()
        let date: Date
        /// When it was said, formatted once for the transcript file instead of on every save.
        let clock: String
        var original: String
        var translation: String?
        /// True when the translation is already GPT's final version (the local one doesn't overwrite it).
        var refined = false
        var speaker = Speaker.others

        init(original: String, translation: String? = nil, refined: Bool = false) {
            let now = Date()
            date = now
            clock = now.formatted(date: .omitted, time: .standard)
            self.original = original
            self.translation = translation
            self.refined = refined
        }
    }

    @Published var segments: [Segment] = []
    @Published var volatile = ""
    @Published var volatileTranslation = ""
    /// Triggers the language download through Apple's UI when it isn't installed yet.
    @Published var translationDownload: TranslationSession.Configuration?
    @Published var isRunning = false
    @Published var isStarting = false
    /// The latest meeting summary: what kind of meeting it was and what was talked about.
    @Published private(set) var summary: MeetingSummary?
    @Published private(set) var isSummarizing = false
    @Published private(set) var summaryError: String?

    @Published var status = ""
    @Published var locales: [Locale] = []
    @Published var localeID: String {
        didSet { UserDefaults.standard.set(localeID, forKey: "localeID") }
    }
    /// The language captions and summaries are written in (see `CaptionLanguage`).
    @Published var captionLanguageID: String {
        didSet { UserDefaults.standard.set(captionLanguageID, forKey: "captionLanguage") }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "openaiModel") }
    }
    /// The model that writes summaries, chosen apart from the translation one.
    @Published var summaryModel: String {
        didSet { UserDefaults.standard.set(summaryModel, forKey: "summaryModel") }
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
    let soundCues = SoundCues()
    /// Short sounds when a session starts, stops, goes on hold and comes back, and when the summary
    /// is ready. On by default; turned off in Settings › Appearance.
    @Published var soundCuesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundCuesEnabled, forKey: "soundCues")
            soundCues.enabled = soundCuesEnabled
        }
    }

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
    /// Opens the summary window; set by the views, which own the window environment.
    var openSummary: (() -> Void)?

    /// Team names and terms, used in speech recognition, GPT translation and the summary.
    @Published var glossary: [GlossaryEntry] {
        didSet { GlossaryEntry.save(glossary) }
    }

    /// Also transcribes the microphone, so the transcript and the summary include what you said.
    /// Off by default: Mara can't tell whether you are muted in the meeting app, so you decide.
    @Published private(set) var microphoneOn: Bool {
        didSet { UserDefaults.standard.set(microphoneOn, forKey: "microphoneOn") }
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
    private var microphoneGate: ActivityGate?
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
    private var transcriptURL: URL?
    private var transcriptSave: Task<Void, Never>?
    private var transcriptTitle = ""

    static let transcriptsFolder = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Mara AI", isDirectory: true)

    init() {
        localeID = UserDefaults.standard.string(forKey: "localeID") ?? "en_US"
        // Earlier versions captioned only in Portuguese, so an install that already picked a
        // meeting language keeps it; a new one starts in the Mac's language.
        let existingInstall = UserDefaults.standard.object(forKey: "localeID") != nil
        captionLanguageID = UserDefaults.standard.string(forKey: "captionLanguage")
            ?? (existingInstall ? "pt-BR" : CaptionLanguage.preferred().id)
        model = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o-mini"
        summaryModel = UserDefaults.standard.string(forKey: "summaryModel") ?? GPTModel.catalog[0].id
        apiKey = Keychain.loadAPIKey()
        useGPT = UserDefaults.standard.object(forKey: "useGPT") as? Bool ?? true
        inputPrice = UserDefaults.standard.object(forKey: "inputPrice") as? Double ?? 0.10
        outputPrice = UserDefaults.standard.object(forKey: "outputPrice") as? Double ?? 0.50
        hotKeysEnabled = UserDefaults.standard.object(forKey: "hotKeysEnabled") as? Bool ?? true
        glossary = GlossaryEntry.load()
        idleAfter = UserDefaults.standard.object(forKey: "idleAfter") as? Double ?? 30
        autoStopAfter = UserDefaults.standard.object(forKey: "autoStopAfter") as? Double ?? 300
        soundCuesEnabled = UserDefaults.standard.object(forKey: "soundCues") as? Bool ?? true
        fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 17
        opacity = UserDefaults.standard.object(forKey: "opacity") as? Double ?? 0.55
        // Without the permission (revoked in System Settings, say), it starts off.
        microphoneOn = UserDefaults.standard.bool(forKey: "microphoneOn") && MicrophonePermission.isGranted
        applyHotKeys()
        soundCues.enabled = soundCuesEnabled
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
        case "pt": return localized("Português (Brasil)")
        case "en": return localized("Inglês (Estados Unidos)")
        case "es": return localized("Espanhol")
        default: return Interface.locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        }
    }

    /// Code of the current language, shown next to the language icon.
    var languageCode: String {
        (Locale(identifier: localeID).language.languageCode?.identifier ?? "").uppercased()
    }

    var captionLanguage: CaptionLanguage { CaptionLanguage.with(id: captionLanguageID) }

    /// The languages at a glance: "EN → PT", or just "PT" when the caption needs no translation.
    var languagePair: String {
        translates ? "\(languageCode) → \(captionLanguage.code.uppercased())" : languageCode
    }

    /// A meeting already in the caption language needs no translation: the caption is the
    /// transcription itself.
    var translates: Bool {
        Locale(identifier: localeID).language.languageCode?.identifier != captionLanguage.code
    }

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
            (HotKeys.toggleMicrophone, { [weak self] in self?.toggleMicrophone() }),
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
            .map { segment in
                let original = segment.speaker == .me ? localized("Você: \(segment.original)") : segment.original
                return [segment.translation == segment.original ? nil : segment.translation, original].compactMap { $0 }.joined(separator: "\n")
            }
            .joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func start() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        status = localized("Preparando a transcrição…")

        let session = TranscriptionSession()
        let gate = ActivityGate()
        let microphoneGate = ActivityGate()
        self.gate = gate
        self.microphoneGate = microphoneGate
        let withMicrophone = microphoneOn && MicrophonePermission.isGranted
        do {
            try await session.start(
                locale: Locale(identifier: localeID),
                vocabulary: glossary.map { $0.term.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                gate: gate,
                microphoneGate: microphoneGate,
                withMicrophone: withMicrophone,
                onAudio: { [audioMeter] buffer in audioMeter.push(buffer) },
                onStatus: { [weak self] in self?.status = $0 },
                onResult: { [weak self] text, isFinal, speaker in
                    if speaker == .me {
                        self?.handleMine(text, isFinal: isFinal)
                    } else {
                        self?.handle(text, isFinal: isFinal)
                    }
                },
                onMicrophoneLost: { [weak self] in self?.microphoneLost() },
                onError: { [weak self] error in
                    SessionLog.write("ERRO \(error.localizedDescription)")
                    self?.status = localized("Erro: \(error.localizedDescription)")
                    Task { await self?.stop(keepStatus: true, cue: .failure) }
                }
            )
            self.session = session
            isRunning = true
            // The microphone may have been switched while the session was starting.
            await applyMicrophone()
            soundCues.play(.start)
            menuBarAnimator.setActive(true)
            audioMeter.setActive(true)
            beginTranscript()
            sessionStart = Date()
            SessionLog.begin()
            SessionLog.write("INICIO idioma=\(localeID) modelo=\(gptEnabled ? model : "sem GPT") microfone=\(withMicrophone)")
            if translates {
                status = ""
                await prepareLocalTranslation()
            } else {
                status = ""
            }
            startIdleWatch()
        } catch {
            await session.stop()
            soundCues.play(.failure)
            SessionLog.write("ERRO ao iniciar: \(error.localizedDescription)")
            status = localized("Não foi possível iniciar: \(error.localizedDescription). Confira a permissão em Ajustes do Sistema > Privacidade e Segurança > Gravação de Tela e Áudio do Sistema.")
        }
    }

    private func stop(keepStatus: Bool = false, cue: SoundCues.Cue = .stop) async {
        guard let session else { return }
        self.session = nil
        isRunning = false
        soundCues.play(cue)
        isIdle = false
        idleTask?.cancel()
        idleTask = nil
        gate = nil
        microphoneGate = nil
        menuBarAnimator.setActive(false)
        audioMeter.setActive(false)
        await session.stop()
        clearVolatile()
        await writeTranscript()
        SessionLog.write("PARADO")
        SessionLog.flush()
        if !keepStatus {
            status = segments.isEmpty ? localized("Parado.") : localized("Parado. Transcrição salva em Documentos/Mara AI.")
        }
    }

    /// Tracks silence: goes on hold, resumes when there is sound, and stops after a long time.
    private func startIdleWatch() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            while !Task.isCancelled, let self, self.isRunning, let gate = self.gate {
                // Speaking into the microphone counts as sound too, even if the others are quiet.
                let quiet = min(gate.secondsSinceSound, self.microphoneOn ? self.microphoneGate?.secondsSinceSound ?? .infinity : .infinity)
                if self.autoStopAfter > 0, quiet >= self.autoStopAfter {
                    let minutes = max(1, Int((self.autoStopAfter / 60).rounded()))
                    SessionLog.write("DESLIGADA por \(Int(quiet))s sem áudio")
                    await self.stop(keepStatus: true)
                    self.status = localized("Desligada automaticamente após \(minutes) min sem áudio. A transcrição foi salva.")
                    return
                }
                if self.isIdle {
                    // On hold: checks every 2 seconds whether sound has come back.
                    if quiet < 2.5 {
                        self.isIdle = false
                        self.soundCues.play(.resume)
                        gate.setPaused(false)
                        self.microphoneGate?.setPaused(false)
                        self.menuBarAnimator.setActive(true)
                        self.audioMeter.setActive(true)
                        SessionLog.write("VOLTOU da espera")
                    }
                    try? await Task.sleep(for: .seconds(2))
                } else {
                    if self.idleAfter > 0, quiet >= self.idleAfter {
                        self.isIdle = true
                        self.soundCues.play(.standby)
                        gate.setPaused(true)
                        self.microphoneGate?.setPaused(true)
                        self.menuBarAnimator.setActive(false)
                        // Nothing shows the sound bars on standby: the meter stops until sound returns.
                        self.audioMeter.setActive(false)
                        self.clearVolatile()
                        SessionLog.write("ESPERA após \(Int(quiet))s sem áudio")
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    /// Apple Speech sometimes delivers the previous sentence's punctuation at the start of the next
    /// one (". Coisa linda…"). Returns those marks apart, to go back where they belong.
    /// Whether a result says anything: recognition sometimes returns only punctuation (", , , ,")
    /// out of noise or music, which isn't a caption.
    nonisolated static func hasWords(_ text: String) -> Bool {
        text.contains { $0.isLetter || $0.isNumber }
    }

    private static func splitLeadingPunctuation(_ text: String) -> (marks: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let marks = String(trimmed.prefix { ".,;:!?…".contains($0) })
        return (marks, String(trimmed.dropFirst(marks.count)).trimmingCharacters(in: .whitespaces))
    }

    private func handle(_ text: String, isFinal: Bool) {
        let (leading, trimmed) = Self.splitLeadingPunctuation(text)
        if isFinal && !leading.isEmpty { attachPunctuation(leading, speaker: .others) }
        guard isFinal else {
            guard Self.hasWords(trimmed) else { return }
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
        guard Self.hasWords(trimmed) else { return }
        SessionLog.write("FINAL \(trimmed)")
        let finalizedAt = Date()

        dropEchoes(of: trimmed)
        // Only the others' sentences: what you say doesn't leave the Mac unless you ask for a summary.
        // The last few lines from the others, read from the end so it doesn't scan a long meeting.
        let context = Array(segments.lazy.reversed().filter { $0.speaker == .others }.prefix(3).map(\.original).reversed())
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
        let target = captionLanguage.englishName
        Task {
            do {
                let result = try await translator.translate(trimmed, from: language, to: target, context: context)
                let elapsed = recordUsage(result, model: translator.model, since: finalizedAt)
                SessionLog.write("GPT \(elapsed)ms in=\(result.inputTokens) out=\(result.outputTokens) \(result.text)")
                setTranslation(result.text, for: id, refined: true)
            } catch {
                SessionLog.write("GPT falhou: \(error.localizedDescription)")
                status = localized("Falha ao traduzir pelo GPT: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Microphone

    /// What you said, from the microphone. It isn't translated (you know what you said): it goes
    /// into the captions, the transcript and the summary as yours, unless it is the echo of the
    /// others coming out of the speakers.
    private func handleMine(_ text: String, isFinal: Bool) {
        // Turned off: whatever the recognizer still had pending is not kept.
        guard isFinal, microphoneOn else { return }
        let (leading, trimmed) = Self.splitLeadingPunctuation(text)
        if !leading.isEmpty { attachPunctuation(leading, speaker: .me) }
        guard Self.hasWords(trimmed) else { return }
        let now = Date()
        var heard = Array(segments.lazy.reversed().filter { $0.speaker == .others }.prefix(8).map { ($0.original, now.timeIntervalSince($0.date)) }.reversed())
        if !volatile.isEmpty { heard.append((volatile, 0)) }
        if EchoFilter.isEcho(trimmed, others: heard) {
            SessionLog.write("MICROFONE eco descartado: \(trimmed)")
            return
        }
        SessionLog.write("MICROFONE \(trimmed)")
        var segment = Segment(original: trimmed, translation: trimmed, refined: true)
        segment.speaker = .me
        segments.append(segment)
        saveTranscript()
    }

    /// The others' sentence can finish after its echo from the microphone was already taken as
    /// yours; when it does, that echo goes away.
    private func dropEchoes(of theirs: String) {
        let now = Date()
        let before = segments.count
        segments.removeAll { segment in
            segment.speaker == .me && now.timeIntervalSince(segment.date) <= EchoFilter.window
                && EchoFilter.isEcho(segment.original, others: [(theirs, -now.timeIntervalSince(segment.date))])
        }
        if segments.count != before {
            SessionLog.write("MICROFONE \(before - segments.count) eco(s) removido(s)")
        }
    }

    /// Turns the microphone on or off, asking for the permission the first time. Works during a
    /// session too, without interrupting the Mac's audio.
    func toggleMicrophone() {
        Task { await setMicrophone(!microphoneOn) }
    }

    func setMicrophone(_ on: Bool) async {
        if on && !MicrophonePermission.isGranted {
            guard !MicrophonePermission.wasDenied, await MicrophonePermission.request() else {
                status = localized("Sem permissão para o microfone: ative a Mara em Ajustes do Sistema › Privacidade e Segurança › Microfone.")
                return
            }
        }
        microphoneOn = on
        await applyMicrophone()
    }

    private var applyingMicrophone = false

    /// Brings the session in line with `microphoneOn`. One change at a time: toggles made while
    /// one is under way (a double ⌃⌥M, or during Iniciar) are picked up by the same loop, so the
    /// session never ends up transcribing a microphone shown as off.
    private func applyMicrophone() async {
        guard !applyingMicrophone else { return }
        applyingMicrophone = true
        defer { applyingMicrophone = false }
        while let session, session.microphoneActive != microphoneOn {
            let on = microphoneOn
            do {
                try await session.setMicrophone(on)
                SessionLog.write(on ? "MICROFONE ligado" : "MICROFONE desligado")
            } catch {
                SessionLog.write("ERRO no microfone: \(error.localizedDescription)")
                status = localized("Não foi possível usar o microfone: \(error.localizedDescription)")
                microphoneOn = session.microphoneActive
                return
            }
        }
    }

    /// The microphone stopped working mid-session (permission revoked, device gone): it is turned
    /// off and the captions carry on with the Mac's audio.
    private func microphoneLost() {
        SessionLog.write("MICROFONE perdido")
        microphoneOn = false
        status = localized("O microfone parou de responder e foi desligado. As legendas continuam.")
    }

    @discardableResult
    private func recordUsage(_ result: Translator.Result, model: String, since start: Date) -> Int {
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        // Catalog models have known prices; any other model uses the prices set in Settings.
        let prices = GPTModel.catalog.first { $0.id == model }.map { ($0.inputPrice, $0.outputPrice) } ?? (inputPrice, outputPrice)
        usage.record(UsageEntry(
            date: Date(),
            model: model,
            inputTokens: result.inputTokens,
            cachedTokens: result.cachedTokens,
            outputTokens: result.outputTokens,
            reasoningTokens: result.reasoningTokens,
            milliseconds: elapsed,
            costUSD: (Double(result.inputTokens) * prices.0 + Double(result.outputTokens) * prices.1) / 1_000_000
        ))
        return elapsed
    }

    // MARK: Meeting summary

    /// The summary is an explicit user request, so it only depends on having a key: it works
    /// even with GPT refinement turned off.
    var canSummarize: Bool { !isRunning && !segments.isEmpty && !apiKey.isEmpty && !isSummarizing }

    var summaryURL: URL? {
        transcriptURL.map { $0.deletingPathExtension().appendingPathExtension("resumo.md") }
    }

    /// The meeting's date and length, from its first and last utterance.
    var summaryDetails: String? {
        guard let first = segments.first?.date, let last = segments.last?.date else { return nil }
        let minutes = max(1, Int((last.timeIntervalSince(first) / 60).rounded()))
        return "\(first.formatted(date: .abbreviated, time: .shortened)) · \(minutes) min"
    }

    var summaryMarkdown: String? { summary?.markdown(details: summaryDetails) }

    /// Used only by the development tool that draws the summary window with a sample summary.
    func setSampleSummary(_ sample: MeetingSummary) { summary = sample }

    func summarize() {
        guard canSummarize else { return }
        isSummarizing = true
        summaryError = nil
        let transcript = Self.summaryTranscript(segments)
        let translator = Translator(apiKey: apiKey, model: summaryModel, glossary: glossary)
        let destination = summaryURL
        let language = captionLanguage
        Task {
            defer { isSummarizing = false }
            let startedAt = Date()
            do {
                let (text, calls) = try await translator.summarize(
                    transcript, language: language.englishName, withSpeakers: segments.contains { $0.speaker == .me }
                )
                for call in calls { recordUsage(call, model: translator.model, since: startedAt) }
                summary = MeetingSummary.parse(text, language: language.code)
                soundCues.play(.summaryReady)
                if let destination, let markdown = summaryMarkdown {
                    try? markdown.write(to: destination, atomically: true, encoding: .utf8)
                }
                openSummary?()
            } catch {
                summaryError = error.localizedDescription
                soundCues.play(.failure)
            }
        }
    }

    /// The transcript the summary is written from. The original is more faithful than the
    /// translation, and the timestamp helps the model follow the conversation. When the microphone
    /// was on, each line says whose it is ("Me" for the person the summary is for).
    static func summaryTranscript(_ segments: [Segment]) -> String {
        let speakers = segments.contains { $0.speaker == .me }
        return segments
            .map { segment in
                let time = "[\(segment.date.formatted(date: .omitted, time: .shortened))]"
                guard speakers else { return "\(time) \(segment.original)" }
                return "\(time) \(segment.speaker == .me ? "Me" : "Others"): \(segment.original)"
            }
            .joined(separator: "\n")
    }

    /// Saves the summary as Markdown wherever the user picks.
    func saveSummaryAs() {
        guard let markdown = summaryMarkdown, let summary else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(summary.title).md"
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    func revealSummaryFile() {
        guard let url = summaryURL, FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copySummary() {
        guard let summaryMarkdown else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summaryMarkdown, forType: .string)
    }

    /// Puts late-arriving punctuation at the end of the last utterance, if it doesn't already end in punctuation.
    private func attachPunctuation(_ marks: String, speaker: Speaker) {
        guard let index = segments.lastIndex(where: { $0.speaker == speaker }) else { return }
        let endsWithPunctuation = { (text: String) in text.last.map { ".,;:!?…".contains($0) } ?? true }
        // Without translation (meeting in the caption language), the caption is the original itself:
        // both change together.
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
        let target = captionLanguage.language
        switch await LanguageAvailability().status(from: source, to: target) {
        case .installed:
            makeLocalSessions(from: source)
        case .supported:
            status = localized("Confirme o download do idioma na janela da Apple para ativar a tradução instantânea.")
            var download = TranslationSession.Configuration(source: source, target: target)
            if translationDownload == download {
                download = translationDownload ?? download
                download.invalidate()
            }
            translationDownload = download
        default:
            if !gptEnabled {
                status = localized("A Apple não traduz do idioma da reunião para o \(captionLanguage.inlineName) e o GPT está desligado: só o original aparece.")
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
            status = localized("Tradução local indisponível: \(error.localizedDescription)")
        }
    }

    private func makeLocalSessions(from source: Locale.Language) {
        localPartial = TranslationSession(installedSource: source, target: captionLanguage.language)
        localFinal = TranslationSession(installedSource: source, target: captionLanguage.language)
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
        let language = displayName(Locale(identifier: localeID))
        let now = Date()
        let fileStamp = now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            + " " + now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                .replacingOccurrences(of: ":", with: ".")
        transcriptTitle = localized("Reunião de \(now.formatted(date: .numeric, time: .shortened)) (\(language))")
        transcriptURL = Self.transcriptsFolder.appendingPathComponent("\(fileStamp) \(language).txt")
    }

    /// Saves the transcript a moment after it changes, off the main actor: a long meeting would
    /// otherwise rewrite a growing file on every sentence and every translation. At most the last
    /// two seconds are lost if the app closes mid-meeting; stopping writes it right away.
    private func saveTranscript() {
        guard transcriptSave == nil else { return }
        transcriptSave = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.transcriptSave = nil
            await self.writeTranscript()
        }
    }

    private func writeTranscript() async {
        transcriptSave?.cancel()
        transcriptSave = nil
        guard let transcriptURL, !segments.isEmpty else { return }
        let segments = segments
        let title = transcriptTitle
        let you = localized("Você")
        let failure = await Task.detached(priority: .utility) { () -> String? in
            let body = segments.map { segment in
                let translation = segment.translation == segment.original ? nil : segment.translation
                let stamp = segment.speaker == .me ? "[\(segment.clock)] \(you)" : "[\(segment.clock)]"
                return ([stamp, translation, segment.original].compactMap { $0 }).joined(separator: "\n")
            }
            let text = title + "\n\n" + body.joined(separator: "\n\n") + "\n"
            do {
                try FileManager.default.createDirectory(at: transcriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try text.write(to: transcriptURL, atomically: true, encoding: .utf8)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value
        if let failure {
            status = localized("Não foi possível salvar a transcrição: \(failure)")
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

    /// Lines wait here and go to disk together, about once a second, instead of one write per
    /// partial caption.
    private static var pending = Data()
    private static var lastFlush = Date()
    private static let lock = NSLock()

    static func begin() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        lock.lock()
        handle = try? FileHandle(forWritingTo: url)
        pending.removeAll()
        lastFlush = Date()
        lock.unlock()
    }

    static func write(_ message: String) {
        let now = Date()
        lock.lock()
        defer { lock.unlock() }
        pending.append(Data("\(clock.string(from: now)) \(message)\n".utf8))
        if pending.count > 16_384 || now.timeIntervalSince(lastFlush) >= 1 { flushLocked() }
    }

    /// Writes whatever is waiting; called when a session stops.
    static func flush() {
        lock.lock()
        flushLocked()
        lock.unlock()
    }

    private static func flushLocked() {
        guard !pending.isEmpty else { return }
        try? handle?.write(contentsOf: pending)
        pending.removeAll(keepingCapacity: true)
        lastFlush = Date()
    }

    static func ms(since date: Date) -> String {
        "\(Int(Date().timeIntervalSince(date) * 1000))ms"
    }
}
