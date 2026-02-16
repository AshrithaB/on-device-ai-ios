import Foundation
import GRDB

/// Represents a text chunk derived from a document
public struct Chunk: Codable, FetchableRecord, PersistableRecord, Sendable {
    public var id: String
    public var documentId: String
    public var content: String
    public var tokenCount: Int
    public var chunkIndex: Int
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        documentId: String,
        content: String,
        tokenCount: Int,
        chunkIndex: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.content = content
        self.tokenCount = tokenCount
        self.chunkIndex = chunkIndex
        self.createdAt = createdAt
    }

    // GRDB table name
    public static let databaseTableName = "chunks"

    // Column coding keys
    enum Columns: String, CodingKey, ColumnExpression {
        case id
        case documentId = "document_id"
        case content
        case tokenCount = "token_count"
        case chunkIndex = "chunk_index"
        case createdAt = "created_at"
    }

    // Custom coding for timestamp conversion
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Columns.self)
        id = try container.decode(String.self, forKey: .id)
        documentId = try container.decode(String.self, forKey: .documentId)
        content = try container.decode(String.self, forKey: .content)
        tokenCount = try container.decode(Int.self, forKey: .tokenCount)
        chunkIndex = try container.decode(Int.self, forKey: .chunkIndex)

        let timestamp = try container.decode(Int64.self, forKey: .createdAt)
        createdAt = Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Columns.self)
        try container.encode(id, forKey: .id)
        try container.encode(documentId, forKey: .documentId)
        try container.encode(content, forKey: .content)
        try container.encode(tokenCount, forKey: .tokenCount)
        try container.encode(chunkIndex, forKey: .chunkIndex)
        try container.encode(Int64(createdAt.timeIntervalSince1970), forKey: .createdAt)
    }
}
