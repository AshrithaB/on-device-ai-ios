import SwiftUI
import CoreEngine

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var documents: [Document] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading documents...")
                } else if documents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No documents yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Add your first document to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section(header: Text("Documents (\(documents.count))")) {
                            ForEach(documents, id: \.id) { doc in
                                NavigationLink(destination: DocumentDetailView(document: doc)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(doc.title)
                                            .font(.headline)
                                        if let source = doc.source {
                                            Text(source)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text("Added: \(doc.createdAt, style: .date)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .onDelete(perform: deleteDocuments)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !documents.isEmpty {
                        EditButton()
                    }
                }
                #endif
                ToolbarItem(placement: .automatic) {
                    Button(action: loadDocuments) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                loadDocuments()
            }
        }
    }
    
    private func loadDocuments() {
        guard let engine = appState.coreEngine else { return }
        
        isLoading = true
        Task {
            do {
                documents = try await engine.getDocuments()
            } catch {
                print("Error loading documents: \(error)")
            }
            isLoading = false
        }
    }
    
    private func deleteDocuments(at offsets: IndexSet) {
        guard let engine = appState.coreEngine else { return }
        
        Task {
            for index in offsets {
                let doc = documents[index]
                do {
                    try await engine.deleteDocument(id: doc.id)
                } catch {
                    print("Error deleting document: \(error)")
                }
            }
            loadDocuments()
            await appState.refreshStatistics()
        }
    }
}
