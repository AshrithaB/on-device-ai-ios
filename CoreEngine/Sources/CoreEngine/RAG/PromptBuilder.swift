import Foundation

/// Builds RAG prompts from search results with citation tracking
public struct PromptBuilder {
    /// Configuration for prompt building
    public struct Config {
        /// Maximum number of context chunks to include
        public let maxContextChunks: Int

        /// Maximum tokens for context section (approximate)
        public let maxContextTokens: Int

        /// System prompt to use
        public let systemPrompt: String

        public init(
            maxContextChunks: Int = 5,
            maxContextTokens: Int = 2048,
            systemPrompt: String = Config.defaultSystemPrompt
        ) {
            self.maxContextChunks = maxContextChunks
            self.maxContextTokens = maxContextTokens
            self.systemPrompt = systemPrompt
        }

        public static let defaultSystemPrompt = """
            You are a helpful AI assistant. Answer the user's question based on the provided context.
            Use citation markers like [1], [2] to reference the context sources.
            If the context does not contain sufficient information to answer the question, say so clearly.
            Be concise and accurate.
            """
    }

    private let config: Config

    public init(config: Config = Config()) {
        self.config = config
    }

    /// Build a RAG prompt from search results
    /// - Parameters:
    ///   - query: The user's question
    ///   - searchResults: Relevant chunks from vector search
    ///   - documents: Map of document ID to document (for citation metadata)
    /// - Returns: Tuple of (formatted prompt, citations array)
    public func buildPrompt(
        query: String,
        searchResults: [SearchResult],
        documents: [String: Document] = [:]
    ) -> (prompt: String, citations: [Citation]) {
        // Handle empty results
        guard !searchResults.isEmpty else {
            let emptyPrompt = buildEmptyContextPrompt(query: query)
            return (emptyPrompt, [])
        }

        // Select top chunks within budget
        let selectedResults = selectChunks(from: searchResults)

        // Build citations
        let citations = buildCitations(from: selectedResults, documents: documents)

        // Build context section
        let contextSection = buildContextSection(citations: citations)

        // Assemble final prompt
        let prompt = """
            System: \(config.systemPrompt)

            Context:
            \(contextSection)

            Question: \(query)

            Answer:
            """

        return (prompt, citations)
    }

    // MARK: - Private Helpers

    /// Select chunks within token budget
    private func selectChunks(from results: [SearchResult]) -> [SearchResult] {
        var selected: [SearchResult] = []
        var tokenCount = 0

        for result in results.prefix(config.maxContextChunks) {
            let chunkTokens = result.chunk.tokenCount

            // Check if adding this chunk would exceed budget
            if tokenCount + chunkTokens > config.maxContextTokens {
                break
            }

            selected.append(result)
            tokenCount += chunkTokens
        }

        // Ensure at least one chunk if available
        if selected.isEmpty && !results.isEmpty {
            selected.append(results[0])
        }

        return selected
    }

    /// Build citations from search results
    private func buildCitations(from results: [SearchResult], documents: [String: Document]) -> [Citation] {
        return results.enumerated().map { index, result in
            // Create snippet (truncate if very long)
            let snippet = truncateSnippet(result.chunk.content)

            // Look up document metadata
            let document = documents[result.chunk.documentId]
            let documentTitle = document?.title ?? "Unknown Document"
            let documentSource = document?.source

            return Citation(
                number: index + 1,  // 1-based numbering
                chunkId: result.chunk.id,
                documentId: result.chunk.documentId,
                documentTitle: documentTitle,
                documentSource: documentSource,
                snippet: snippet,
                relevanceScore: result.score
            )
        }
    }

    /// Build the context section with citation markers
    private func buildContextSection(citations: [Citation]) -> String {
        return citations.map { citation in
            "[\(citation.number)] \(citation.snippet)"
        }.joined(separator: "\n\n")
    }

    /// Build prompt for when no context is available
    private func buildEmptyContextPrompt(query: String) -> String {
        return """
            System: \(config.systemPrompt)

            Context:
            [No relevant information found in the knowledge base]

            Question: \(query)

            Answer:
            """
    }

    /// Truncate snippet to reasonable length (first ~500 chars)
    private func truncateSnippet(_ text: String, maxLength: Int = 500) -> String {
        if text.count <= maxLength {
            return text
        }

        let truncated = String(text.prefix(maxLength))
        return truncated + "..."
    }
}
