import CoreGraphics
import Speech
import SwiftUI
import Translation

let onboardingWindowID = "onboarding"

/// The introduction shown on first launch: what Mara does, the permission to hear the Mac's audio,
/// the meeting language (downloaded ahead of time) and, optionally, the OpenAI key for summaries.
enum Onboarding {
    static let doneKey = "onboardingDone"
    /// The step to resume at: macOS asks to reopen the app after granting the permission.
    static let stepKey = "onboardingStep"

    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    /// Quits and opens Mara again, once this process is gone, so macOS applies the permission.
    static func relaunch() {
        let bundle = Bundle.main.bundleURL
        guard bundle.pathExtension == "app" else {
            NSApp.terminate(nil) // Run from a terminal there is no app to reopen.
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", bundle.path]
        try? process.run()
        NSApp.terminate(nil)
    }
}

/// "Screen & System Audio Recording": ScreenCaptureKit needs it even when only audio is captured.
enum ScreenAudioPermission {
    static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system prompt the first time; afterwards it only reports the current state.
    static func request() -> Bool { CGRequestScreenCaptureAccess() }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, permission, language, summary, ready
    }

    @EnvironmentObject private var model: CaptionModel
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage(Onboarding.doneKey) private var done = false
    @AppStorage(Onboarding.stepKey) private var savedStep = 0
    @State private var step = Step.welcome
    /// The direction of the last move, so pages slide the way you are going.
    @State private var forward = true

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                page
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: forward ? 28 : -28)),
                        removal: .opacity.combined(with: .offset(x: forward ? -28 : 28))
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        // A fixed size: the window never resizes between steps (animated window resizing has
        // crashed AppKit on macOS 26; see SettingsView).
        .frame(width: 560, height: 620)
        .background(Theme.ink)
        .foregroundStyle(Theme.paper)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear { step = Step(rawValue: savedStep) ?? .welcome }
        // "Ver a introdução" in Settings starts over even when this window is already open.
        .onChange(of: savedStep) { _, saved in
            if saved != step.rawValue { go(to: Step(rawValue: saved)) }
        }
        .task { await model.loadLocales() }
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome: WelcomePage()
        case .permission: PermissionPage()
        case .language: LanguagePage()
        case .summary: SummaryKeyPage()
        case .ready: ReadyPage()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            PageDots(count: Step.allCases.count, current: step.rawValue)
            Spacer()
            if step != .welcome {
                Button("Voltar") { go(to: Step(rawValue: step.rawValue - 1)) }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Button(primaryTitle) {
                step == .ready ? finish() : go(to: Step(rawValue: step.rawValue + 1))
            }
            .buttonStyle(PillButtonStyle(large: true))
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    private var primaryTitle: String {
        switch step {
        case .summary: return model.apiKey.isEmpty ? "Agora não" : "Continuar"
        case .ready: return "Abrir legendas"
        default: return "Continuar"
        }
    }

    private func go(to next: Step?) {
        guard let next else { return }
        // The direction goes in first, so the page leaving already knows which way to slide.
        forward = next.rawValue > step.rawValue
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { step = next }
            savedStep = next.rawValue
        }
    }

    private func finish() {
        done = true
        dismissWindow(id: onboardingWindowID)
        model.showCaptions()
    }
}

// MARK: Pages

/// The shared layout: a large SF Symbol, a title and a short text, centered, with the page's
/// own content underneath.
private struct PageLayout<Content: View>: View {
    let symbol: String
    let title: String
    let text: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(height: 52)
            Text(title)
                .font(Theme.display(30))
                .multilineTextAlignment(.center)
                .padding(.top, 18)
            Text(text)
                .font(.system(size: 13.5))
                .lineSpacing(2)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            content
                .padding(.top, 26)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 56)
        .padding(.top, 52)
    }
}

private struct WelcomePage: View {
    @State private var shown = false

    private let features: [(symbol: String, title: String, text: String)] = [
        ("captions.bubble", "Legenda ao vivo", "Reuniões, aulas e vídeos em inglês ou espanhol viram legenda em português enquanto as pessoas falam."),
        ("lock.laptopcomputer", "Grátis e privado", "A Apple transcreve e traduz no próprio Mac. O áudio nunca sai do seu computador."),
        ("sparkles", "Resumo com IA", "No fim, um resumo do que foi conversado, feito pelo GPT com a sua chave da OpenAI."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            DotMark(shown: shown)
                .frame(height: 64)
            Text("Boas-vindas à Mara")
                .font(Theme.display(32))
                .padding(.top, 22)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 6)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: shown)
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(.system(size: 14, weight: .semibold))
                            Text(feature.text)
                                .font(.system(size: 12.5))
                                .lineSpacing(1.5)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.9).delay(0.5 + Double(index) * 0.09), value: shown)
                }
            }
            .padding(.top, 34)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 64)
        .padding(.top, 56)
        .onAppear { shown = true }
    }
}

