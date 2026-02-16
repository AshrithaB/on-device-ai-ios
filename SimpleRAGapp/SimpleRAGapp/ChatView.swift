import SwiftUI
import CoreEngine

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var question = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var topK = 3
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if messages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "message")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                    Text("Ask a question")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("I'll search your documents and provide an answer")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            } else {
                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input area
                VStack(spacing: 8) {
                    HStack {
                        Text("Context chunks:")
                            .font(.caption)
                        Stepper("\(topK)", value: $topK, in: 1...10)
                            .labelsHidden()
                        Text("\(topK)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    
                    HStack(spacing: 12) {
                        TextField("Ask a question...", text: $question, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...5)
                            .onSubmit(sendMessage)
                        
                        Button(action: sendMessage) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .disabled(question.isEmpty || isProcessing)
                    }
                }
                .padding()
            }
            .navigationTitle("Ask")
        }
    }
    
    private func sendMessage() {
        guard let engine = appState.coreEngine else { return }
        
        let userQuestion = question
        question = ""
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: userQuestion)
        messages.append(userMessage)
        
        isProcessing = true
        
        Task {
            do {
                // Get search results first
                let searchResults = try await engine.search(query: userQuestion, topK: topK)

                // Use askComplete to get the full answer
                let answer = try await engine.askComplete(query: userQuestion, topK: topK)

                // Add assistant message
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: answer.text,
                    sources: searchResults
                )
                messages.append(assistantMessage)
            } catch {
                // Add error message
                let errorMessage = ChatMessage(
                    role: .assistant,
                    content: "Error: \(error.localizedDescription)"
                )
                messages.append(errorMessage)
            }
            isProcessing = false
        }
    }
}

// MARK: - Supporting Types

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    var sources: [SearchResult]?
    
    enum Role {
        case user
        case assistant
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showSources = false
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                if let sources = message.sources, !sources.isEmpty {
                    Button(action: { showSources.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: showSources ? "chevron.down" : "chevron.right")
                                .font(.caption)
                            Text("\(sources.count) sources")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if showSources {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(sources.indices, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Source \(index + 1)")
                                            .font(.caption)
                                            .bold()
                                        Text(String(format: "%.1f%%", sources[index].score * 100))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(sources[index].chunk.content)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}
