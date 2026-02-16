//
//  SimpleRAGappApp.swift
//  SimpleRAGapp
//
//  Created by Nitin Datta Movva on 2/16/26.
//

import SwiftUI

@main
struct SimpleRAGappApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
