import SwiftUI
import Translation

@main
struct MaraAIApp: App {
    @StateObject private var model = CaptionModel()

    var body: some Scene {
        Window("Mara AI", id: captionsWindowID) {
            ContentView()
                .environmentObject(model)
                .background(FloatingWindow())
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 520, height: 150)

        Window("Ajustes da Mara", id: settingsWindowID) {
            SettingsView().environmentObject(model)
        }
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

/// Menu bar icon. Since it is always alive, it is the one that hands the model the action that
/// opens the captions window, used by the global shortcuts.
struct MenuBarLabel: View {
    @EnvironmentObject private var model: CaptionModel
    @ObservedObject var animator: MenuBarAnimator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // When stopped, the icon is static; while listening, a shimmer wave runs across the dots of the "M".
        Image(nsImage: animator.image)
            .onAppear {
                model.openCaptions = { openWindow(id: captionsWindowID) }
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
    private let bottomID = "bottom"
    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        ZStack(alignment: .top) {
            captions
            // The controls only appear on hover, so the window is nothing but captions.
            controlBar
                .opacity(hovering ? 1 : 0)
        }
        .overlay { listeningIndicator }
        .animation(.spring(response: 0.6, dampingFraction: 0.86), value: indicatorInHeader)
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
            LanguageMenu()
                .padding(.leading, 4)
            IconButton(
                symbol: model.isRunning ? "stop.fill" : "play.fill",
                help: model.isRunning ? "Parar" : "Iniciar",
                color: Theme.accent
            ) { model.toggle() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isStarting)
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .help(model.status)
            }
            Spacer(minLength: 0)
            IconButton(symbol: "doc.on.doc", help: "Copiar a transcrição") { model.copyTranscript() }
                .disabled(model.segments.isEmpty)
            IconButton(symbol: "gearshape", help: "Ajustes") {
                openWindow(id: settingsWindowID)
                NSApp.activate(ignoringOtherApps: true)
            }
            IconButton(symbol: "xmark", help: "Fechar a janela de legendas") { dismissWindow(id: captionsWindowID) }
        }
        .padding(.horizontal, 6)
        .frame(height: 32)
        .background(
            LinearGradient(colors: [Theme.ink.opacity(0.92), Theme.ink.opacity(0)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var isEmpty: Bool { model.segments.isEmpty && model.volatile.isEmpty }

    /// On the first utterance, the indicator moves from the middle of the window to the top center.
    private var indicatorInHeader: Bool { !isEmpty }

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
                        .help("Ouvindo o áudio do Mac")
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

    /// Before the first utterance: the logo when stopped, the sound bars when listening.
    private var emptyState: some View {
        Group {
            if !model.isRunning {
                Text("Mara")
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.paper.opacity(0.35))
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
                            Text(segment.translation ?? "…")
                                .font(.system(size: model.fontSize, weight: .medium))
                                .foregroundStyle(Theme.paper)
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
                case .idle:
                    if userScrolling { followsLatest = fromBottom < 28 }
                    userScrolling = false
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
            .overlay(alignment: .bottom) {
                if !followsLatest {
                    Button {
                        followsLatest = true
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(bottomID, anchor: .bottom) }
                    } label: {
                        Label("Falas novas", systemImage: "arrow.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: followsLatest)
            .onChange(of: model.segments.count) { follow() }
            .onChange(of: model.volatile) { follow() }
            .onChange(of: model.volatileTranslation) { follow() }
            .onChange(of: model.segments.last?.translation) { follow() }
        }
    }
}

/// Idle indicator: the session is paused for lack of audio and resumes on its own when there is sound.
struct IdleBadge: View {
    var large = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: large ? 15 : 10.5))
            Text("Em espera")
                .font(.system(size: large ? 13 : 10.5, weight: .medium))
        }
        .foregroundStyle(Theme.paper.opacity(0.45))
        .help("Sem áudio há algum tempo. A Mara volta a ouvir sozinha quando houver som.")
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
