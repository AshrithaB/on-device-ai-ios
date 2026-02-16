import Foundation
import CoreEngine

@main
struct CoreEngineCLI {
    static func main() async {
        print("=== Core Engine Demo ===\n")

        do {
            // Create engine instance with persistent database
            print("Initializing Core Engine...")
            let dbPath = "/tmp/coreengine_demo.db"
            print("Database path: \(dbPath)")
            let engine = try await CoreEngine(databasePath: dbPath)

            // Sample document
            let sampleText = """
            Machine learning is a subset of artificial intelligence that focuses on the development
            of algorithms and statistical models that enable computers to learn from and make
            predictions or decisions based on data. Unlike traditional programming, where explicit
            instructions are provided, machine learning systems improve their performance through
            experience.

            There are three main types of machine learning: supervised learning, unsupervised learning,
            and reinforcement learning. Supervised learning uses labeled data to train models, making
            it ideal for tasks like classification and regression. Unsupervised learning finds patterns
            in unlabeled data, useful for clustering and dimensionality reduction. Reinforcement learning
            involves training agents to make sequences of decisions by rewarding desired behaviors.

            Neural networks are a popular approach in machine learning, inspired by the structure of
            biological brains. Deep learning, which uses multi-layer neural networks, has achieved
            remarkable success in areas such as image recognition, natural language processing, and
            game playing. The availability of large datasets and powerful computing resources has
            accelerated the adoption of deep learning across many industries.
            """

            // Ingest document
            print("Ingesting sample document...")
            let document = try await engine.ingest(
                title: "Introduction to Machine Learning",
                content: sampleText,
                source: "demo"
            )
            print("✓ Document ingested: \(document.title)")
            print("  Document ID: \(document.id)\n")

            // Get chunks
            print("Retrieving chunks...")
            let chunks = try await engine.getChunks(forDocument: document.id)
            print("✓ Created \(chunks.count) chunks:\n")

            for (index, chunk) in chunks.enumerated() {
                print("Chunk \(index + 1):")
                print("  ID: \(chunk.id)")
                print("  Tokens: \(chunk.tokenCount)")
                print("  Preview: \(String(chunk.content.prefix(80)))...")
                print()
            }

            // Get stats
            let stats = try await engine.getStats()
            print("=== Statistics ===")
            print("Documents: \(stats.documentCount)")
            print("Chunks: \(stats.chunkCount)")
            print()

            // Ingest another document
            print("Ingesting second document...")
            let document2 = try await engine.ingest(
                title: "Types of Neural Networks",
                content: """
                Convolutional Neural Networks (CNNs) are specialized for processing grid-like data
                such as images. They use convolutional layers to automatically learn spatial hierarchies
                of features. Recurrent Neural Networks (RNNs) are designed for sequential data like
                time series or text, maintaining hidden states that capture information about previous
                inputs. Transformers have revolutionized natural language processing by using
                self-attention mechanisms to process sequences in parallel.
                """,
                source: "demo"
            )
            print("✓ Document ingested: \(document2.title)\n")

            // Final stats
            let finalStats = try await engine.getStats()
            print("=== Final Statistics ===")
            print("Documents: \(finalStats.documentCount)")
            print("Chunks: \(finalStats.chunkCount)")
            print("Vectors: \(finalStats.vectorCount) (persisted to database)")
            print("Memory: \(String(format: "%.2f MB", finalStats.memoryMB))")
            print()

            // Demonstrate semantic search
            print("=== Semantic Search Demo ===\n")

            let queries = [
                "What are neural networks?",
                "Tell me about supervised learning",
                "How do transformers work?",
                "What is deep learning used for?"
            ]

            for (index, query) in queries.enumerated() {
                print("Query \(index + 1): \"\(query)\"")
                let results = try await engine.search(query: query, topK: 3, minScore: 0.0)

                if results.isEmpty {
                    print("  No results found\n")
                } else {
                    for result in results {
                        print("  [\(result.rank)] Score: \(String(format: "%.3f", result.score))")
                        print("      \(String(result.chunk.content.prefix(100)))...")
                    }
                    print()
                }
            }

            print("✅ Demo completed successfully!")

        } catch {
            print("❌ Error: \(error)")
        }
    }
}
