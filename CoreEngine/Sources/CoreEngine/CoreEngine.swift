import Foundation

/// Main entry point for the Core Engine
/// Coordinates document ingestion, chunking, embedding, and search
public actor CoreEngine {
    private let database: Database
    private let documentStore: DocumentStore
    private let chunkStore: ChunkStore
    private let embeddingStore: EmbeddingStore
    private let chunker: TextChunker
    private let embeddingModel: EmbeddingModel
    private let vectorStore: VectorStore
    private let similaritySearch: SimilaritySearch
    private let generationModel: GenerationModel
    private let promptBuilder: PromptBuilder

    public init(databasePath: String = ":memory:", embeddingModelPath: String? = nil, generationModelPath: String? = nil, llamaCliPath: String? = nil) async throws {
        self.database = try Database(path: databasePath)
        self.documentStore = DocumentStore(database: database)
        self.chunkStore = ChunkStore(database: database)
        self.embeddingStore = EmbeddingStore(database: database)
        self.chunker = TextChunker()

        // Initialize embedding model with optional path
        #if os(macOS) && !MOCK_EMBEDDINGS
        let defaultEmbeddingPath = "/Users/nitindattamovva/Desktop/Code/on-device-ai-ios/Models/MiniLM_L6_v2.mlpackage"
        self.embeddingModel = try EmbeddingModel(modelPath: embeddingModelPath ?? defaultEmbeddingPath)
        #elseif !MOCK_EMBEDDINGS
        self.embeddingModel = try EmbeddingModel(modelPath: embeddingModelPath)
        #else
        self.embeddingModel = EmbeddingModel()
        #endif

        self.vectorStore = try await VectorStore(embeddingStore: embeddingStore)
        self.similaritySearch = SimilaritySearch(vectorStore: vectorStore)

        // Initialize generation model with optional path
        #if os(macOS) && !MOCK_LLM
        let defaultLLMPath = "/Users/nitindattamovva/Desktop/Code/on-device-ai-ios/Models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
        self.generationModel = try GenerationModel(
            modelPath: generationModelPath ?? defaultLLMPath,
            llamaCliPath: llamaCliPath
        )
        #elseif !MOCK_LLM
        guard let llmPath = generationModelPath else {
            fatalError("generationModelPath required for non-macOS platforms when not using mock")
        }
        self.generationModel = try GenerationModel(modelPath: llmPath, llamaCliPath: llamaCliPath)
        #else
        self.generationModel = GenerationModel()
        #endif

        self.promptBuilder = PromptBuilder()
    }

    // MARK: - Document Ingestion

    /// Ingest a document and create chunks
    /// - Parameters:
    ///   - title: Document title
    ///   - content: Document content
    ///   - source: Optional source identifier
    /// - Returns: The created document
    @discardableResult
    public func ingest(title: String, content: String, source: String? = nil) async throws -> Document {
        // Create document
        let document = Document(
            title: title,
            content: content,
            source: source
        )

        // Save document
        try await documentStore.insert(document)

        // Chunk the content
        let chunkedTexts = chunker.chunk(content)

        // Convert to Chunk models and save
        let chunks = chunkedTexts.map { chunkedText in
            Chunk(
                documentId: document.id,
                content: chunkedText.content,
                tokenCount: chunkedText.tokenCount,
                chunkIndex: chunkedText.chunkIndex
            )
        }

        try await chunkStore.insertBatch(chunks)

        // Generate embeddings for all chunks
        try await embedChunks(chunks)

        return document
    }

    /// Generate and store embeddings for chunks
    private func embedChunks(_ chunks: [Chunk]) async throws {
        let texts = chunks.map { $0.content }

        // Generate embeddings in batch
        let embeddings = try await embeddingModel.embedBatch(texts)

        // Store in vector store (now persists to database)
        var embeddingDict: [String: [Float]] = [:]
        for (chunk, embedding) in zip(chunks, embeddings) {
            embeddingDict[chunk.id] = embedding
        }

        try await vectorStore.storeBatch(embeddingDict)
    }

    // MARK: - Document Management

    /// Fetch all documents
    public func getDocuments() async throws -> [Document] {
        try await documentStore.fetchAll()
    }

    /// Fetch a specific document
    public func getDocument(id: String) async throws -> Document? {
        try await documentStore.fetch(id: id)
    }

    /// Delete a document and its chunks
    public func deleteDocument(id: String) async throws {
        try await documentStore.delete(id: id)
    }

    /// Get chunks for a document
    public func getChunks(forDocument documentId: String) async throws -> [Chunk] {
        try await chunkStore.fetchChunks(forDocument: documentId)
    }

    /// Get all chunks
    public func getAllChunks() async throws -> [Chunk] {
        try await chunkStore.fetchAll()
    }

    // MARK: - Stats

    /// Get statistics about the knowledge base
    public func getStats() async throws -> EngineStats {
        let documentCount = try await documentStore.count()
        let chunkCount = try await chunkStore.fetchAll().count
        let vectorStats = await vectorStore.getStats()

        return EngineStats(
            documentCount: documentCount,
            chunkCount: chunkCount,
            vectorCount: vectorStats.vectorCount,
            memoryMB: vectorStats.estimatedMemoryMB
        )
    }

    // MARK: - Search

    /// Search for relevant chunks using semantic search
    /// - Parameters:
    ///   - query: Search query
    ///   - topK: Number of results to return
    ///   - minScore: Minimum similarity score (0.0 to 1.0)
    /// - Returns: Array of search results sorted by relevance
    public func search(
        query: String,
        topK: Int = 5,
        minScore: Float = 0.0
    ) async throws -> [SearchResult] {
        // Generate query embedding
        let queryEmbedding = try await embeddingModel.embed(query)

        // Get all chunks
        let allChunks = try await chunkStore.fetchAll()

        // Perform similarity search
        let config = SearchConfig(topK: topK, minScore: minScore)
        return await similaritySearch.search(
            queryEmbedding: queryEmbedding,
            chunks: allChunks,
            config: config
        )
    }

    // MARK: - Question Answering (RAG)

    /// Ask a question and get a streaming answer with citations
    /// - Parameters:
    ///   - query: The user's question
    ///   - topK: Number of context chunks to use (default: 5)
    /// - Returns: AsyncStream of tokens (content, citations, metadata, errors)
    public func ask(
        query: String,
        topK: Int = 5
    ) -> AsyncStream<StreamToken> {
        return AsyncStream { continuation in
            Task {
                do {
                    let startTime = Date()

                    // Search for relevant chunks
                    let searchResults = try await search(query: query, topK: topK)

                    // Fetch document metadata for citations
                    let documentIds = Set(searchResults.map { $0.chunk.documentId })
                    var documents: [String: Document] = [:]
                    for docId in documentIds {
                        if let doc = try await getDocument(id: docId) {
                            documents[docId] = doc
                        }
                    }

                    // Build RAG prompt
                    let (prompt, citations) = promptBuilder.buildPrompt(
                        query: query,
                        searchResults: searchResults,
                        documents: documents
                    )

                    // Stream generated answer
                    for await token in await generationModel.generateStream(prompt) {
                        continuation.yield(.content(token))
                    }

                    // Send citations
                    continuation.yield(.citations(citations))

                    // Send final metadata
                    let generationTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
                    let metadata = AnswerMetadata(
                        tokensGenerated: 0,  // Mock doesn't track tokens
                        generationTimeMs: generationTimeMs,
                        citationsUsed: citations.count
                    )
                    continuation.yield(.metadata(metadata))

                    continuation.finish()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    /// Ask a question and get a complete answer (non-streaming)
    /// - Parameters:
    ///   - query: The user's question
    ///   - topK: Number of context chunks to use (default: 5)
    /// - Returns: Complete answer with citations
    public func askComplete(
        query: String,
        topK: Int = 5
    ) async throws -> Answer {
        let startTime = Date()

        // Search for relevant chunks
        let searchResults = try await search(query: query, topK: topK)

        // Fetch document metadata for citations
        let documentIds = Set(searchResults.map { $0.chunk.documentId })
        var documents: [String: Document] = [:]
        for docId in documentIds {
            if let doc = try await getDocument(id: docId) {
                documents[docId] = doc
            }
        }

        // Build RAG prompt
        let (prompt, citations) = promptBuilder.buildPrompt(
            query: query,
            searchResults: searchResults,
            documents: documents
        )

        // Generate answer
        let text = try await generationModel.generate(prompt)

        // Calculate timing
        let generationTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

        // Return complete answer
        return Answer(
            query: query,
            text: text,
            citations: citations,
            generationTimeMs: generationTimeMs
        )
    }
}

/// Statistics about the engine's knowledge base
public struct EngineStats: Sendable {
    public let documentCount: Int
    public let chunkCount: Int
    public let vectorCount: Int
    public let memoryMB: Double

    public init(documentCount: Int, chunkCount: Int, vectorCount: Int = 0, memoryMB: Double = 0.0) {
        self.documentCount = documentCount
        self.chunkCount = chunkCount
        self.vectorCount = vectorCount
        self.memoryMB = memoryMB
    }
}
