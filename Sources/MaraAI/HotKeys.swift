import AppKit
import Carbon.HIToolbox

/// Global keyboard shortcuts that work no matter which app is in the foreground.
/// Uses Carbon's hot key API, which doesn't require Accessibility permission.
final class HotKeys {
    static let shared = HotKeys()

    struct Shortcut {
        let id: UInt32
        let keyCode: Int
        let keys: String
        let title: String
    }

    /// All of them use Control + Option, a combination meeting apps rarely claim.
    static let toggleSession = Shortcut(id: 1, keyCode: kVK_ANSI_S, keys: "⌃⌥S", title: localized("Iniciar ou parar"))
    static let toggleCaptions = Shortcut(id: 2, keyCode: kVK_ANSI_L, keys: "⌃⌥L", title: localized("Mostrar ou ocultar as legendas"))
    static let toggleMicrophone = Shortcut(id: 3, keyCode: kVK_ANSI_M, keys: "⌃⌥M", title: localized("Ligar ou desligar o microfone"))
    static let toggleReadAloud = Shortcut(id: 4, keyCode: kVK_ANSI_V, keys: "⌃⌥V", title: localized("Ligar ou desligar a leitura em voz alta"))
    static let all = [toggleSession, toggleCaptions, toggleMicrophone, toggleReadAloud]

    private var actions: [UInt32: () -> Void] = [:]
    private var references: [EventHotKeyRef] = []
    private var handlerInstalled = false

    /// Returns false when the system rejects the shortcut (usually because it's already in use).
    @discardableResult
    func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x4D41_5241), id: shortcut.id) // "MARA"
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode), UInt32(controlKey | optionKey), identifier,
            GetApplicationEventTarget(), 0, &reference
        )
        guard status == noErr, let reference else { return false }
        references.append(reference)
        actions[shortcut.id] = action
        return true
    }

    func unregisterAll() {
        references.forEach { UnregisterEventHotKey($0) }
        references = []
        actions = [:]
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var identifier = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &identifier
            )
            let pressed = identifier.id
            DispatchQueue.main.async { HotKeys.shared.actions[pressed]?() }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