/// The icon's dot-matrix "M", large, with its lavender dot; the dots pop in from left to right.
private struct DotMark: View {
    let shown: Bool
    /// The same 5 × 5 "M" as the menu bar icon (see `Theme.menuBarImage`).
    private let dots = ["x...x", "xx.xx", "x.x.x", "x...x", "x...x"].map { $0.map { $0 == "x" } }

    var body: some View {
        VStack(spacing: 4.5) {
            ForEach(dots.indices, id: \.self) { row in
                HStack(spacing: 4.5) {
                    ForEach(dots[row].indices, id: \.self) { column in
                        Circle()
                            .fill(row == 2 && column == 2 ? Theme.accent : Theme.paper)
                            .frame(width: 8.5, height: 8.5)
                            .opacity(dots[row][column] && shown ? 1 : 0)
                            .scaleEffect(shown ? 1 : 0.3)
                            .animation(.spring(response: 0.42, dampingFraction: 0.62).delay(Double(column) * 0.05 + Double(row) * 0.02), value: shown)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Mara")
    }
}

private struct PermissionPage: View {
    @State private var granted = ScreenAudioPermission.isGranted
    @State private var asked = false

    var body: some View {
        PageLayout(
            symbol: "waveform.badge.mic",
            title: "Deixe a Mara ouvir o Mac",
            text: "Para legendar, a Mara precisa do áudio que sai do Mac: Zoom, Meet, Teams ou o navegador. O macOS chama isso de Gravação de Tela e Áudio do Sistema. A Mara usa só o som: não guarda imagens da tela e não usa o seu microfone."
        ) {
            Group {
                if granted {
                    StatusCard(symbol: "checkmark.circle.fill", title: "Permissão concedida", text: "A Mara já pode ouvir as suas reuniões.")
                } else if !asked {
                    Button("Permitir") {
                        asked = true
                        granted = ScreenAudioPermission.request()
                    }
                    .buttonStyle(PillButtonStyle(large: true))
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ative a Mara em Ajustes do Sistema › Privacidade e Segurança › Gravação de Tela e Áudio do Sistema. Depois, reabra a Mara para o macOS aplicar a permissão.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.paper.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button("Abrir Ajustes do Sistema") { ScreenAudioPermission.openSystemSettings() }
                                .buttonStyle(PillButtonStyle(prominent: false))
                            Button("Reabrir a Mara") { Onboarding.relaunch() }
                                .buttonStyle(PillButtonStyle())
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .animation(.easeOut(duration: 0.2), value: granted)
            .animation(.easeOut(duration: 0.2), value: asked)
        }
        // macOS only reports the change once it applies it, so keep checking while the page is open.
        .task {
            while !Task.isCancelled {
                granted = ScreenAudioPermission.isGranted
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct LanguagePage: View {
    @EnvironmentObject private var model: CaptionModel
    @StateObject private var preparation = LanguagePreparation()

    var body: some View {
        PageLayout(
            symbol: "globe",
            title: "Em que idioma vão falar?",
            text: "A legenda sai sempre em português. A Mara já baixa o que o Mac precisa para esse idioma, e nada fica esperando na primeira reunião."
        ) {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    ForEach(model.locales, id: \.identifier) { locale in
                        let selected = locale.identifier == model.localeID
                        Button {
                            model.localeID = locale.identifier
                        } label: {
                            HStack {
                                Text(model.displayName(locale))
                                    .font(.system(size: 13.5, weight: selected ? .semibold : .regular))
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? Theme.accent : Theme.paper.opacity(0.25))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Theme.paper.opacity(selected ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(selected ? Theme.accent : Theme.paper.opacity(0.08), lineWidth: selected ? 1.5 : 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .disabled(model.isRunning || model.isStarting)
                PreparationStatus(preparation: preparation, retry: { preparation.prepare(localeID: model.localeID) })
            }
        }
        .onAppear { preparation.prepare(localeID: model.localeID) }
        .onChange(of: model.localeID) { _, id in preparation.prepare(localeID: id) }
        .translationTask(preparation.translationDownload) { session in
            await preparation.finishTranslation(with: session)
        }
    }
}

private struct PreparationStatus: View {
    @ObservedObject var preparation: LanguagePreparation
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            switch preparation.state {
            case .checking:
                ProgressView().controlSize(.small)
                label("Conferindo o que o Mac já tem…")
            case .downloading(let fraction):
                VStack(alignment: .leading, spacing: 6) {
                    label("Baixando o modelo de fala… \(Int(fraction * 100))%")
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                }
            case .translating:
                ProgressView().controlSize(.small)
                label("Confirme o download da tradução na janela da Apple.")
            case .ready(let text):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                label(text)
            case .failed(let text):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                label(text)
                Spacer(minLength: 4)
                Button("Tentar de novo", action: retry)
                    .buttonStyle(PillButtonStyle(prominent: false))
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
        .animation(.easeOut(duration: 0.2), value: preparation.state)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.paper.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SummaryKeyPage: View {
    var body: some View {
        PageLayout(
            symbol: "sparkles",
            title: "Resumo com IA",
            text: "Opcional. No fim da reunião, o GPT resume o que foi conversado, com a sua chave da OpenAI. Só o texto transcrito é enviado; o áudio, nunca."
        ) {
            OpenAIKeyField(missingHint: "Fica no Keychain do macOS. Dá para adicionar depois, em Ajustes.")
        }
    }
}

private struct ReadyPage: View {
    var body: some View {
        PageLayout(
            symbol: "checkmark.seal",
            title: "Tudo pronto",
            text: "A Mara fica na barra de menus, no M de pontinhos. Clique nele para começar uma sessão, ou use os atalhos de qualquer app."
        ) {
            VStack(spacing: 18) {
                MenuBarPreview()
                ShortcutList()
                    .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

/// A slice of the menu bar with Mara's icon, which a soft lavender ring keeps pointing out.
private struct MenuBarPreview: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Theme.accent, lineWidth: 1.5)
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulse ? 1.5 : 0.9)
                    .opacity(pulse ? 0 : 0.8)
                Image(nsImage: Theme.menuBarIcon)
                    .renderingMode(.template)
                    .foregroundStyle(Theme.paper)
                    .padding(5)
                    .background(Theme.paper.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Qua 10:24")
                .font(.system(size: 12.5, weight: .medium))
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.paper.opacity(0.85))
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Theme.paper.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

// MARK: Components

private struct StatusCard: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Which step you are on: the current one is a short lavender capsule.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Theme.accent : Theme.paper.opacity(0.22))
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: current)
        .accessibilityElement()
        .accessibilityLabel("Etapa \(current + 1) de \(count)")
    }
}

// MARK: Language preparation

/// Downloads, ahead of the first meeting, the speech model for the meeting language and Apple's
/// translation from it into Portuguese.
@MainActor
final class LanguagePreparation: ObservableObject {
    enum State: Equatable {
        case checking
        case downloading(Double)
        case translating
        case ready(String)
        case failed(String)
    }

    @Published private(set) var state = State.checking
    /// Set when Apple's translation needs a download, which only its own UI can confirm.
    @Published var translationDownload: TranslationSession.Configuration?
    private var task: Task<Void, Never>?
    private var readyText = ""

    func prepare(localeID: String) {
        task?.cancel()
        translationDownload = nil
        state = .checking
        let locale = Locale(identifier: localeID)
        readyText = localeID.hasPrefix("pt")
            ? "Pronto para legendar reuniões em português."
            : "Pronto: fala e tradução para português, no próprio Mac."
        task = Task {
            do {
                if let request = try await TranscriptionSession.modelDownload(for: locale) {
                    state = .downloading(0)
                    let progress = Task {
                        while !Task.isCancelled {
                            state = .downloading(request.progress.fractionCompleted)
                            try? await Task.sleep(for: .milliseconds(200))
                        }
                    }
                    defer { progress.cancel() }
                    try await request.downloadAndInstall()
                }
                guard !Task.isCancelled else { return }
                guard !localeID.hasPrefix("pt") else {
                    state = .ready(readyText)
                    return
                }
                let source = locale.language
                let availability = await LanguageAvailability().status(from: source, to: CaptionModel.targetLanguage)
                // Another language may have been picked meanwhile; its own preparation reports.
                guard !Task.isCancelled else { return }
                switch availability {
                case .installed:
                    state = .ready(readyText)
                case .supported:
                    state = .translating
                    translationDownload = TranslationSession.Configuration(source: source, target: CaptionModel.targetLanguage)
                default:
                    state = .ready("A fala está pronta. A Apple não traduz esse idioma no Mac; a tradução vem do GPT.")
                }
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed("Não foi possível preparar o idioma: \(error.localizedDescription)")
            }
        }
    }

    func finishTranslation(with session: TranslationSession) async {
        do {
            try await session.prepareTranslation()
            state = .ready(readyText)
        } catch {
            state = .failed("A tradução não foi baixada: \(error.localizedDescription)")
        }
    }
}
