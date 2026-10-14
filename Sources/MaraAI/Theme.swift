import AppKit
import SwiftUI

/// Mara AI's visual identity: near-black, off-white and lavender as the only accent,
/// the system font and pill-shaped controls.
enum Theme {
    static let ink = Color(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0D / 255)
    static let paper = Color(red: 0xFA / 255, green: 0xFA / 255, blue: 0xFA / 255)
    static let accent = Color(red: 0xB8 / 255, green: 0xA4 / 255, blue: 0xF8 / 255)
    static let muted = paper.opacity(0.6)

    /// Titles in the system font (San Francisco), like the rest of the app.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size * 0.86, weight: .semibold)
    }

    /// The icon's dot-matrix "M", as a template image for the menu bar.
    static let menuBarIcon = menuBarImage(phase: nil)

    /// `phase` (0 to 1) is the position of the shimmer wave and `depth` its strength; with a nil
    /// `phase` the icon is static, with every dot fully filled.
    static func menuBarImage(phase: Double?, depth: Double = 1) -> NSImage {
        let glyph = ["x...x", "xx.xx", "x.x.x", "x...x", "x...x"]
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let step: CGFloat = 3.5
            let dot: CGFloat = 2.5
            let origin = side / 2 - step * 2
            for (row, line) in glyph.enumerated() {
                for (column, mark) in line.enumerated() where mark != "." {
                    // In template images only opacity matters: the wave brightens and dims the dots,
                    // sweeping left to right and slightly top to bottom.
                    var alpha = 1.0
                    if let phase {
                        let position = (Double(column) + Double(row) * 0.35) / 5.4
                        let wave = 0.3 + 0.7 * pow(max(0, cos((phase - position) * 2 * .pi)), 2)
                        alpha = 1 - (1 - wave) * depth
                    }
                    NSColor.black.withAlphaComponent(alpha).setFill()
                    let x = origin + CGFloat(column) * step - dot / 2
                    let y = origin + CGFloat(row) * step - dot / 2
                    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dot, height: dot)).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Primary button: a lavender pill with dark text.
struct PillButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .foregroundStyle(prominent ? Theme.ink : Theme.paper)
            .background(prominent ? Theme.accent : Theme.paper.opacity(0.12), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// Language icon that opens the menu for changing the meeting language.
struct LanguageMenu: View {
    @EnvironmentObject private var model: CaptionModel
    /// Just the globe, for tight spots like the captions window's control bar; the language is
    /// still in the tooltip and the menu.
    var iconOnly = false

    var body: some View {
        Menu {
            Picker("Idioma da reunião", selection: $model.localeID) {
                ForEach(model.locales, id: \.identifier) { locale in
                    Text(model.displayName(locale)).tag(locale.identifier)
                }
            }
            .pickerStyle(.inline)
        } label: {
            if iconOnly {
                Image(systemName: "globe")
                    .font(.system(size: 11.5, weight: .medium))
            } else {
                Label(model.languageCode, systemImage: "globe")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11.5, weight: .medium))
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Idioma da reunião: \(model.languageCode)")
        .disabled(model.isRunning || model.isStarting)
    }
}

/// Animates the menu bar icon: the shimmer wave builds up when listening starts, runs during the
/// session and, on stop, fades out until every dot is fully filled again.
/// Kept separate from the model so the animation doesn't redraw the rest of the UI.
@MainActor
final class MenuBarAnimator: ObservableObject {
    @Published private(set) var image = Theme.menuBarIcon
    private var timer: Timer?
    private var phase = 0.0
    /// Wave strength, from 0 (static icon) to 1.
    private var depth = 0.0
    private var active = false

    func setActive(_ active: Bool) {
        self.active = active
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.step() }
        }
    }

    private func step() {
        phase = (phase + 1.0 / 16).truncatingRemainder(dividingBy: 1)
        // Fades in over about half a second and out over just over one, so the stop is noticeable.
        depth = active ? min(1, depth + 0.16) : max(0, depth - 0.07)
        if depth == 0 {
            timer?.invalidate()
            timer = nil
            image = Theme.menuBarIcon
        } else {
            image = Theme.menuBarImage(phase: phase, depth: depth)
        }
    }
}
