//
//  MeowApp.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import SwiftUI
import SwiftData

@main
struct MeowApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ShortcutItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // 主窗口
        WindowGroup {
            ContentView()
                .onAppear {
                    GlobalShortcutMonitor.shared.start(with: sharedModelContainer)
                }
        }
        .commands {
            AppMenuCommands()
        }
        .modelContainer(sharedModelContainer)

        // 菜单栏图标
        MenuBarExtra("Meow", systemImage: "pawprint.fill") {
            Button("首页") {
                showMainWindow()
            }

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// 将主窗口显示到前台（从最小化/后台恢复）
    private func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible || $0.isMiniaturized }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
