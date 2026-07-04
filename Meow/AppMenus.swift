//
//  AppMenus.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import SwiftUI

// MARK: - 菜单栏配置

struct AppMenuCommands: Commands {
    var body: some Commands {
        // MARK: 诊断工具
        CommandGroup(after: .appInfo) {
            Divider()
            Button("检查快捷键状态") {
                checkShortcutStatus()
            }
        }

        // MARK: 快捷键（Shortcuts）
        CommandMenu("快捷键") {
            Section {
                Button("快捷键设置...") {
                    AppMenuAction.showShortcutSettings()
                }

                Button("查看所有快捷键") {
                    AppMenuAction.showShortcutList()
                }
            }

            Divider()

            Section {
                Button("切换快捷键显示") {
                    AppMenuAction.toggleShortcutOverlay()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        // MARK: 宠物（Pet）
        CommandMenu("宠物") {
            Section {
                Button("添加新宠物...") {
                    AppMenuAction.addNewPet()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("宠物列表") {
                    AppMenuAction.showPetList()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            Divider()

            Section {
                Button("宠物设置...") {
                    AppMenuAction.showPetSettings()
                }
                .keyboardShortcut(",", modifiers: [.command, .option])
            }
        }
    }

    /// 诊断：检查全局监听状态
    private func checkShortcutStatus() {
        let trusted = AXIsProcessTrusted()
        let alert = NSAlert()
        alert.messageText = "快捷键状态"
        alert.informativeText = """
        辅助功能权限: \(trusted ? "✅ 已授权" : "❌ 未授权")
        全局监听器: \(GlobalShortcutMonitor.shared.isRunning ? "✅ 运行中" : "❌ 未启动")
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")

        if !trusted {
            alert.addButton(withTitle: "打开权限设置")
            let resp = alert.runModal()
            if resp == .alertSecondButtonReturn {
                openAccessibilitySettings()
            }
        } else {
            alert.runModal()
        }
    }

    /// 打开辅助功能设置
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url { NSWorkspace.shared.open(url) }
    }
}

// MARK: - 菜单动作

enum AppMenuAction {
    static func showShortcutSettings() {
        postNavigation(.shortcuts)
    }

    static func showShortcutList() {
        postNavigation(.shortcuts)
    }

    static func toggleShortcutOverlay() {
        print("[Menu] 切换快捷键显示")
    }

    static func addNewPet() {
        postNavigation(.pets)
    }

    static func showPetList() {
        postNavigation(.pets)
    }

    static func showPetSettings() {
        postNavigation(.pets)
    }

    private static func postNavigation(_ section: SidebarSection) {
        NotificationCenter.default.post(
            name: .navigateToSection,
            object: nil,
            userInfo: ["section": section.rawValue]
        )
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let navigateToSection = Notification.Name("com.meow.navigateToSection")
    static let shortcutsDidChange = Notification.Name("com.meow.shortcutsDidChange")
}
