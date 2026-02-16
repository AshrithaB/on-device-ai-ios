import Foundation
import GRDB

/// Database manager using GRDB for SQLite operations
public actor Database {
    private let dbQueue: DatabaseQueue
    private let schemaVersion = 1

    public enum DatabaseError: Error {
        case initializationFailed(String)
        case queryFailed(String)
    }

    /// Initialize database at specified path
    /// - Parameter path: File path for SQLite database (or ":memory:" for in-memory)
    public init(path: String = ":memory:") throws {
        do {
            // Create database queue
            dbQueue = try DatabaseQueue(path: path)

            // Initialize schema
            try dbQueue.write { db in
                try db.execute(sql: Database.schemaSQL)
            }
        } catch {
            throw DatabaseError.initializationFailed("Failed to initialize database: \(error)")
        }
    }

    /// Execute a read-only query
    public func read<T>(_ block: (GRDB.Database) throws -> T) async throws -> T {
        try await dbQueue.read(block)
    }

    /// Execute a write query
    public func write(_ block: @escaping (GRDB.Database) throws -> Void) async throws {
        try await dbQueue.write(block)
    }

    /// Execute a write query and return a value
    public func writeAndReturn<T>(_ block: @escaping (GRDB.Database) throws -> T) async throws -> T {
        try await dbQueue.write(block)
    }

    // MARK: - Schema

    private static let schemaSQL = """
    -- On-Device AI Core Engine Database Schema

    CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        source TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );

    CREATE INDEX IF NOT EXISTS idx_documents_created ON documents(created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_documents_source ON documents(source);

    CREATE TABLE IF NOT EXISTS chunks (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        content TEXT NOT NULL,
        token_count INTEGER NOT NULL,
        chunk_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_chunks_document ON chunks(document_id);
    CREATE INDEX IF NOT EXISTS idx_chunks_index ON chunks(document_id, chunk_index);

    CREATE TABLE IF NOT EXISTS embeddings (
        chunk_id TEXT PRIMARY KEY,
        vector_data BLOB NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        FOREIGN KEY (chunk_id) REFERENCES chunks(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_embeddings_created ON embeddings(created_at);
    """
}
