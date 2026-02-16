import Foundation
import GRDB

/// Represents a source document in the knowledge base
public struct Document: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var content: String
    public var source: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        source: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // GRDB table name
    public static let databaseTableName = "documents"

    // Column coding keys
    enum Columns: String, CodingKey, ColumnExpression {
        case id, title, content, source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Custom coding for timestamp conversion
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Columns.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        source = try container.decodeIfPresent(String.self, forKey: .source)

        let createdTimestamp = try container.decode(Int64.self, forKey: .createdAt)
        createdAt = Date(timeIntervalSince1970: TimeInterval(createdTimestamp))

        let updatedTimestamp = try container.decode(Int64.self, forKey: .updatedAt)
        updatedAt = Date(timeIntervalSince1970: TimeInterval(updatedTimestamp))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Columns.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encode(Int64(createdAt.timeIntervalSince1970), forKey: .createdAt)
        try container.encode(Int64(updatedAt.timeIntervalSince1970), forKey: .updatedAt)
    }
}
