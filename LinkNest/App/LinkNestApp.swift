//
//  LinkNestApp.swift
//  LinkNest
//

import SwiftUI
import SwiftData

@main
struct LinkNestApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(container.appState)
                .environment(container.router)
                .modelContainer(container.modelContainer)
                .preferredColorScheme(container.appState.themeMode.colorScheme)
        }
    }
}
