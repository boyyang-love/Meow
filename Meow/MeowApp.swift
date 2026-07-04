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
            MeowMenuView()
        }
        .modelContainer(sharedModelContainer)
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
            NSApplication.shared.terminate(nil)
        }
    }

    private func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible || $0.isMiniaturized }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
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
