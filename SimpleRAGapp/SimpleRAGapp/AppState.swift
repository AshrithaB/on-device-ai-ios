import SwiftUI
import Combine
import CoreEngine

@MainActor
class AppState: ObservableObject {
    @Published var coreEngine: CoreEngine?
    @Published var isInitializing = true
    @Published var initializationError: String?
    @Published var statistics: EngineStats?
    
    init() {
        Task {
            await initializeCoreEngine()
        }
    }
    
    func initializeCoreEngine() async {
        do {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbDirectory = appSupport.appendingPathComponent("SimpleRAGApp", isDirectory: true)
            try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
            let dbPath = dbDirectory.appendingPathComponent("ragapp.db").path
            
            let engine = try await CoreEngine(databasePath: dbPath)
            let stats = try await engine.getStats()
            
            self.coreEngine = engine
            self.statistics = stats
            self.isInitializing = false
        } catch {
            self.initializationError = error.localizedDescription
            self.isInitializing = false
        }
    }
    
    func refreshStatistics() async {
        guard let engine = coreEngine else { return }
        do {
            let stats = try await engine.getStats()
            self.statistics = stats
        } catch {
            // Silent fail
        }
    }
}
