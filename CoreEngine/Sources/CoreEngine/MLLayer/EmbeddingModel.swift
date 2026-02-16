import Foundation
import Accelerate

/// Embedding model for generating vector representations of text
/// For MVP: Uses a simple hash-based embedding (deterministic mock)
/// Production: Replace with actual Core ML model
public actor EmbeddingModel {
    private let embeddingDimension = 384
    private let seed: UInt64

    public enum EmbeddingError: Error {
        case embeddingFailed(String)
        case invalidInput
    }

    public init(seed: UInt64 = 42) {
        self.seed = seed
    }

    /// Generate embedding for a single text
    /// - Parameter text: Input text to embed
    /// - Returns: 384-dimensional embedding vector
    public func embed(_ text: String) async throws -> [Float] {
        return try await embedBatch([text]).first!
    }

    /// Generate embeddings for multiple texts in batch
    /// - Parameter texts: Array of input texts
    /// - Returns: Array of 384-dimensional embedding vectors
    public func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        return texts.map { text in
            generateDeterministicEmbedding(for: text)
        }
    }

    // MARK: - Private Implementation

    /// Generate a deterministic embedding based on text content
    /// Uses hashing to create reproducible embeddings
    private func generateDeterministicEmbedding(for text: String) -> [Float] {
        // Normalize text
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Generate deterministic seed from text
        var hasher = Hasher()
        hasher.combine(normalized)
        hasher.combine(seed)
        let textHash = UInt64(bitPattern: Int64(hasher.finalize()))

        // Generate embedding using deterministic random numbers
        var rng = LinearCongruentialGenerator(seed: textHash)
        var embedding = (0..<embeddingDimension).map { _ in
            rng.next()
        }

        // Normalize to unit length
        embedding = normalizeVector(embedding)

        return embedding
    }

    /// Normalize a vector to unit length (L2 normalization)
    private func normalizeVector(_ vector: [Float]) -> [Float] {
        var normalized = vector
        var norm: Float = 0.0

        // Calculate L2 norm
        vDSP_svesq(vector, 1, &norm, vDSP_Length(vector.count))
        norm = sqrt(norm)

        // Avoid division by zero
        if norm > 0 {
            var divisor = norm
            vDSP_vsdiv(vector, 1, &divisor, &normalized, 1, vDSP_Length(vector.count))
        }

        return normalized
    }
}

// MARK: - Deterministic Random Number Generator

/// Simple linear congruential generator for deterministic randomness
private struct LinearCongruentialGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> Float {
        // LCG parameters (same as Java's Random)
        state = (state &* 6364136223846793005 &+ 1442695040888963407)

        // Convert to Float in range [-1, 1]
        let normalized = Float(Int64(bitPattern: state)) / Float(Int64.max)
        return normalized
    }
}

// MARK: - Future: Core ML Integration

/*
/// Production implementation using actual Core ML model
public actor CoreMLEmbeddingModel {
    private let model: MiniLM_L6_v2
    private let tokenizer: BertTokenizer

    public init() throws {
        // Load Core ML model
        let config = MLModelConfiguration()
        self.model = try MiniLM_L6_v2(configuration: config)
        self.tokenizer = BertTokenizer()
    }

    public func embed(_ text: String) async throws -> [Float] {
        // Tokenize
        let tokens = tokenizer.encode(text, maxLength: 128)

        // Create MLMultiArray inputs
        let inputIds = try MLMultiArray(shape: [1, 128], dataType: .int32)
        let attentionMask = try MLMultiArray(shape: [1, 128], dataType: .int32)

        for i in 0..<tokens.count {
            inputIds[i] = tokens[i] as NSNumber
            attentionMask[i] = 1 as NSNumber
        }

        // Run inference
        let output = try model.prediction(
            input_ids: inputIds,
            attention_mask: attentionMask
        )

        // Extract embeddings
        let embeddings = output.embeddings
        var result: [Float] = []
        for i in 0..<384 {
            result.append(Float(truncating: embeddings[i] as! NSNumber))
        }

        return result
    }
}
*/
