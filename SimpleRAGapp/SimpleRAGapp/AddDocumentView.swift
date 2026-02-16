import SwiftUI
import CoreEngine

struct AddDocumentView: View {
    @EnvironmentObject var appState: AppState
    @State private var documentText = ""
    @State private var isProcessing = false
    @State private var statusMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Add Document")
                    .font(.largeTitle)
                    .bold()
                
                TextEditor(text: $documentText)
                    .font(.body)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .frame(minHeight: 200)
                
                Button(action: addDocument) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Label("Add Document", systemImage: "plus.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(documentText.isEmpty || isProcessing)
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundColor(statusMessage.contains("Error") ? .red : .green)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Document")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
    
    private func addDocument() {
        guard let engine = appState.coreEngine else { return }
        
        isProcessing = true
        statusMessage = ""
        
        Task {
            do {
                // CoreEngine.ingest() needs title, content, and optional source
                let title = "Document \(Date().timeIntervalSince1970)"
                try await engine.ingest(title: title, content: documentText, source: nil)
                await appState.refreshStatistics()

                statusMessage = "✅ Document added successfully!"
                documentText = ""

                // Clear status after 2 seconds
                try? await Task.sleep(for: .seconds(2))
                statusMessage = ""
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isProcessing = false
        }
    }
}
