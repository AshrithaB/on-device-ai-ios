import Foundation

/// Represents a search result with similarity score
public struct SearchResult: Sendable {
    /// The chunk that matched the query
    public let chunk: Chunk

    /// Similarity score (0.0 to 1.0, higher is better)
    public let score: Float

    /// Rank in the result list (1-based)
    public let rank: Int

    public init(chunk: Chunk, score: Float, rank: Int) {
        self.chunk = chunk
        self.score = score
        self.rank = rank
    }
}

/// Configuration for search operations
public struct SearchConfig: Sendable {
    /// Number of top results to return
    public let topK: Int

    /// Minimum similarity score threshold (0.0 to 1.0)
    public let minScore: Float

    public init(topK: Int = 5, minScore: Float = 0.0) {
        self.topK = topK
        self.minScore = minScore
    }

    public static let `default` = SearchConfig()
}
