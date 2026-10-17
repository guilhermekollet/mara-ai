import Testing
@testable import MaraAI

@Suite("Caption results")
struct CaptionResultTests {
    @Test func dropsResultsWithoutWords() {
        // Recognition sometimes turns noise or music into punctuation only.
        #expect(!CaptionModel.hasWords(", , , , , ,"))
        #expect(!CaptionModel.hasWords("…"))
        #expect(!CaptionModel.hasWords(""))
        #expect(CaptionModel.hasWords("Sure, I'll share it."))
        #expect(CaptionModel.hasWords("42"))
        #expect(CaptionModel.hasWords("¿Qué?"))
    }
}
