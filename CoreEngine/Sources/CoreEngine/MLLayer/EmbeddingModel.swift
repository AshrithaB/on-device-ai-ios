import Foundation
import Accelerate
import CoreML

/// Mock embedding model for testing and development
/// Uses a simple hash-based embedding (deterministic mock)
public actor MockEmbeddingModel {
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

// MARK: - Simple Tokenizer

/// Simple tokenizer for BERT-style models (MVP implementation)
struct SimpleTokenizer {
    let maxLength: Int = 128
    let clsToken: Int32 = 101  // [CLS]
    let sepToken: Int32 = 102  // [SEP]
    let padToken: Int32 = 0    // [PAD]

    func encode(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32]) {
        let words = text.lowercased().split(separator: " ")
        var inputIds: [Int32] = [clsToken]

        // Convert words to token IDs (simple hash-based approach)
        for word in words.prefix(maxLength - 2) {
            let tokenId = Int32(abs(word.hashValue) % 30522)  // BERT vocab size
            inputIds.append(tokenId)
        }

        inputIds.append(sepToken)

        // Create attention mask (1 for real tokens, 0 for padding)
        let attentionMask = [Int32](repeating: 1, count: inputIds.count) +
                           [Int32](repeating: 0, count: maxLength - inputIds.count)

        // Pad input IDs
        inputIds += [Int32](repeating: padToken, count: maxLength - inputIds.count)

        return (inputIds, attentionMask)
    }
}

// MARK: - Core ML Embedding Model

#if !MOCK_EMBEDDINGS
/// Production embedding model using Core ML
public actor CoreMLEmbeddingModel: Sendable {
    private let model: MLModel
    private let tokenizer: SimpleTokenizer
    private let embeddingDimension = 384

    public enum EmbeddingError: Error {
        case modelLoadFailed(String)
        case embeddingFailed(String)
        case invalidInput
    }

    public init(modelPath: String? = nil) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine  // Use Neural Engine if available

        if let path = modelPath {
            var url = URL(fileURLWithPath: path)

            // If .mlpackage path given, try .mlmodelc first (compiled version)
            if url.pathExtension == "mlpackage" {
                let compiledPath = url.deletingPathExtension().appendingPathExtension("mlmodelc")
                if FileManager.default.fileExists(atPath: compiledPath.path) {
                    url = compiledPath
                } else {
                    // Compile it on the fly
                    url = try MLModel.compileModel(at: url)
                }
            }

            self.model = try MLModel(contentsOf: url, configuration: config)
        } else {
            // Use bundled model (default for iOS app)
            guard let modelURL = Bundle.main.url(forResource: "MiniLM_L6_v2", withExtension: "mlmodelc")
                  ?? Bundle.main.url(forResource: "MiniLM_L6_v2", withExtension: "mlpackage") else {
                throw EmbeddingError.modelLoadFailed("Model not found in bundle")
            }

            if modelURL.pathExtension == "mlpackage" {
                // Compile if needed
                let compiledURL = try MLModel.compileModel(at: modelURL)
                self.model = try MLModel(contentsOf: compiledURL, configuration: config)
            } else {
                self.model = try MLModel(contentsOf: modelURL, configuration: config)
            }
        }

        self.tokenizer = SimpleTokenizer()
    }

    public func embed(_ text: String) async throws -> [Float] {
        return try await embedBatch([text]).first!
    }

    public func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []

        for text in texts {
            // Tokenize
            let (inputIds, attentionMask) = tokenizer.encode(text)

            // Create MLMultiArray inputs
            let inputIdsArray = try MLMultiArray(shape: [1, 128], dataType: .int32)
            let attentionMaskArray = try MLMultiArray(shape: [1, 128], dataType: .int32)

            for i in 0..<128 {
                inputIdsArray[i] = NSNumber(value: inputIds[i])
                attentionMaskArray[i] = NSNumber(value: attentionMask[i])
            }

            // Create input feature provider
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLFeatureValue(multiArray: inputIdsArray),
                "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
            ])

            // Run inference
            let output = try model.prediction(from: input)

            // Extract embeddings (384-dim)
            guard let embeddingsFeature = output.featureValue(for: "embeddings"),
                  let embeddingsArray = embeddingsFeature.multiArrayValue else {
                throw EmbeddingError.embeddingFailed("Failed to extract embeddings from model output")
            }

            var embedding: [Float] = []
            for i in 0..<embeddingDimension {
                embedding.append(Float(truncating: embeddingsArray[i]))
            }

            results.append(embedding)
        }

        return results
    }
}
#endif

// MARK: - Type Alias for Build-Time Selection

#if MOCK_EMBEDDINGS
public typealias EmbeddingModel = MockEmbeddingModel
#else
public typealias EmbeddingModel = CoreMLEmbeddingModel
#endif
