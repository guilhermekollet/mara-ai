import Foundation

/// Grapheme-to-phoneme conversion for Spanish (Mara removed the other languages it covered).
///
/// Rule-based orthography→IPA conversion. Each language has specific rules for
/// digraphs, accent handling, and context-dependent pronunciation.
final class LatinPhonemizer {

    enum Language {
        case spanish
    }

    private let language: Language

    init(language: Language) {
        self.language = language
    }

    // MARK: - Public API

    func phonemize(_ text: String) -> String {
        let words = tokenize(text)
        var result = ""
        var lastWasWord = false

        for token in words {
            switch token {
            case .word(let w):
                if lastWasWord { result += " " }
                result += convertWord(w.lowercased())
                lastWasWord = true
            case .punctuation(let p):
                result += p
                lastWasWord = false
            case .space:
                lastWasWord = false
            }
        }

        return result
    }

    // MARK: - Tokenization

    private enum Token {
        case word(String)
        case punctuation(String)
        case space
    }

    private func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""

        for ch in text {
            if ch.isWhitespace {
                if !current.isEmpty { tokens.append(.word(current)); current = "" }
                tokens.append(.space)
            } else if ch.isLetter || ch == "'" || ch == "'" || ch == "-" {
                current.append(ch)
            } else if ch.isPunctuation || ch.isSymbol {
                if !current.isEmpty { tokens.append(.word(current)); current = "" }
                tokens.append(.punctuation(String(ch)))
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(.word(current)) }

        return tokens
    }

    // MARK: - Word Conversion

    /// Public word-level phonemization for dictionary fallback.
    func phonemizeWord(_ word: String) -> String {
        return convertWord(word.lowercased())
    }

    private func convertWord(_ word: String) -> String {
        var ipa: String
        switch language {
        case .spanish: ipa = spanishToIPA(word)
        }

        // Apply E2M mappings to match Kokoro's training format.
        // Kokoro was trained with espeak-ng output post-processed by misaki.
        // These replace multi-char IPA sequences with single-char equivalents.
        for (from, to) in Self.e2mMappings {
            ipa = ipa.replacingOccurrences(of: from, with: to)
        }

        // Add primary stress mark for multi-syllable words.
        if ipa.count >= 4 {
            return "ˈ" + ipa
        }
        return ipa
    }

    // MARK: - E2M Post-Processing (Kokoro Training Format)

    /// Mappings from standard IPA to Kokoro's internal format.
    /// Sorted longest-first for correct greedy replacement.
    private static let e2mMappings: [(from: String, to: String)] = [
        // Affricates → ligatures (multi-char to single)
        ("dʒ", "ʤ"), ("tʃ", "ʧ"), ("dz", "ʣ"),
        // Consonant normalizations
        ("ʁ", "ɹ"),     // French/German uvular → alveolar approximant
        ("ɐ", "ə"),     // Near-open central → schwa
    ]

    // MARK: - Spanish G2P

    /// Spanish is very regular — nearly 1:1 grapheme-to-phoneme.
    private static let spanishRules: [(pattern: String, ipa: String)] = [
        // Digraphs
        ("ch", "tʃ"), ("ll", "ʝ"), ("rr", "rː"), ("qu", "k"),
        ("gu", "ɡ"), ("gü", "ɡw"),
        ("ñ", "ɲ"),
        // Accented vowels (stressed — add length)
        ("á", "aː"), ("é", "eː"), ("í", "iː"), ("ó", "oː"), ("ú", "uː"), ("ü", "w"),
        // Basic
        ("a", "a"), ("b", "b"), ("c", "k"), ("d", "d"), ("e", "e"),
        ("f", "f"), ("g", "ɡ"), ("h", ""), ("i", "i"), ("j", "x"),
        ("k", "k"), ("l", "l"), ("m", "m"), ("n", "n"), ("o", "o"),
        ("p", "p"), ("r", "ɾ"), ("s", "s"), ("t", "t"), ("u", "u"),
        ("v", "b"), ("w", "w"), ("x", "ks"), ("y", "ʝ"), ("z", "θ"),
    ]

    private func spanishToIPA(_ word: String) -> String {
        var result = ""
        let chars = Array(word)
        var i = 0

        while i < chars.count {
            // Context: c before e/i = θ, g before e/i = x
            if i + 1 < chars.count {
                if chars[i] == "c" && "eiéí".contains(chars[i+1]) {
                    result += "θ"
                    i += 1
                    continue
                }
                if chars[i] == "g" && "eiéí".contains(chars[i+1]) {
                    result += "x"
                    i += 1
                    continue
                }
            }

            var matched = false
            for len in stride(from: min(2, chars.count - i), through: 1, by: -1) {
                let substr = String(chars[i..<i+len])
                if let rule = Self.spanishRules.first(where: { $0.pattern == substr }) {
                    result += rule.ipa
                    i += len
                    matched = true
                    break
                }
            }
            if !matched {
                result += String(chars[i])
                i += 1
            }
        }

        return result
    }

}
