import XCTest
@testable import CoreEngine

final class PromptBuilderTests: XCTestCase {

    // MARK: - Helper Functions

    /// Create a mock chunk for testing
    private func makeChunk(
        id: String = UUID().uuidString,
        documentId: String = "doc1",
        content: String,
        tokenCount: Int,
        chunkIndex: Int = 0
    ) -> Chunk {
        return Chunk(
            id: id,
            documentId: documentId,
            content: content,
            tokenCount: tokenCount,
            chunkIndex: chunkIndex
        )
    }

    /// Create a mock search result for testing
    private func makeSearchResult(
        content: String,
        tokenCount: Int,
        score: Float,
        rank: Int = 1,
        chunkId: String = UUID().uuidString,
        documentId: String = "doc1"
    ) -> SearchResult {
        let chunk = makeChunk(
            id: chunkId,
            documentId: documentId,
            content: content,
            tokenCount: tokenCount
        )
        return SearchResult(chunk: chunk, score: score, rank: rank)
    }

    // MARK: - Tests

    func testBasicPromptBuilding() {
        let builder = PromptBuilder()
        let results = [
            makeSearchResult(content: "Swift is a programming language.", tokenCount: 10, score: 0.9),
            makeSearchResult(content: "SwiftUI is a framework for building UIs.", tokenCount: 12, score: 0.8)
        ]

        let (prompt, citations) = builder.buildPrompt(query: "What is Swift?", searchResults: results)

        // Verify prompt contains key sections
        XCTAssertTrue(prompt.contains("System:"))
        XCTAssertTrue(prompt.contains("Context:"))
        XCTAssertTrue(prompt.contains("Question: What is Swift?"))
        XCTAssertTrue(prompt.contains("Answer:"))

        // Verify citations
        XCTAssertEqual(citations.count, 2)
        XCTAssertEqual(citations[0].number, 1)
        XCTAssertEqual(citations[1].number, 2)
        XCTAssertEqual(citations[0].score, 0.9)
        XCTAssertEqual(citations[1].score, 0.8)
    }

    func testCitationNumbering() {
        let builder = PromptBuilder()
        let results = [
            makeSearchResult(content: "First chunk", tokenCount: 5, score: 0.9, rank: 1),
            makeSearchResult(content: "Second chunk", tokenCount: 5, score: 0.8, rank: 2),
            makeSearchResult(content: "Third chunk", tokenCount: 5, score: 0.7, rank: 3)
        ]

        let (prompt, citations) = builder.buildPrompt(query: "Test", searchResults: results)

        // Verify sequential numbering
        XCTAssertEqual(citations.count, 3)
        XCTAssertEqual(citations[0].number, 1)
        XCTAssertEqual(citations[1].number, 2)
        XCTAssertEqual(citations[2].number, 3)

        // Verify context contains citation markers
        XCTAssertTrue(prompt.contains("[1]"))
        XCTAssertTrue(prompt.contains("[2]"))
        XCTAssertTrue(prompt.contains("[3]"))
    }

    func testEmptySearchResults() {
        let builder = PromptBuilder()
        let results: [SearchResult] = []

        let (prompt, citations) = builder.buildPrompt(query: "What is AI?", searchResults: results)

        // Should have empty citations
        XCTAssertTrue(citations.isEmpty)

        // Prompt should indicate no context
        XCTAssertTrue(prompt.contains("No relevant information found"))
        XCTAssertTrue(prompt.contains("Question: What is AI?"))
    }

    func testContextFormatting() {
        let builder = PromptBuilder()
        let results = [
            makeSearchResult(content: "Machine learning is a subset of AI.", tokenCount: 10, score: 0.9),
            makeSearchResult(content: "Deep learning uses neural networks.", tokenCount: 10, score: 0.8)
        ]

        let (prompt, citations) = builder.buildPrompt(query: "What is ML?", searchResults: results)

        // Verify context section formatting
        XCTAssertTrue(prompt.contains("[1] Machine learning is a subset of AI."))
        XCTAssertTrue(prompt.contains("[2] Deep learning uses neural networks."))

        // Verify citations match
        XCTAssertEqual(citations[0].snippet, "Machine learning is a subset of AI.")
        XCTAssertEqual(citations[1].snippet, "Deep learning uses neural networks.")
    }

    func testMaxContextChunksLimit() {
        let config = PromptBuilder.Config(maxContextChunks: 2)
        let builder = PromptBuilder(config: config)

        // Create 5 results, but only top 2 should be used
        let results = [
            makeSearchResult(content: "First", tokenCount: 5, score: 0.9),
            makeSearchResult(content: "Second", tokenCount: 5, score: 0.8),
            makeSearchResult(content: "Third", tokenCount: 5, score: 0.7),
            makeSearchResult(content: "Fourth", tokenCount: 5, score: 0.6),
            makeSearchResult(content: "Fifth", tokenCount: 5, score: 0.5)
        ]

        let (prompt, citations) = builder.buildPrompt(query: "Test", searchResults: results)

        // Should only have 2 citations
        XCTAssertEqual(citations.count, 2)
        XCTAssertTrue(prompt.contains("[1] First"))
        XCTAssertTrue(prompt.contains("[2] Second"))
        XCTAssertFalse(prompt.contains("[3]"))
    }

