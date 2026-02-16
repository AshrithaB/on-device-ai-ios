import SwiftUI
import CoreEngine

struct DocumentDetailView: View {
    @EnvironmentObject var appState: AppState
    let document: Document
    @State private var chunks: [Chunk] = []
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading chunks...")
            } else if chunks.isEmpty {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No chunks found")
                        .foregroundColor(.secondary)
                }
            } else {
                List(chunks, id: \.id) { chunk in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Chunk \(chunk.chunkIndex + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(chunk.tokenCount) tokens")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Text(chunk.content)
                            .font(.body)
                            .lineLimit(nil)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(document.title)
        .task {
            loadChunks()
        }
    }
    
    private func loadChunks() {
        guard let engine = appState.coreEngine else { return }
        
        isLoading = true
        Task {
            do {
                chunks = try await engine.getChunks(forDocument: document.id)
            } catch {
                print("Error loading chunks: \(error)")
            }
            isLoading = false
        }
    }
}
