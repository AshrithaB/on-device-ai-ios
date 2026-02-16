import Foundation

/// Normalizes text before chunking and embedding
public struct TextNormalizer {
    public init() {}

    /// Normalize text by cleaning whitespace and standardizing format
    public func normalize(_ text: String) -> String {
        var normalized = text

        // Normalize line endings
        normalized = normalized.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")

        // Remove excessive whitespace
        normalized = normalized.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )

        // Normalize multiple newlines to maximum of 2
        normalized = normalized.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        // Trim whitespace from start and end
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized
    }

    /// Clean text by removing special characters (optional)
    public func clean(_ text: String, removeSpecialChars: Bool = false) -> String {
        var cleaned = text

        if removeSpecialChars {
            // Remove non-alphanumeric except basic punctuation and whitespace
            cleaned = cleaned.replacingOccurrences(
                of: "[^a-zA-Z0-9\\s.,!?;:'\"-]",
                with: "",
                options: .regularExpression
            )
        }

        return cleaned
    }
}
