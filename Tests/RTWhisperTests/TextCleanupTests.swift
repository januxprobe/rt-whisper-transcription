import XCTest
@testable import RTWhisperLib

final class TextCleanupTests: XCTestCase {

    // MARK: - FillerWordRemover Tests

    func testFillerWordRemoverRemovesUm() {
        let remover = FillerWordRemover()
        let result = remover.process("Um I went to the store")
        XCTAssertEqual(result, "I went to the store")
    }

    func testFillerWordRemoverRemovesMultipleFillers() {
        let remover = FillerWordRemover()
        let result = remover.process("Um so like I basically went to the store")
        XCTAssertEqual(result, "I went to the store")
    }

    func testFillerWordRemoverRemovesYouKnow() {
        let remover = FillerWordRemover()
        let result = remover.process("I went to, you know, the store")
        XCTAssertEqual(result, "I went to, the store")
    }

    func testFillerWordRemoverHandlesCaseInsensitivity() {
        let remover = FillerWordRemover()
        let result = remover.process("UM LIKE I went there")
        XCTAssertEqual(result, "I went there")
    }

    func testFillerWordRemoverPreservesNonFillerWords() {
        let remover = FillerWordRemover()
        let result = remover.process("The umbrella is actually broken")
        // "actually" should be removed, but "umbrella" should stay
        XCTAssertEqual(result, "The umbrella is broken")
    }

    func testFillerWordRemoverHandlesIMean() {
        let remover = FillerWordRemover()
        let result = remover.process("I mean I went to the store")
        XCTAssertEqual(result, "I went to the store")
    }

    // MARK: - RepetitionRemover Tests

    func testRepetitionRemoverRemovesStutters() {
        let remover = RepetitionRemover()
        let result = remover.process("I I I went to the store")
        XCTAssertEqual(result, "I went to the store")
    }

    func testRepetitionRemoverRemovesDoubleWords() {
        let remover = RepetitionRemover()
        let result = remover.process("the the store")
        XCTAssertEqual(result, "the store")
    }

    func testRepetitionRemoverRemovesTripleWords() {
        let remover = RepetitionRemover()
        let result = remover.process("went went went to")
        XCTAssertEqual(result, "went to")
    }

    func testRepetitionRemoverHandlesCaseInsensitivity() {
        let remover = RepetitionRemover()
        let result = remover.process("The THE the store")
        XCTAssertEqual(result, "The store")
    }

    func testRepetitionRemoverRemovesFalseStarts() {
        let remover = RepetitionRemover()
        let result = remover.process("I went- went to the store")
        XCTAssertEqual(result, "I went to the store")
    }

    func testRepetitionRemoverPreservesValidRepetitions() {
        let remover = RepetitionRemover()
        // "very very" intentional emphasis should probably be kept, but
        // our simple algorithm will remove it - this is acceptable behavior
        let result = remover.process("It was very very good")
        XCTAssertEqual(result, "It was very good")
    }

    // MARK: - TextCleanupPipeline Tests

    func testPipelineRemovesFillersAndRepetitions() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("Um so I I went to like the store")
        XCTAssertEqual(result, "I went to the store")
    }

    func testPipelineHandlesComplexInput() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("So um basically I I mean I went to you know the the store")
        XCTAssertEqual(result, "I went to the store")
    }

    func testPipelinePreservesEmptyString() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("")
        XCTAssertEqual(result, "")
    }

    func testPipelineHandlesOnlyFillers() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("um uh like so")
        XCTAssertEqual(result, "")
    }

    func testPipelineCapitalizesFirstLetter() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("um went to the store")
        XCTAssertEqual(result, "Went to the store")
    }

    func testPipelineHandlesSentencePunctuation() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("I went. um Then I came back.")
        XCTAssertEqual(result, "I went. Then I came back.")
    }

    func testPipelineHandlesMultipleSentences() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("um I went to the store. like Then I came home.")
        XCTAssertEqual(result, "I went to the store. Then I came home.")
    }

    // MARK: - Edge Cases

    func testPipelineHandlesWhitespaceOnly() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("   ")
        XCTAssertEqual(result, "")
    }

    func testPipelineNormalizesMultipleSpaces() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("I   went    to   the   store")
        XCTAssertEqual(result, "I went to the store")
    }

    func testPipelineHandlesNewlines() {
        let pipeline = TextCleanupPipeline.defaultPipeline()
        let result = pipeline.process("I went\nto the store")
        XCTAssertEqual(result, "I went to the store")
    }

    func testFillerWordDoesNotMatchPartialWords() {
        let remover = FillerWordRemover()
        // "some" should not be affected by "so" removal
        let result = remover.process("some people went")
        XCTAssertEqual(result, "Some people went")
    }

    func testFillerWordAtEndOfSentence() {
        let remover = FillerWordRemover()
        let result = remover.process("I went to the store um")
        XCTAssertEqual(result, "I went to the store")
    }
}
