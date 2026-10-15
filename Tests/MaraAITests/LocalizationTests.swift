import Testing
@testable import MaraAI

@Suite("Localization")
struct LocalizationTests {
    @Test(arguments: ["en", "es"])
    func everyStringInTheInterfaceIsTranslated(language: String) {
        let keys = localizedKeysInSources()
        #expect(keys.count > 100, "The sources' strings weren't found")
        let translated = Set(translationTable(language).keys.map(normalizedKey))
        let missing = Set(keys).subtracting(translated)
        #expect(missing.isEmpty, "Missing in \(language).lproj: \(missing.sorted())")
    }

    @Test func englishAndSpanishTranslateTheSameStrings() {
        #expect(Set(translationTable("en").keys) == Set(translationTable("es").keys))
    }

    @Test(arguments: ["en", "es"])
    func translationsKeepTheirPlaceholders(language: String) {
        for (key, value) in translationTable(language) {
            #expect(formatSpecifiers(value) == formatSpecifiers(key), "\(language): \(key)")
        }
    }
}