    func testTokenBudgetLimit() {
        // Set very low token budget
        let config = PromptBuilder.Config(maxContextChunks: 10, maxContextTokens: 25)
        let builder = PromptBuilder(config: config)

        // Create chunks that would exceed budget if all included
        let results = [
            makeSearchResult(content: "First chunk", tokenCount: 10, score: 0.9),
            makeSearchResult(content: "Second chunk", tokenCount: 10, score: 0.8),
            makeSearchResult(content: "Third chunk", tokenCount: 10, score: 0.7),  // Would exceed 25
            makeSearchResult(content: "Fourth chunk", tokenCount: 10, score: 0.6)
        ]

        let (prompt, citations) = builder.buildPrompt(query: "Test", searchResults: results)

        // Should only include first 2 chunks (20 tokens total)
        XCTAssertEqual(citations.count, 2)
        XCTAssertTrue(prompt.contains("[1]"))
        XCTAssertTrue(prompt.contains("[2]"))
        XCTAssertFalse(prompt.contains("[3]"))
    }

    func testAtLeastOneChunkIncluded() {
        // Set token budget lower than even one chunk
        let config = PromptBuilder.Config(maxContextChunks: 10, maxContextTokens: 5)
        let builder = PromptBuilder(config: config)

        let results = [
            makeSearchResult(content: "This is a chunk with many tokens", tokenCount: 100, score: 0.9)
        ]

        let (_, citations) = builder.buildPrompt(query: "Test", searchResults: results)

        // Should still include at least one chunk
        XCTAssertEqual(citations.count, 1)
    }

    func testSnippetTruncation() {
        let builder = PromptBuilder()

        // Create very long content (>500 chars)
        let longContent = String(repeating: "word ", count: 200)  // ~1000 chars
        let results = [
            makeSearchResult(content: longContent, tokenCount: 200, score: 0.9)
        ]

        let (_, citations) = builder.buildPrompt(query: "Test", searchResults: results)

        // Snippet should be truncated and end with "..."
        XCTAssertTrue(citations[0].snippet.count <= 504)  // 500 + "..." = 503
        if citations[0].snippet.count > 500 {
            XCTAssertTrue(citations[0].snippet.hasSuffix("..."))
        }
    }

    func testCitationMetadata() {
        let builder = PromptBuilder()
        let chunkId = "test-chunk-id"
        let documentId = "test-doc-id"

        let results = [
            makeSearchResult(
                content: "Test content",
                tokenCount: 5,
                score: 0.85,
                chunkId: chunkId,
                documentId: documentId
            )
        ]

        let (_, citations) = builder.buildPrompt(query: "Test", searchResults: results)

        XCTAssertEqual(citations[0].chunkId, chunkId)
        XCTAssertEqual(citations[0].documentId, documentId)
        XCTAssertEqual(citations[0].score, 0.85)
    }

    func testCustomSystemPrompt() {
        let customPrompt = "You are a test assistant."
        let config = PromptBuilder.Config(systemPrompt: customPrompt)
        let builder = PromptBuilder(config: config)

        let results = [
            makeSearchResult(content: "Test", tokenCount: 5, score: 0.9)
        ]

        let (prompt, _) = builder.buildPrompt(query: "Test", searchResults: results)

        XCTAssertTrue(prompt.contains(customPrompt))
    }

    func testPromptStructure() {
        let builder = PromptBuilder()
        let results = [
            makeSearchResult(content: "Test content", tokenCount: 5, score: 0.9)
        ]

        let (prompt, _) = builder.buildPrompt(query: "What is testing?", searchResults: results)

        // Verify prompt has correct structure and order
        let systemIndex = prompt.range(of: "System:")?.lowerBound
        let contextIndex = prompt.range(of: "Context:")?.lowerBound
        let questionIndex = prompt.range(of: "Question:")?.lowerBound
        let answerIndex = prompt.range(of: "Answer:")?.lowerBound

        XCTAssertNotNil(systemIndex)
        XCTAssertNotNil(contextIndex)
        XCTAssertNotNil(questionIndex)
        XCTAssertNotNil(answerIndex)

        // Verify order
        XCTAssertTrue(systemIndex! < contextIndex!)
        XCTAssertTrue(contextIndex! < questionIndex!)
        XCTAssertTrue(questionIndex! < answerIndex!)
    }
}
