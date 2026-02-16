import Foundation

/// Vector store for embeddings with optional persistence
/// Maintains in-memory cache for fast search with optional database backing
public actor VectorStore {
    private var vectors: [String: [Float]] = [:]  // chunkId -> embedding (in-memory cache)
    private let embeddingStore: EmbeddingStore?
    private var isPersistenceEnabled: Bool { embeddingStore != nil }

    /// Initialize vector store
    /// - Parameter embeddingStore: Optional embedding store for persistence. If nil, uses memory-only mode.
    public init(embeddingStore: EmbeddingStore? = nil) async throws {
        self.embeddingStore = embeddingStore

        // Load existing vectors from database if persistence is enabled
        if let store = embeddingStore {
            vectors = try await store.fetchAll()
        }
    }

    /// Store an embedding for a chunk
    /// - Parameters:
    ///   - chunkId: Chunk identifier
    ///   - embedding: 384-dimensional vector
    public func store(chunkId: String, embedding: [Float]) async throws {
        vectors[chunkId] = embedding

        // Persist to database if enabled
        if let store = embeddingStore {
            try await store.insert(chunkId: chunkId, embedding: embedding)
        }
    }

    /// Store multiple embeddings in batch
    /// - Parameter embeddings: Dictionary of chunkId to embedding
    public func storeBatch(_ embeddings: [String: [Float]]) async throws {
        for (chunkId, embedding) in embeddings {
            vectors[chunkId] = embedding
        }

        // Persist to database if enabled
        if let store = embeddingStore {
            try await store.insertBatch(embeddings)
        }
    }

    /// Retrieve an embedding for a chunk
    /// - Parameter chunkId: Chunk identifier
    /// - Returns: Embedding vector if found
    public func get(chunkId: String) -> [Float]? {
        return vectors[chunkId]
    }

    /// Get all stored vectors
    /// - Returns: Dictionary of all chunk IDs and their embeddings
    public func getAll() -> [String: [Float]] {
        return vectors
    }

    /// Remove embedding for a chunk
    /// - Parameter chunkId: Chunk identifier
    public func remove(chunkId: String) async throws {
        vectors.removeValue(forKey: chunkId)

        // Remove from database if enabled
        if let store = embeddingStore {
            try await store.delete(chunkId: chunkId)
        }
    }

    /// Remove all embeddings for a document's chunks
    /// - Parameter chunkIds: Array of chunk identifiers
    public func removeBatch(_ chunkIds: [String]) async throws {
        for chunkId in chunkIds {
            vectors.removeValue(forKey: chunkId)
        }

        // Remove from database if enabled
        if let store = embeddingStore {
            try await store.deleteBatch(chunkIds)
        }
    }

    /// Clear all vectors
    public func clear() async throws {
        vectors.removeAll()

        // Clear database if enabled
        if let store = embeddingStore {
            try await store.clear()
        }
    }

    /// Reload vectors from database
    /// Useful to sync in-memory cache with database state
    public func reload() async throws {
        guard let store = embeddingStore else { return }
        vectors = try await store.fetchAll()
    }

    /// Check if persistence is enabled
    public func hasPersistence() -> Bool {
        return isPersistenceEnabled
    }

    /// Get count of stored vectors
    public func count() -> Int {
        return vectors.count
    }

    /// Get statistics about the vector store
    public func getStats() -> VectorStoreStats {
        let totalVectors = vectors.count
        let dimensionality = vectors.values.first?.count ?? 0
        let memoryUsage = totalVectors * dimensionality * MemoryLayout<Float>.size

        return VectorStoreStats(
            vectorCount: totalVectors,
            dimensionality: dimensionality,
            estimatedMemoryBytes: memoryUsage
        )
    }
}

/// Statistics about the vector store
public struct VectorStoreStats: Sendable {
    public let vectorCount: Int
    public let dimensionality: Int
    public let estimatedMemoryBytes: Int

    public var estimatedMemoryMB: Double {
        return Double(estimatedMemoryBytes) / (1024 * 1024)
    }

    public init(vectorCount: Int, dimensionality: Int, estimatedMemoryBytes: Int) {
        self.vectorCount = vectorCount
        self.dimensionality = dimensionality
        self.estimatedMemoryBytes = estimatedMemoryBytes
    }
}
