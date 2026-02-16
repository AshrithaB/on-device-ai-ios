import XCTest
@testable import CoreEngine

final class ChunkerTests: XCTestCase {

    func testBasicChunking() {
        let chunker = TextChunker(config: ChunkConfig(chunkSize: 10, minChunkSize: 3))

        // Create text with exactly 25 tokens
        let words = (1...25).map { "word\($0)" }
        let text = words.joined(separator: " ")

        let chunks = chunker.chunk(text)

        // Should create 3 chunks: [10 tokens, 10 tokens, 5 tokens]
        XCTAssertEqual(chunks.count, 3)

        // Verify first chunk
        XCTAssertEqual(chunks[0].tokenCount, 10)
        XCTAssertEqual(chunks[0].chunkIndex, 0)
        XCTAssertTrue(chunks[0].content.hasPrefix("word1"))

        // Verify second chunk
        XCTAssertEqual(chunks[1].tokenCount, 10)
        XCTAssertEqual(chunks[1].chunkIndex, 1)
        XCTAssertTrue(chunks[1].content.hasPrefix("word11"))

        // Verify third chunk
        XCTAssertEqual(chunks[2].tokenCount, 5)
        XCTAssertEqual(chunks[2].chunkIndex, 2)
        XCTAssertTrue(chunks[2].content.hasPrefix("word21"))
    }

    func testEmptyText() {
        let chunker = TextChunker()
        let chunks = chunker.chunk("")

        XCTAssertEqual(chunks.count, 0)
    }

    func testWhitespaceOnlyText() {
        let chunker = TextChunker()
        let chunks = chunker.chunk("   \n\n  \t  ")

        XCTAssertEqual(chunks.count, 0)
    }

    func testMinChunkSize() {
        let chunker = TextChunker(config: ChunkConfig(chunkSize: 100, minChunkSize: 10))

        // Text with only 5 tokens (less than minChunkSize)
        let text = "one two three four five"
        let chunks = chunker.chunk(text)

        // Should still create a chunk because it's the last (and only) one
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].tokenCount, 5)
    }

    func testTextNormalization() {
        let chunker = TextChunker()

        // Text with irregular whitespace
        let text = "This   has    irregular\n\n\nwhitespace    everywhere"
        let chunks = chunker.chunk(text)

        XCTAssertEqual(chunks.count, 1)
        // Normalized text should have single spaces
        XCTAssertFalse(chunks[0].content.contains("  "))
    }

    func testLongDocument() {
        let chunker = TextChunker(config: ChunkConfig(chunkSize: 512))

        // Create a document with 2000 tokens
        let words = (1...2000).map { "token\($0)" }
        let text = words.joined(separator: " ")

        let chunks = chunker.chunk(text)

        // Should create 4 chunks: [512, 512, 512, 464]
        XCTAssertEqual(chunks.count, 4)
        XCTAssertEqual(chunks[0].tokenCount, 512)
        XCTAssertEqual(chunks[1].tokenCount, 512)
        XCTAssertEqual(chunks[2].tokenCount, 512)
        XCTAssertEqual(chunks[3].tokenCount, 464)

        // Verify chunk indices are sequential
        for (index, chunk) in chunks.enumerated() {
            XCTAssertEqual(chunk.chunkIndex, index)
        }
    }

    func testChunkContentIntegrity() {
        let chunker = TextChunker(config: ChunkConfig(chunkSize: 5))

        let text = "one two three four five six seven eight nine ten"
        let chunks = chunker.chunk(text)

        // Verify that chunks contain the correct content
        XCTAssertTrue(chunks[0].content.contains("one"))
        XCTAssertTrue(chunks[0].content.contains("five"))
        XCTAssertTrue(chunks[1].content.contains("six"))
        XCTAssertTrue(chunks[1].content.contains("ten"))
    }

    func testTokenizerCountTokens() {
        let tokenizer = Tokenizer()

        XCTAssertEqual(tokenizer.countTokens("hello world"), 2)
        XCTAssertEqual(tokenizer.countTokens("one two three"), 3)
        XCTAssertEqual(tokenizer.countTokens(""), 0)
        XCTAssertEqual(tokenizer.countTokens("   "), 0)
        XCTAssertEqual(tokenizer.countTokens("word"), 1)
    }

    func testTextNormalizerBasic() {
        let normalizer = TextNormalizer()

        // Test whitespace normalization
        let text1 = "hello    world"
        XCTAssertEqual(normalizer.normalize(text1), "hello world")

        // Test newline normalization
        let text2 = "line1\r\nline2\rline3\nline4"
        let normalized2 = normalizer.normalize(text2)
        XCTAssertFalse(normalized2.contains("\r"))

        // Test multiple newlines
        let text3 = "para1\n\n\n\npara2"
        let normalized3 = normalizer.normalize(text3)
        XCTAssertFalse(normalized3.contains("\n\n\n"))
    }
}
