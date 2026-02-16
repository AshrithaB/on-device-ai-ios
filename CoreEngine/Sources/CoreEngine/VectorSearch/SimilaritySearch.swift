import Foundation
import Accelerate

/// Performs similarity search using cosine similarity
public actor SimilaritySearch {
    private let vectorStore: VectorStore

    public init(vectorStore: VectorStore) {
        self.vectorStore = vectorStore
    }

    /// Search for similar chunks using cosine similarity
    /// - Parameters:
    ///   - queryEmbedding: Query vector (384 dimensions)
    ///   - chunks: Available chunks to search through
    ///   - config: Search configuration
    /// - Returns: Array of search results sorted by similarity (highest first)
    public func search(
        queryEmbedding: [Float],
        chunks: [Chunk],
        config: SearchConfig = .default
    ) async -> [SearchResult] {
        // Get all vectors
        let allVectors = await vectorStore.getAll()

        // Calculate similarities for all chunks that have embeddings
        var scored: [(chunk: Chunk, score: Float)] = []

        for chunk in chunks {
            guard let chunkEmbedding = allVectors[chunk.id] else {
                continue
            }

            let similarity = cosineSimilarity(queryEmbedding, chunkEmbedding)

            // Filter by minimum score
            if similarity >= config.minScore {
                scored.append((chunk: chunk, score: similarity))
            }
        }

        // Sort by score (descending)
        scored.sort { $0.score > $1.score }

        // Take top K results
        let topResults = scored.prefix(config.topK)

        // Convert to SearchResult with ranks
        return topResults.enumerated().map { index, item in
            SearchResult(
                chunk: item.chunk,
                score: item.score,
                rank: index + 1
            )
        }
    }

    // MARK: - Similarity Metrics

    /// Calculate cosine similarity between two vectors using Accelerate
    /// Returns value in range [-1, 1], where 1 is most similar
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        assert(a.count == b.count, "Vectors must have same dimensionality")

        let n = vDSP_Length(a.count)

        // Dot product
        var dotProduct: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, n)

        // Magnitude of a
        var magnitudeA: Float = 0.0
        vDSP_svesq(a, 1, &magnitudeA, n)
        magnitudeA = sqrt(magnitudeA)

        // Magnitude of b
        var magnitudeB: Float = 0.0
        vDSP_svesq(b, 1, &magnitudeB, n)
        magnitudeB = sqrt(magnitudeB)

        // Cosine similarity
        let magnitude = magnitudeA * magnitudeB
        if magnitude > 0 {
            return dotProduct / magnitude
        } else {
            return 0.0
        }
    }

    /// Calculate Euclidean distance between two vectors
    /// Lower values indicate more similarity
    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        assert(a.count == b.count, "Vectors must have same dimensionality")

        var difference = [Float](repeating: 0, count: a.count)
        var distance: Float = 0.0

        // Calculate difference
        vDSP_vsub(b, 1, a, 1, &difference, 1, vDSP_Length(a.count))

        // Calculate squared Euclidean distance
        vDSP_svesq(difference, 1, &distance, vDSP_Length(a.count))

        return sqrt(distance)
    }
}
