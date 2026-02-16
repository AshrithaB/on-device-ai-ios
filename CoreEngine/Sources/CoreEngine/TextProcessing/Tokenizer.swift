import Foundation

/// Simple whitespace-based tokenizer for MVP
/// Production version should use proper subword tokenization matching the embedding model
public struct Tokenizer {
    public init() {}

    /// Tokenize text into words/tokens
    /// For MVP, uses simple whitespace splitting
    public func tokenize(_ text: String) -> [String] {
        // Normalize whitespace and split
        let normalized = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return normalized
    }

    /// Count tokens in text
    public func countTokens(_ text: String) -> Int {
        return tokenize(text).count
    }

    /// Encode text to token IDs (simplified for MVP)
    /// Returns approximate token indices - production should use actual model tokenizer
    public func encode(_ text: String) -> [Int] {
        return tokenize(text).enumerated().map { $0.offset }
    }

    /// Decode token IDs back to text (simplified for MVP)
    public func decode(_ tokens: [Int], from text: String) -> String {
        let words = tokenize(text)
        return tokens.compactMap { index in
            index < words.count ? words[index] : nil
        }.joined(separator: " ")
    }
}
