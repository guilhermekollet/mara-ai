import Foundation

/// A language Mara writes captions and summaries in. When the meeting is already in it, the
/// caption is the transcription itself, with no translation.
struct CaptionLanguage: Identifiable, Equatable {
    /// BCP 47, as Apple's Translation framework takes it.
    let id: String
    /// ISO 639 code, to compare with the meeting language.
    let code: String
    /// The name the GPT prompts use.
    let englishName: String

    var language: Locale.Language { Locale.Language(identifier: id) }

    /// The name in the interface's language, as it reads in a sentence: "inglês" in Portuguese,
    /// "English" in English.
    var inlineName: String { Interface.locale.localizedString(forLanguageCode: code) ?? englishName }

    /// The name on its own, as in a menu: "Inglês", "English".
    var name: String { inlineName.capitalized(with: Interface.locale) }

    static let all = [
        CaptionLanguage(id: "pt-BR", code: "pt", englishName: "Brazilian Portuguese"),
        CaptionLanguage(id: "en-US", code: "en", englishName: "English"),
        CaptionLanguage(id: "es-ES", code: "es", englishName: "Spanish"),
    ]

    static func with(id: String) -> CaptionLanguage {
        all.first { $0.id == id } ?? all[0]
    }

    /// The language of a meeting locale (for example "es_MX"), when Mara can caption in it.
    static func matching(_ locale: Locale) -> CaptionLanguage? {
        all.first { $0.code == locale.language.languageCode?.identifier }
    }

    /// The default for a new install: the Mac's own language when Mara captions in it, else English.
    static func preferred(for locale: Locale = .current) -> CaptionLanguage {
        matching(locale) ?? all[1]
    }
}
