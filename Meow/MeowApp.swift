//
//  MeowApp.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import SwiftUI
import SwiftData

/// 全局共享的 ModelContainer（供 AppDelegate 和 SwiftUI 场景共用）
let _sharedModelContainer: ModelContainer = {
    let schema = Schema([ShortcutItem.self, PetItem.self])
    let modelConfiguration = ModelConfiguration("MeowData", schema: schema, isStoredInMemoryOnly: false, allowsSave: true, groupContainer: .none, cloudKitDatabase: .none)
    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()

@main
struct MeowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer { _sharedModelContainer }
    
    var body: some Scene {
        // 主窗口
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .commands {
            AppMenuCommands()
        }
        .modelContainer(_sharedModelContainer)
    }
}
