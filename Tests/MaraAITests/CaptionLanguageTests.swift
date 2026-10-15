import Testing
@testable import MaraAI

@Suite("Caption language")
struct CaptionLanguageTests {
    @Test func defaultsToTheMacsLanguageWhenMaraCaptionsInIt() {
        #expect(preferredCaptionLanguage(onMacIn: "pt_BR") == "pt-BR")
        #expect(preferredCaptionLanguage(onMacIn: "es_MX") == "es-ES")
        // Any other language falls back to English.
        #expect(preferredCaptionLanguage(onMacIn: "fr_FR") == "en-US")
    }

    @Test func matchesAMeetingLocaleByLanguage() {
        #expect(captionLanguageCode(matching: "en_US") == "en")
        #expect(captionLanguageCode(matching: "es_ES") == "es")
        #expect(captionLanguageCode(matching: "de_DE") == nil)
    }

    @Test func unknownIdentifiersFallBackToTheFirstLanguage() {
        #expect(CaptionLanguage.with(id: "xx").id == CaptionLanguage.all[0].id)
    }
}
