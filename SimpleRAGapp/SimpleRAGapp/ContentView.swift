import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if appState.isInitializing {
                ProgressView("Initializing...")
            } else if let error = appState.initializationError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Error: \(error)")
                }
            } else {
                TabView(selection: $selectedTab) {
                    LibraryView()
                        .tabItem {
                            Label("Library", systemImage: "folder.fill")
                        }
                        .tag(0)
                    
                    AddDocumentView()
                        .tabItem {
                            Label("Add", systemImage: "plus.circle.fill")
                        }
                        .tag(1)
                    
                    SearchView()
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        .tag(2)
                    
                    ChatView()
                        .tabItem {
                            Label("Ask", systemImage: "message.fill")
                        }
                        .tag(3)
                }
            }
        }
    }
}


