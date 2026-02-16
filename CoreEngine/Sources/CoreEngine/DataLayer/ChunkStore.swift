import Foundation
import GRDB

/// Repository for managing chunks in the database
public actor ChunkStore {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    // MARK: - Create

    /// Insert a new chunk
    public func insert(_ chunk: Chunk) async throws {
        try await database.write { db in
            try chunk.insert(db)
        }
    }

    /// Insert multiple chunks in a single transaction
    public func insertBatch(_ chunks: [Chunk]) async throws {
        try await database.write { db in
            for chunk in chunks {
                try chunk.insert(db)
            }
        }
    }

    // MARK: - Read

    /// Fetch a chunk by ID
    public func fetch(id: String) async throws -> Chunk? {
        try await database.read { db in
            try Chunk.fetchOne(db, key: id)
        }
    }

    /// Fetch all chunks for a document
    public func fetchChunks(forDocument documentId: String) async throws -> [Chunk] {
        try await database.read { db in
            try Chunk
                .filter(Column("document_id") == documentId)
                .order(Column("chunk_index"))
                .fetchAll(db)
        }
    }

    /// Fetch all chunks
    public func fetchAll() async throws -> [Chunk] {
        try await database.read { db in
            try Chunk.fetchAll(db)
        }
    }

    /// Count chunks for a document
    public func count(forDocument documentId: String) async throws -> Int {
        try await database.read { db in
            try Chunk
                .filter(Column("document_id") == documentId)
                .fetchCount(db)
        }
    }

    // MARK: - Delete

    /// Delete a chunk by ID
    public func delete(id: String) async throws {
        try await database.write { db in
            try Chunk.deleteOne(db, key: id)
        }
    }

    /// Delete all chunks for a document
    public func deleteChunks(forDocument documentId: String) async throws {
        try await database.write { db in
            try Chunk
                .filter(Column("document_id") == documentId)
                .deleteAll(db)
        }
    }
}
