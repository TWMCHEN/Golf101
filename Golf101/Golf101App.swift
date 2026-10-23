//
//  Golf101App.swift
//  Golf101
//
//  Created by Hsiaoyi Chen on 2026/10/23.
//

import SwiftUI
import SwiftData

@main
struct Golf101App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlayerProfile.self,
            StageRecord.self,
            Item.self
        ])
        let persistentConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [persistentConfig]) {
            return container
        }
        // Graceful fallback to in-memory container if persistent storage is unavailable
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let fallbackContainer = try? ModelContainer(for: schema, configurations: [memoryConfig]) else {
            preconditionFailure("Unable to initialize SwiftData ModelContainer")
        }
        return fallbackContainer
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
