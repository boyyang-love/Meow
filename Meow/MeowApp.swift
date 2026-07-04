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
    let schema = Schema([ShortcutItem.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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
                .onAppear {
                    GlobalShortcutMonitor.shared.start(with: _sharedModelContainer)
                }
        }
        .commands {
            AppMenuCommands()
        }
        .modelContainer(_sharedModelContainer)

        // 菜单栏图标
        MenuBarExtra("Meow", systemImage: "pawprint.fill") {
            MeowMenuView()
        }
        .modelContainer(_sharedModelContainer)
    }
}

// MARK: - MenuBar 菜单视图

private struct MeowMenuView: View {
    @State private var isMonitoringEnabled = GlobalShortcutMonitor.shared.isRunning

    var body: some View {
        Button("首页") {
            showMainWindow()
        }

        Button("快捷键管理") {
            navigateTo(.shortcuts)
        }

        Button("宠物管理") {
            navigateTo(.pets)
        }

        Divider()

        Toggle("快捷键监听", isOn: $isMonitoringEnabled)
            .onChange(of: isMonitoringEnabled) { _, newValue in
                if newValue {
                    GlobalShortcutMonitor.shared.resume()
                } else {
                    GlobalShortcutMonitor.shared.pause()
                }
            }

        Divider()

        Button("退出") {
            AppDelegate.shouldTerminate = true
            NSApplication.shared.terminate(nil)
        }
    }

    private func showMainWindow() {
        (NSApplication.shared.delegate as? AppDelegate)?.showMainWindow()
    }

    private func navigateTo(_ section: SidebarSection) {
        showMainWindow()
        NotificationCenter.default.post(
            name: .navigateToSection,
            object: nil,
            userInfo: ["section": section.rawValue]
        )
    }
}
