import Foundation

/// Configuration for text chunking
public struct ChunkConfig: Sendable {
    /// Target number of tokens per chunk
    public let chunkSize: Int

    /// Number of overlapping tokens between chunks (MVP: 0)
    public let overlapSize: Int

    /// Minimum chunk size (smaller chunks are discarded)
    public let minChunkSize: Int

    public init(
        chunkSize: Int = 512,
        overlapSize: Int = 0,
        minChunkSize: Int = 50
    ) {
        self.chunkSize = chunkSize
        self.overlapSize = overlapSize
        self.minChunkSize = minChunkSize
    }

    public static let `default` = ChunkConfig()
}

/// Chunks text into fixed-size segments for embedding
public struct TextChunker {
    private let config: ChunkConfig
    private let tokenizer: Tokenizer
    private let normalizer: TextNormalizer

    public init(config: ChunkConfig = .default) {
        self.config = config
        self.tokenizer = Tokenizer()
        self.normalizer = TextNormalizer()
    }

    /// Chunk text into fixed-size segments
    /// - Parameter text: Input text to chunk
    /// - Returns: Array of text chunks with metadata
    public func chunk(_ text: String) -> [ChunkedText] {
        // Normalize text first
        let normalized = normalizer.normalize(text)

        // Tokenize
        let tokens = tokenizer.tokenize(normalized)

        guard !tokens.isEmpty else {
            return []
        }

        var chunks: [ChunkedText] = []
        var currentIndex = 0
        var chunkIndex = 0

        // Create fixed-size chunks
        while currentIndex < tokens.count {
            let endIndex = min(currentIndex + config.chunkSize, tokens.count)
            let chunkTokens = Array(tokens[currentIndex..<endIndex])

            // Skip chunks that are too small (except the last one)
            if chunkTokens.count >= config.minChunkSize || endIndex == tokens.count {
                let chunkText = chunkTokens.joined(separator: " ")

                chunks.append(
                    ChunkedText(
                        content: chunkText,
                        tokenCount: chunkTokens.count,
                        chunkIndex: chunkIndex,
                        startToken: currentIndex,
                        endToken: endIndex
                    )
                )

                chunkIndex += 1
            }

            // Move to next chunk (MVP: no overlap)
            currentIndex = endIndex
        }

        return chunks
    }
}

/// Represents a chunk of text with metadata
public struct ChunkedText: Sendable {
    /// The text content of this chunk
    public let content: String

    /// Number of tokens in this chunk
    public let tokenCount: Int

    /// Index of this chunk in the document (0-based)
    public let chunkIndex: Int

    /// Starting token index in original document
    public let startToken: Int

    /// Ending token index in original document
    public let endToken: Int

    public init(
        content: String,
        tokenCount: Int,
        chunkIndex: Int,
        startToken: Int,
        endToken: Int
    ) {
        self.content = content
        self.tokenCount = tokenCount
        self.chunkIndex = chunkIndex
        self.startToken = startToken
        self.endToken = endToken
    }
}
