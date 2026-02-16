import Foundation

/// Mock language model for testing and development
/// Uses simple extractive summarization (deterministic mock)
public actor MockGenerationModel {
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

    /// Generate smart templated answer from context chunks
    /// Improved mock: Creates fluent, coherent answers using templates
    private func generateExtractiveAnswer(
        query: String,
        contextChunks: [(number: Int, text: String)]
    ) -> String {
        // Extract key information from context
        var sentences: [String] = []

        for (_, text) in contextChunks.prefix(3) {
            let chunkSentences = text.components(separatedBy: ". ")
                .prefix(2)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            sentences.append(contentsOf: chunkSentences)
        }

        // Analyze query type and generate appropriate answer
        let answerStyle = determineAnswerStyle(query: query)

        var answer = ""

        switch answerStyle {
        case .definition:
            // "What is X?" style questions
            if let firstSentence = sentences.first {
                answer = firstSentence
                if sentences.count > 1 {
                    answer += ". " + sentences[1...min(2, sentences.count-1)].joined(separator: ". ")
                }
            }

        case .explanation:
            // "How does X work?" style questions
            answer = "Based on the provided context, "
            answer += sentences.prefix(3).joined(separator: ". ")

        case .enumeration:
            // "What are the types of X?" style questions
            let items = extractListItems(from: sentences)
            if items.isEmpty {
                answer = sentences.prefix(2).joined(separator: ". ")
            } else {
                answer = "According to the available information, "
                answer += "the main types include: "
                answer += items.joined(separator: "; ")
            }

        case .general:
            // General questions
            answer = sentences.prefix(3).joined(separator: ". ")
        }

        // Ensure proper ending
        if !answer.hasSuffix(".") && !answer.hasSuffix("!") && !answer.hasSuffix("?") {
            answer += "."
        }

        // Add citations
        let citationNumbers = contextChunks.prefix(3).map { $0.number }
        let citations = citationNumbers.map { "[\($0)]" }.joined()
        answer += " \(citations)"

        return answer
    }

    /// Determine the style of answer to generate based on query
    private func determineAnswerStyle(query: String) -> AnswerStyle {
        let lowercased = query.lowercased()

        if lowercased.starts(with: "what is") || lowercased.starts(with: "define") {
            return .definition
        } else if lowercased.contains("how does") || lowercased.contains("how do") || lowercased.contains("explain") {
            return .explanation
        } else if lowercased.contains("what are the") || lowercased.contains("types of") || lowercased.contains("kinds of") {
            return .enumeration
        } else {
            return .general
        }
    }

    /// Extract list items from sentences (simple heuristic)
    private func extractListItems(from sentences: [String]) -> [String] {
        var items: [String] = []

        for sentence in sentences {
            // Look for list-like patterns
            if sentence.contains(":") {
                // Split on colon and take the part after
                let parts = sentence.components(separatedBy: ":")
                if parts.count > 1 {
                    let listPart = parts[1]
                    // Look for comma-separated items
                    let commaItems = listPart.components(separatedBy: ",")
                    if commaItems.count > 1 {
                        items.append(contentsOf: commaItems.map { $0.trimmingCharacters(in: .whitespaces) })
                    }
                }
            }
        }

        return items.prefix(5).map { $0 }
    }

    private enum AnswerStyle {
        case definition
        case explanation
        case enumeration
        case general
    }
}

// MARK: - LlamaCli Integration

#if !MOCK_LLM
/// Production implementation using llama-cli executable
public actor LlamaCliGenerationModel: Sendable {
    private let modelPath: String
    private let llamaCliPath: String
    private let maxTokens: Int
    private let temperature: Float
    private let threads: Int

    public enum GenerationError: Error {
        case modelNotLoaded
        case generationFailed(String)
        case invalidPrompt
        case contextTooLong
        case llamaCliNotFound
    }

    public init(modelPath: String, llamaCliPath: String? = nil, maxTokens: Int = 512, temperature: Float = 0.7, threads: Int = 4) throws {
        self.modelPath = modelPath
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.threads = threads

        // Determine llama-cli path
        if let path = llamaCliPath {
            self.llamaCliPath = path
        } else {
            // Default locations
            let defaultPaths = [
                "/Users/nitindattamovva/Desktop/Code/on-device-ai-ios/llama-cpp-build/build/bin/llama-cli",
                "/usr/local/bin/llama-cli",
                "/opt/homebrew/bin/llama-cli"
            ]

            guard let found = defaultPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
                throw GenerationError.llamaCliNotFound
            }

            self.llamaCliPath = found
        }

        // Verify model exists
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw GenerationError.modelNotLoaded
        }
    }

    public func generate(_ prompt: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: llamaCliPath)

        // Build arguments
        process.arguments = [
            "-m", modelPath,
            "-n", String(maxTokens),
            "--temp", String(temperature),
            "-t", String(threads),
            "-p", prompt,
            "--no-display-prompt",
            "-ngl", "0"  // CPU-only for compatibility
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GenerationError.generationFailed(errorMessage)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw GenerationError.generationFailed("Failed to decode output")
        }

        // Clean up output (remove metadata, timing info, etc.)
        let cleaned = cleanLlamaOutput(output)
        return cleaned
    }

    public func generateStream(_ prompt: String) -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: llamaCliPath)

                process.arguments = [
                    "-m", modelPath,
                    "-n", String(maxTokens),
                    "--temp", String(temperature),
                    "-t", String(threads),
                    "-p", prompt,
                    "--no-display-prompt",
                    "-ngl", "0"
                ]

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                // Set up output handling for streaming
                let outputHandle = outputPipe.fileHandleForReading
                outputHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                        // Stream each chunk
                        continuation.yield(text)
                    }
                }

                do {
                    try process.run()

                    // Wait for completion in background
                    DispatchQueue.global().async {
                        process.waitUntilExit()
                        outputHandle.readabilityHandler = nil
                        continuation.finish()
                    }
                } catch {
                    continuation.yield("[Error: \(error.localizedDescription)]")
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Helpers

    private func cleanLlamaOutput(_ output: String) -> String {
        var cleaned = output

        // Remove common llama.cpp metadata patterns
        let patternsToRemove = [
            "llm_load_tensors:.*\n",
            "llama_model_load:.*\n",
            "llama_new_context_with_model:.*\n",
            "main:.*\n"
        ]

        for pattern in patternsToRemove {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}
#endif

// MARK: - Type Alias for Build-Time Selection

#if MOCK_LLM
public typealias GenerationModel = MockGenerationModel
#else
public typealias GenerationModel = LlamaCliGenerationModel
#endif
