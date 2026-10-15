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

/// The icon's dot-matrix "M", with its lavender dot. The dots pop in from left to right when
/// `shown` turns on. Used large in the introduction and small in the empty captions window.
struct DotMark: View {
    let shown: Bool
    var dot: CGFloat = 8.5
    var spacing: CGFloat = 4.5
    /// The same 5 × 5 "M" as the menu bar icon (see `Theme.menuBarImage`).
    private let dots = ["x...x", "xx.xx", "x.x.x", "x...x", "x...x"].map { $0.map { $0 == "x" } }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(dots.indices, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(dots[row].indices, id: \.self) { column in
                        Circle()
                            .fill(row == 2 && column == 2 ? Theme.accent : Theme.paper)
                            .frame(width: dot, height: dot)
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

/// Primary button: a lavender pill with dark text. `large` is the introduction's size.
struct PillButtonStyle: ButtonStyle {
    var prominent = true
    var large = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 13.5 : 12, weight: large ? .semibold : .medium))
            .padding(.horizontal, large ? 20 : 12)
            .padding(.vertical, large ? 8 : 5)
            .foregroundStyle(prominent ? Theme.ink : Theme.paper)
            .background(prominent ? Theme.accent : Theme.paper.opacity(0.12), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// Language icon that opens the menu for the meeting and caption languages.
struct LanguageMenu: View {
    @EnvironmentObject private var model: CaptionModel
    /// Just the globe, for tight spots like the captions window's control bar; the language is
    /// still in the tooltip and the menu.
    var iconOnly = false
    @State private var anchor = MenuAnchor()

    var body: some View {
        if iconOnly {
            // A SwiftUI button like its neighbors, so it animates with them (a native Menu ignores
            // the hover entrance's offset and pops in on its own), opening the native menu below it.
            IconButton(symbol: "globe", help: help) {
                anchor.show([
                    MenuAnchor.Section(
                        title: localized("Reunião em"),
                        items: model.locales.map { (model.displayName($0), $0.identifier) },
                        selected: model.localeID
                    ) { model.localeID = $0 },
                    MenuAnchor.Section(
                        title: localized("Legenda em"),
                        items: CaptionLanguage.all.map { ($0.name, $0.id) },
                        selected: model.captionLanguageID
                    ) { model.captionLanguageID = $0 },
                ])
            }
            .background(MenuAnchorView(anchor: anchor))
            .disabled(model.isRunning || model.isStarting)
        } else {
            menu
        }
    }

    private var menu: some View {
        Menu {
            Picker(localized("Reunião em"), selection: $model.localeID) {
                ForEach(model.locales, id: \.identifier) { locale in
                    Text(model.displayName(locale)).tag(locale.identifier)
                }
            }
            .pickerStyle(.inline)
            Picker(localized("Legenda em"), selection: $model.captionLanguageID) {
                ForEach(CaptionLanguage.all) { language in
                    Text(language.name).tag(language.id)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(model.languagePair, systemImage: "globe")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11.5, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(help)
        .disabled(model.isRunning || model.isStarting)
    }

    private var help: String {
        let locale = Locale(identifier: model.localeID)
        let meeting = CaptionLanguage.matching(locale)?.inlineName ?? model.displayName(locale)
        return localized("Reunião em \(meeting), legenda em \(model.captionLanguage.inlineName)")
    }
}

/// Pops up a native menu right below the view it is attached to (see `MenuAnchorView`).
@MainActor
final class MenuAnchor {
    /// A titled group of choices, one of them checked.
    struct Section {
        let title: String
        let items: [(title: String, id: String)]
        let selected: String
        let pick: (String) -> Void
    }

    fileprivate weak var view: NSView?
    private var sections: [Section] = []

    func show(_ sections: [Section]) {
        guard let view else { return }
        self.sections = sections
        let menu = NSMenu()
        for (index, section) in sections.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            menu.addItem(.sectionHeader(title: section.title))
            for item in section.items {
                let entry = NSMenuItem(title: item.title, action: #selector(choose(_:)), keyEquivalent: "")
                entry.target = self
                entry.tag = index
                entry.representedObject = item.id
                entry.state = item.id == section.selected ? .on : .off
                menu.addItem(entry)
            }
        }
        // The view isn't flipped: y = 0 is its bottom edge, and the menu hangs from that point.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: view)
    }

    @objc private func choose(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String, sections.indices.contains(item.tag) else { return }
        sections[item.tag].pick(id)
    }
}

struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
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
