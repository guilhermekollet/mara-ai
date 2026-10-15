import SwiftUI
import Translation

@main
struct MaraAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = CaptionModel()

    init() {
        // Development tool: `MaraAI --render-summary file.png` draws the summary window with a
        // sample summary and exits, so it can be checked without an OpenAI key or a meeting.
        if let flag = CommandLine.arguments.firstIndex(of: "--render-summary"), CommandLine.arguments.count > flag + 1 {
            SummaryView.renderSample(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
            exit(0)
        }
    }

    var body: some Scene {
        Window("Mara AI", id: captionsWindowID) {
            ContentView()
                .environmentObject(model)
                .background(FloatingWindow())
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 520, height: 150)

        Window(localized("Resumo da Mara"), id: summaryWindowID) {
            SummaryView().environmentObject(model)
        }
        .windowResizability(.contentSize)

        Window(localized("Ajustes da Mara"), id: settingsWindowID) {
            SettingsView().environmentObject(model)
        }
        .windowResizability(.contentSize)

        Window(localized("Boas-vindas à Mara"), id: onboardingWindowID) {
            OnboardingView().environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarPanel().environmentObject(model)
        } label: {
            MenuBarLabel(animator: model.menuBarAnimator).environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

let captionsWindowID = "captions"

/// Starts the update checks on launch and puts a downloaded update in place on quit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Updater.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Updater.shared.installIfReady(relaunch: false)
    }
}

/// Opens one of the app's windows in front of everything, on the screen the pointer is on.
/// SwiftUI puts a window back where it was last closed, which can be another monitor the person
/// isn't looking at, and activating the app alone doesn't raise it on recent macOS versions.
@MainActor
func present(_ id: String, using openWindow: OpenWindowAction) {
    openWindow(id: id)
    NSApp.activate()
    // SwiftUI creates the window in this pass of the run loop; it exists by the next one.
    DispatchQueue.main.async {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == id }) else { return }
        let pointer = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }),
           window.screen?.frame != screen.frame {
            // Moves without resizing: resizing windows during layout has crashed AppKit on macOS 26.
            let area = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2, y: area.midY - window.frame.height / 2))
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

/// Menu bar icon. Since it is always alive, it is the one that hands the model the action that
/// opens the captions window, used by the global shortcuts, and that opens the introduction on
/// first launch.
struct MenuBarLabel: View {
    @EnvironmentObject private var model: CaptionModel
    @ObservedObject var animator: MenuBarAnimator
    @Environment(\.openWindow) private var openWindow
    /// The introduction opens once per launch, even if the menu bar redraws the icon.
    @State private var offeredIntroduction = false

