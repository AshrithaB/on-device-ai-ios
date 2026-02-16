import Foundation
import GRDB

/// Store for managing vector embeddings persistence
public actor EmbeddingStore {
    private let database: Database

    public enum EmbeddingError: Error {
        case serializationFailed
        case deserializationFailed
        case invalidVectorSize
    }

    public init(database: Database) {
        self.database = database
    }

    // MARK: - CRUD Operations

    /// Insert or update an embedding for a chunk
    /// - Parameters:
    ///   - chunkId: Chunk identifier
    ///   - embedding: 384-dimensional vector
    public func insert(chunkId: String, embedding: [Float]) async throws {
        let vectorData = try serializeVector(embedding)

        try await database.write { @Sendable db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO embeddings (chunk_id, vector_data, created_at)
                VALUES (?, ?, ?)
                """,
                arguments: [chunkId, vectorData, Int(Date().timeIntervalSince1970)]
            )
        }
    }

    /// Insert multiple embeddings in a batch
    /// - Parameter embeddings: Dictionary of chunk ID to embedding vector
    public func insertBatch(_ embeddings: [String: [Float]]) async throws {
        try await database.write { @Sendable [self] db in
            for (chunkId, embedding) in embeddings {
                let vectorData = try self.serializeVector(embedding)
                try db.execute(
                    sql: """
                    INSERT OR REPLACE INTO embeddings (chunk_id, vector_data, created_at)
                    VALUES (?, ?, ?)
                    """,
                    arguments: [chunkId, vectorData, Int(Date().timeIntervalSince1970)]
                )
            }
        }
    }

    /// Fetch an embedding for a specific chunk
    /// - Parameter chunkId: Chunk identifier
    /// - Returns: Embedding vector if found, nil otherwise
    public func fetch(chunkId: String) async throws -> [Float]? {
        try await database.read { @Sendable [self] db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT vector_data FROM embeddings WHERE chunk_id = ?",
                arguments: [chunkId]
            ) else {
                return nil
            }

            let vectorData: Data = row["vector_data"]
            return try deserializeVector(vectorData)
        }
    }

    /// Fetch all embeddings
    /// - Returns: Dictionary mapping chunk IDs to their embedding vectors
    public func fetchAll() async throws -> [String: [Float]] {
        try await database.read { @Sendable [self] db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT chunk_id, vector_data FROM embeddings"
            )

            var result: [String: [Float]] = [:]
            for row in rows {
                let chunkId: String = row["chunk_id"]
                let vectorData: Data = row["vector_data"]
                result[chunkId] = try self.deserializeVector(vectorData)
            }
            return result
        }
    }

    /// Fetch embeddings for specific chunks
    /// - Parameter chunkIds: Array of chunk identifiers
    /// - Returns: Dictionary mapping chunk IDs to their embeddings
    public func fetchBatch(_ chunkIds: [String]) async throws -> [String: [Float]] {
        guard !chunkIds.isEmpty else { return [:] }

        return try await database.read { @Sendable [self] db in
            let placeholders = chunkIds.map { _ in "?" }.joined(separator: ", ")
            let sql = "SELECT chunk_id, vector_data FROM embeddings WHERE chunk_id IN (\(placeholders))"
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(chunkIds))

            var result: [String: [Float]] = [:]
            for row in rows {
                let chunkId: String = row["chunk_id"]
                let vectorData: Data = row["vector_data"]
                result[chunkId] = try self.deserializeVector(vectorData)
            }
            return result
        }
    }

    /// Delete an embedding
    /// - Parameter chunkId: Chunk identifier
    public func delete(chunkId: String) async throws {
        try await database.write { db in
            try db.execute(
                sql: "DELETE FROM embeddings WHERE chunk_id = ?",
                arguments: [chunkId]
            )
        }
    }

    /// Delete multiple embeddings
    /// - Parameter chunkIds: Array of chunk identifiers
    public func deleteBatch(_ chunkIds: [String]) async throws {
        guard !chunkIds.isEmpty else { return }

        try await database.write { db in
            let placeholders = chunkIds.map { _ in "?" }.joined(separator: ", ")
            let sql = "DELETE FROM embeddings WHERE chunk_id IN (\(placeholders))"
            try db.execute(sql: sql, arguments: StatementArguments(chunkIds))
        }
    }

    /// Delete all embeddings for a document's chunks
    /// - Parameter documentId: Document identifier
    public func deleteForDocument(_ documentId: String) async throws {
        try await database.write { db in
            try db.execute(
                sql: """
                DELETE FROM embeddings
                WHERE chunk_id IN (SELECT id FROM chunks WHERE document_id = ?)
                """,
                arguments: [documentId]
            )
        }
    }

    /// Get count of stored embeddings
    public func count() async throws -> Int {
        try await database.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM embeddings") ?? 0
        }
    }

    /// Clear all embeddings
    public func clear() async throws {
        try await database.write { db in
            try db.execute(sql: "DELETE FROM embeddings")
        }
    }

    // MARK: - Serialization

    /// Serialize a Float array to Data (binary blob)
    private nonisolated func serializeVector(_ vector: [Float]) throws -> Data {
        // Store as raw bytes: [Float] -> Data
        let data = vector.withUnsafeBytes { Data($0) }
        return data
    }

    /// Deserialize Data back to Float array
    private nonisolated func deserializeVector(_ data: Data) throws -> [Float] {
        // Convert Data -> [Float]
        guard data.count % MemoryLayout<Float>.size == 0 else {
            throw EmbeddingError.deserializationFailed
        }

        let count = data.count / MemoryLayout<Float>.size
        var vector = [Float](repeating: 0, count: count)

        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let baseAddress = ptr.baseAddress else { return }
            vector.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) in
                destPtr.copyMemory(from: UnsafeRawBufferPointer(start: baseAddress, count: data.count))
            }
        }

        return vector
    }
}
