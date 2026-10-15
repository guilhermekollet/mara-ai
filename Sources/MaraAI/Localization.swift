import Foundation

/// The interface's language: Portuguese, English or Spanish, following the Mac, and English on a Mac
/// in any other language. The translations are in Resources/*.lproj, keyed by the Portuguese text.
enum Interface {
    /// The app carries the translations in Contents/Resources (build.sh copies them there); run
    /// straight from .build, they are in SwiftPM's resource bundle. Inside the app `Bundle.module`
    /// can't be used: it looks for that bundle at the root of the .app, where code signing doesn't
    /// allow it.
    private static let resources: Bundle = Bundle.main.bundleURL.pathExtension == "app" ? .main : .module

    static let language = Bundle.preferredLocalizations(from: resources.localizations, forPreferences: Locale.preferredLanguages).first ?? "en"
    static let locale = Locale(identifier: language)

    /// The table for `language`, picked by hand: macOS localizes every bundle like the main one,
    /// which, run from .build, is a bare executable with no translations of its own.
    static let bundle = resources.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? resources
}

/// `text` in the interface's language. A missing translation shows the Portuguese original.
func localized(_ text: String.LocalizationValue) -> String {
    String(localized: text, bundle: Interface.bundle)
}
