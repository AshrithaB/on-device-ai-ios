import SwiftUI
import CoreEngine

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var topK = 5
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Search input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Query")
                        .font(.headline)
                    
                    TextField("Enter your search...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(performSearch)
                }
                
                // Top K picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of results: \(topK)")
                        .font(.headline)
                    
                    Stepper("Results", value: $topK, in: 1...20)
                        .labelsHidden()
                }
                
                // Search button
                Button(action: performSearch) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(query.isEmpty || isSearching)
                
                // Results
                if !results.isEmpty {
                    List(results, id: \.chunk.id) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Doc \(result.chunk.documentId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.2f%%", result.score * 100))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            Text(result.chunk.content)
                                .font(.body)
                                .lineLimit(nil)
                        }
                        .padding(.vertical, 4)
                    }
                } else if !query.isEmpty && !isSearching {
                    Spacer()
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No results found")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Search")
        }
    }
    
    private func performSearch() {
        guard let engine = appState.coreEngine else { return }
        
        isSearching = true
        results = []
        
        Task {
            do {
                results = try await engine.search(query: query, topK: topK)
            } catch {
                print("Search error: \(error)")
            }
            isSearching = false
        }
    }
}
