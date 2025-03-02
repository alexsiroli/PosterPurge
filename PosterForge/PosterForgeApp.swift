// ========================================
// File: PosterForgeApp.swift
// ========================================
import SwiftUI

@main
struct PosterForgeApp: App {
    @StateObject var preferencesManager = PreferencesManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferencesManager)
        }
    }
}
