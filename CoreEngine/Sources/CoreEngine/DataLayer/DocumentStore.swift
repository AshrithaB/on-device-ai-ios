import Foundation
import GRDB

/// Repository for managing documents in the database
public actor DocumentStore {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    // MARK: - Create

    /// Insert a new document
    public func insert(_ document: Document) async throws {
        try await database.write { db in
            try document.insert(db)
        }
    }

    // MARK: - Read

    /// Fetch a document by ID
    public func fetch(id: String) async throws -> Document? {
        try await database.read { db in
            try Document.fetchOne(db, key: id)
        }
    }

    /// Fetch all documents
    public func fetchAll() async throws -> [Document] {
        try await database.read { db in
            try Document
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    /// Count total documents
    public func count() async throws -> Int {
        try await database.read { db in
            try Document.fetchCount(db)
        }
    }

    // MARK: - Update

    /// Update an existing document
    public func update(_ document: Document) async throws {
        var updated = document
        updated.updatedAt = Date()

        try await database.write { db in
            try updated.update(db)
        }
    }

    // MARK: - Delete

    /// Delete a document by ID (cascades to chunks)
    public func delete(id: String) async throws {
        try await database.write { db in
            try Document.deleteOne(db, key: id)
        }
    }

    /// Delete all documents
    public func deleteAll() async throws {
        try await database.write { db in
            try Document.deleteAll(db)
        }
    }
}
