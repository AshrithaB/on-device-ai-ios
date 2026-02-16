import Foundation

/// Language model for text generation
/// For MVP: Uses a simple extractive summarization (deterministic mock)
/// Production: Replace with actual Core ML LLM or llama.cpp wrapper
public actor GenerationModel {
    private let seed: UInt64

    public enum GenerationError: Error {
        case modelNotLoaded
        case generationFailed(String)
        case invalidPrompt
        case contextTooLong
    }

    public init(seed: UInt64 = 42) {
        self.seed = seed
    }

    /// Generate answer from prompt (non-streaming)
    /// - Parameter prompt: RAG prompt with system, context, and question
    /// - Returns: Generated answer text
    public func generate(_ prompt: String) async throws -> String {
        // Parse the prompt to extract components
        guard let query = extractQuery(from: prompt),
              let contextChunks = extractContextChunks(from: prompt) else {
            throw GenerationError.invalidPrompt
        }

        // Handle empty context case
        if contextChunks.isEmpty {
            return "I don't have enough information in my knowledge base to answer this question. The context provided does not contain relevant details about '\(query)'."
        }

        // Generate answer using extractive summarization
        let answer = generateExtractiveAnswer(
            query: query,
            contextChunks: contextChunks
        )

        return answer
    }

    /// Generate answer with streaming tokens
    /// - Parameter prompt: RAG prompt with system, context, and question
    /// - Returns: AsyncStream of generated text tokens
    public func generateStream(_ prompt: String) -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                do {
                    // Generate full answer
                    let answer = try await generate(prompt)

                    // Simulate streaming by splitting into words
                    let words = answer.split(separator: " ", omittingEmptySubsequences: false)

                    for (index, word) in words.enumerated() {
                        // Add space before word (except first)
                        let token = index == 0 ? String(word) : " " + String(word)

                        continuation.yield(token)

                        // Simulate generation delay (50ms per token)
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }

                    continuation.finish()
                } catch {
                    // Yield error message and finish
                    continuation.yield("[Error: \(error.localizedDescription)]")
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Extract user query from prompt
    private func extractQuery(from prompt: String) -> String? {
        // Look for "Question:" section
        guard let questionRange = prompt.range(of: "Question:") else {
            return nil
        }

        let afterQuestion = prompt[questionRange.upperBound...]

        // Extract until "Answer:" or end of string
        if let answerRange = afterQuestion.range(of: "Answer:") {
            return String(afterQuestion[..<answerRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(afterQuestion)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract context chunks from prompt
    private func extractContextChunks(from prompt: String) -> [(number: Int, text: String)]? {
        // Look for "Context:" section
        guard let contextRange = prompt.range(of: "Context:") else {
            return nil
        }

        let afterContext = prompt[contextRange.upperBound...]

        // Extract until "Question:" section
        guard let questionRange = afterContext.range(of: "Question:") else {
            return nil
        }

        let contextSection = String(afterContext[..<questionRange.lowerBound])

        // Check for empty context marker
        if contextSection.contains("No relevant information found") {
            return []
        }

        // Parse numbered chunks [1] text [2] text ...
        var chunks: [(Int, String)] = []
        let lines = contextSection.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Look for [N] prefix
            if let match = trimmed.range(of: #"^\[(\d+)\]\s*(.+)$"#, options: .regularExpression) {
                let content = String(trimmed[match])

                // Extract number and text
                if let numberEnd = content.range(of: "]"),
                   let number = Int(content[content.index(after: content.startIndex)..<numberEnd.lowerBound]) {
                    let text = String(content[content.index(after: numberEnd.upperBound)...])
                        .trimmingCharacters(in: .whitespaces)
                    chunks.append((number, text))
                }
            }
        }

        return chunks
    }

    /// Generate extractive answer from context chunks
    private func generateExtractiveAnswer(
        query: String,
        contextChunks: [(number: Int, text: String)]
    ) -> String {
        // Create answer by combining key sentences from context
        var sentences: [String] = []

        // Extract relevant sentences from each chunk
        for (_, text) in contextChunks.prefix(3) {  // Use top 3 chunks
            // Take first 1-2 sentences from each chunk
            let chunkSentences = text.components(separatedBy: ". ")
                .prefix(2)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            sentences.append(contentsOf: chunkSentences)
        }

        // Build answer
        var answer = "Based on the available information: "

        // Combine sentences
        let combined = sentences.joined(separator: ". ")

        // Ensure proper ending punctuation
        var finalText = combined
        if !finalText.hasSuffix(".") && !finalText.hasSuffix("!") && !finalText.hasSuffix("?") {
            finalText += "."
        }

        answer += finalText

        // Add citation markers for chunks used
        let citationNumbers = contextChunks.prefix(3).map { $0.number }
        let citations = citationNumbers.map { "[\($0)]" }.joined()
        answer += " \(citations)"

        return answer
    }
}

// MARK: - Future: Real LLM Integration

/*
/// Production implementation using llama.cpp Swift wrapper
public actor LlamaCppGenerationModel {
    private let context: LlamaContext
    private let model: LlamaModel

    public init(modelPath: String) throws {
        // Load GGUF model
        let params = LlamaContextParams()
        params.nCtx = 2048  // Context window size
        params.nThreads = 4  // CPU threads
        params.nGpuLayers = 0  // CPU-only for MVP

        self.model = try LlamaModel(path: modelPath)
        self.context = try LlamaContext(model: model, params: params)
    }

    public func generate(_ prompt: String) async throws -> String {
        // Tokenize prompt
        let tokens = try context.tokenize(prompt, addBos: true)

        // Generate tokens
        var outputTokens: [Int32] = []
        let maxTokens = 512

        for _ in 0..<maxTokens {
            // Evaluate
            try context.eval(tokens: tokens + outputTokens)

            // Sample next token
            let logits = context.logits()
            let nextToken = sampleToken(logits: logits)

            // Check for EOS
            if nextToken == context.eosToken {
                break
            }

            outputTokens.append(nextToken)
        }

        // Decode tokens to text
        let text = try context.decode(tokens: outputTokens)
        return text
    }

    public func generateStream(_ prompt: String) -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                // Similar to above but yield each token as it's generated
                let tokens = try context.tokenize(prompt, addBos: true)
                var outputTokens: [Int32] = []

                for _ in 0..<512 {
                    try context.eval(tokens: tokens + outputTokens)
                    let nextToken = sampleToken(logits: context.logits())

                    if nextToken == context.eosToken {
                        break
                    }

                    outputTokens.append(nextToken)

                    // Decode and yield
                    let text = try context.decode(tokens: [nextToken])
                    continuation.yield(text)
                }

                continuation.finish()
            }
        }
    }
}
*/