    var body: some View {
        // When stopped, the icon is static; while listening, a shimmer wave runs across the dots of the "M".
        Image(nsImage: animator.image)
            .onAppear {
                model.openCaptions = { openWindow(id: captionsWindowID) }
                if !Onboarding.isDone && !offeredIntroduction {
                    offeredIntroduction = true
                    DispatchQueue.main.async { present(onboardingWindowID, using: openWindow) }
                }
            }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: CaptionModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var hovering = false
    /// True while the list follows new utterances (scrolled to the bottom).
    @State private var followsLatest = true
    /// True while the user is scrolling (dragging or coasting on momentum).
    @State private var userScrolling = false
    /// The jump-to-latest button shows only its arrow; its label slides in once the list has been
    /// left still for a while, so it doesn't cover captions while someone is rereading.
    @State private var showsJumpLabel = false
    @State private var jumpLabelTimer: Task<Void, Never>?
    /// Going on standby, the moon opens in the middle of the window for a moment, with the
    /// captions stepping back, before it settles at the top in place of the sound bars.
    @State private var standbyIntro = false
    @State private var standbyIntroTimer: Task<Void, Never>?
    /// The dotted "M" builds itself when the window opens.
    @State private var markShown = false
    private let bottomID = "bottom"
    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        ZStack(alignment: .top) {
            captions
                .opacity(standbyIntro ? 0.12 : 1)
                .animation(.easeInOut(duration: 0.4), value: standbyIntro)
            // The controls only appear on hover, so the window is nothing but captions.
            controlBar
        }
        .overlay { listeningIndicator }
        .animation(.spring(response: 0.6, dampingFraction: 0.86), value: indicatorInHeader)
        .onChange(of: model.isIdle) { _, idle in showStandbyIntro(idle) }
        .frame(minWidth: 300, minHeight: 96)
        .background {
            ZStack {
                VisualEffectBackground()
                Theme.ink.opacity(model.opacity)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.paper.opacity(0.09), lineWidth: 1))
        .ignoresSafeArea()
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.2)) { hovering = inside }
        }
        .tint(Theme.accent)
        .task { await model.loadLocales() }
        .translationTask(model.translationDownload) { session in
            await model.finishLocalDownload(with: session)
        }
    }

    private var controlBar: some View {
        HStack(spacing: 2) {
            LanguageMenu(iconOnly: true)
                .padding(.leading, 4)
                .modifier(HoverReveal(shown: hovering, order: 0))
            IconButton(
                symbol: model.isRunning ? "stop.fill" : "play.fill",
                help: model.isRunning ? localized("Parar") : localized("Iniciar"),
                color: Theme.accent
            ) { model.toggle() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isStarting)
                .modifier(HoverReveal(shown: hovering, order: 1))
            MicrophoneButton()
                .modifier(HoverReveal(shown: hovering, order: 2))
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .help(model.status)
                    .modifier(HoverReveal(shown: hovering, order: 3))
            }
            Spacer(minLength: 0)
            IconButton(symbol: "doc.on.doc", help: localized("Copiar a transcrição")) { model.copyTranscript() }
                .disabled(model.segments.isEmpty)
                .modifier(HoverReveal(shown: hovering, order: 4))
            IconButton(symbol: "gearshape", help: localized("Ajustes")) { present(settingsWindowID, using: openWindow) }
            .modifier(HoverReveal(shown: hovering, order: 5))
            IconButton(symbol: "xmark", help: localized("Fechar a janela de legendas")) { dismissWindow(id: captionsWindowID) }
                .modifier(HoverReveal(shown: hovering, order: 6))
        }
        .padding(.horizontal, 6)
        .frame(height: 32)
        .background(
            LinearGradient(colors: [Theme.ink.opacity(0.92), Theme.ink.opacity(0)], startPoint: .top, endPoint: .bottom)
                .opacity(hovering ? 1 : 0)
        )
    }

    private var isEmpty: Bool { model.segments.isEmpty && model.volatile.isEmpty }

    private func showStandbyIntro(_ idle: Bool) {
        standbyIntroTimer?.cancel()
        guard idle, !isEmpty else {
            standbyIntro = false
            return
        }
        standbyIntro = true
        standbyIntroTimer = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            standbyIntro = false
        }
    }

    /// On the first utterance, the indicator moves from the middle of the window to the top center.
    private var indicatorInHeader: Bool { !isEmpty && !standbyIntro }

    /// The sound bars (or the moon, when idle). It is a single piece that changes position and size
    /// with a spring, instead of two pieces that appear and disappear.
    @ViewBuilder
    private var listeningIndicator: some View {
        if model.isRunning {
            Group {
                if model.isIdle {
                    IdleBadge(large: true)
                } else {
                    SoundBars(meter: model.audioMeter, height: 26, color: Theme.accent.opacity(0.9))
                        .help(localized("Ouvindo o áudio do Mac"))
                }
            }
            .scaleEffect(indicatorInHeader ? 0.5 : 1)
            // At the top, it is centered within the 32 pt strip of the control bar.
            .frame(height: 26)
            .padding(.top, indicatorInHeader ? 3 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: indicatorInHeader ? .top : .center)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    /// Before the first utterance: the dotted "M" when stopped, the sound bars when listening.
    private var emptyState: some View {
        Group {
            if !model.isRunning {
                DotMark(shown: markShown, dot: 4, spacing: 1.8)
                    .opacity(0.45)
                    .transition(.opacity)
                    .onAppear { markShown = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Scrollable history: the current utterance highlighted and earlier ones fading out upwards.
    private var captions: some View {
        ScrollViewReader { proxy in
            // Only follows new utterances while scrolled to the bottom.
            let follow = { if followsLatest && !userScrolling { proxy.scrollTo(bottomID, anchor: .bottom) } }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(model.segments) { segment in
                        let isLatest = segment.id == model.segments.last?.id && model.volatile.isEmpty
                        VStack(alignment: .leading, spacing: 1) {
                            if segment.speaker == .me {
                                // Yours, from the microphone: labeled and quieter, since the captions are for the others.
                                Text(localized("Você"))
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(Theme.accent.opacity(0.8))
                            }
                            Text(segment.translation ?? "…")
                                .font(.system(size: model.fontSize, weight: .medium))
                                .foregroundStyle(segment.speaker == .me ? Theme.paper.opacity(0.7) : Theme.paper)
                            if segment.translation != segment.original {
                                Text(segment.original)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.paper.opacity(0.4))
                            }
                        }
                        .opacity(isLatest ? 1 : 0.6)
                        .textSelection(.enabled)
                    }
                    if !model.volatile.isEmpty {
                        VStack(alignment: .leading, spacing: 1) {
                            if !model.volatileTranslation.isEmpty {
                                AnimatedWords(text: model.volatileTranslation, size: model.fontSize, color: Theme.accent)
                            }
                            if model.volatileTranslation != model.volatile {
                                Text(model.volatile)
                                    .font(.system(size: 11).italic())
                                    .foregroundStyle(Theme.paper.opacity(0.4))
                            }
                        }
                    }
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
            // Older utterances fade out smoothly at the top instead of being clipped.
            .mask(
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.28), .init(color: .black, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay { if isEmpty { emptyState } }
            // Always starts at the bottom, following new utterances.
            .defaultScrollAnchor(.bottom)
            // Scrolling up to reread pauses following; returning to the bottom resumes it. Only scrolling
            // done by the user counts (dragging or its momentum), never scrolling done by the app itself.
            .onScrollPhaseChange { _, phase, context in
                let geometry = context.geometry
                let fromBottom = geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height
                switch phase {
                case .interacting, .decelerating:
                    userScrolling = true
                    if fromBottom > 28 { followsLatest = false }
                    hideJumpLabel()
                case .idle:
                    if userScrolling { followsLatest = fromBottom < 28 }
                    userScrolling = false
                    if !followsLatest { scheduleJumpLabel() }
                default:
                    break
                }
            }
            .onAppear {
                followsLatest = true
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
            // A new session always starts following the bottom.
            .onChange(of: model.isRunning) {
                if model.isRunning {
                    followsLatest = true
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            // Back to the latest captions: just the arrow in the bottom right corner; after 5 s
            // without scrolling, localized("Falas novas") slides in beside it.
            .overlay(alignment: .bottomTrailing) {
                if !followsLatest {
                    Button {
                        followsLatest = true
                        hideJumpLabel()
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(bottomID, anchor: .bottom) }
                    } label: {
                        HStack(spacing: 5) {
                            if showsJumpLabel {
                                Text(localized("Falas novas"))
                                    .fixedSize()
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, showsJumpLabel ? 10 : 0)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Theme.accent, in: Capsule())
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(localized("Ir para as falas novas"))
                    .padding([.bottom, .trailing], 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .bottomTrailing)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: followsLatest)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showsJumpLabel)
            // Back at the bottom, the next time the button appears it starts as just the arrow.
            .onChange(of: followsLatest) { if followsLatest { hideJumpLabel() } }
            .onChange(of: model.segments.count) { follow() }
            .onChange(of: model.volatile) { follow() }
            .onChange(of: model.volatileTranslation) { follow() }
            .onChange(of: model.segments.last?.translation) { follow() }
        }
    }
}

extension ContentView {
    /// Shows the jump button's label after 5 s with the list still; any scroll starts the wait over.
    fileprivate func scheduleJumpLabel() {
        jumpLabelTimer?.cancel()
        jumpLabelTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, !followsLatest, !userScrolling else { return }
            showsJumpLabel = true
        }
    }

    fileprivate func hideJumpLabel() {
        jumpLabelTimer?.cancel()
        jumpLabelTimer = nil
        showsJumpLabel = false
    }
}

/// Hover entrance for the captions window's controls: they come in one by one, left to right,
/// fading in and settling from slightly above; when the pointer leaves they go out together.
/// No scaling: it makes the SF Symbols look like they jump and blurs them mid-animation.
private struct HoverReveal: ViewModifier {
    let shown: Bool
    let order: Int

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : -3)
            .animation(
                shown
                    ? .spring(response: 0.34, dampingFraction: 0.9).delay(Double(order) * 0.035)
                    : .easeOut(duration: 0.12),
                value: shown
            )
    }
}

/// Idle indicator: the session is paused for lack of audio and resumes on its own when there is sound.
struct IdleBadge: View {
    var large = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: large ? 15 : 10.5))
            Text(localized("Em espera"))
                .font(.system(size: large ? 13 : 10.5, weight: .medium))
        }
        .foregroundStyle(Theme.paper.opacity(0.45))
        .help(localized("Sem áudio há algum tempo. A Mara volta a ouvir sozinha quando houver som."))
    }
}

/// The microphone in the captions window's control bar: lavender while it is on, so it's clear
/// when what you say is being transcribed.
struct MicrophoneButton: View {
    @EnvironmentObject private var model: CaptionModel

    var body: some View {
        IconButton(
            symbol: model.microphoneOn ? "mic.fill" : "mic.slash",
            help: model.microphoneOn
                ? localized("Microfone ligado: o que você diz entra na transcrição (⌃⌥M)")
                : localized("Microfone desligado: só o áudio do Mac é transcrito (⌃⌥M)"),
            color: model.microphoneOn ? Theme.accent : Theme.paper.opacity(0.7)
        ) { model.toggleMicrophone() }
    }
}

/// Subtle icon button for the control bar.
struct IconButton: View {
    let symbol: String
    let help: String
    var color: Color = Theme.paper.opacity(0.7)
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(Theme.paper.opacity(hovering ? 0.12 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// Borderless captions window: floats over the meeting (including in full screen), without the
/// window buttons, and can be dragged from anywhere.
struct FloatingWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Blur of whatever is behind the window, like in system panels.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
