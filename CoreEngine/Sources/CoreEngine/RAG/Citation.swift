import Foundation

/// Represents a citation to a source chunk in the knowledge base
public struct Citation: Codable, Sendable, Identifiable {
    /// Unique identifier for the citation
    public let id: String

    /// Citation number for referencing ([1], [2], etc.)
    public let number: Int

    /// Reference to the source chunk
    public let chunkId: String

    /// Source document identifier
    public let documentId: String

    /// Text excerpt from the source
    public let snippet: String

    /// Search relevance score (0.0 to 1.0)
    public let score: Float

    public init(
        id: String = UUID().uuidString,
        number: Int,
        chunkId: String,
        documentId: String,
        snippet: String,
        score: Float
    ) {
        self.id = id
        self.number = number
        self.chunkId = chunkId
        self.documentId = documentId
        self.snippet = snippet
        self.score = score
    }
}

/// Represents a complete answer with citations
public struct Answer: Sendable, Identifiable {
    /// Unique identifier for the answer
    public let id: String

    /// Original user query
    public let query: String

    /// Generated answer text
    public let text: String

    /// Citations referenced in the answer
    public let citations: [Citation]

    /// Timestamp when answer was generated
    public let timestamp: Date

    /// Generation time in milliseconds
    public let generationTimeMs: Int

    public init(
        id: String = UUID().uuidString,
        query: String,
        text: String,
        citations: [Citation],
        timestamp: Date = Date(),
        generationTimeMs: Int
    ) {
        self.id = id
        self.query = query
        self.text = text
        self.citations = citations
        self.timestamp = timestamp
        self.generationTimeMs = generationTimeMs
    }
}

/// Streaming token from answer generation
public enum StreamToken: Sendable {
    /// Content token (part of the answer text)
    case content(String)

    /// Citation marker in the stream
    case citation(Int)

    /// Metadata about the completed generation
    case metadata(AnswerMetadata)

    /// Error during generation
    case error(String)
}

/// Metadata about answer generation
public struct AnswerMetadata: Sendable {
    /// Number of tokens generated
    public let tokensGenerated: Int

    /// Generation time in milliseconds
    public let generationTimeMs: Int

    /// Number of citations used
    public let citationsUsed: Int

    public init(
        tokensGenerated: Int,
        generationTimeMs: Int,
        citationsUsed: Int
    ) {
        self.tokensGenerated = tokensGenerated
        self.generationTimeMs = generationTimeMs
        self.citationsUsed = citationsUsed
    }
}
