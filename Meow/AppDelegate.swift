//
//  AppDelegate.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import AppKit
import SwiftData

/// 应用委托：拦截 Dock/CMD+Q 的退出，改为隐藏到后台（menubar 模式）
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 由 menubar「退出」按钮设为 true，表示本次是真正的退出
    static var shouldTerminate = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] didFinishLaunching")
        GlobalShortcutMonitor.shared.start(with: _sharedModelContainer)
    }

    /// 显示主窗口（创建或恢复）
    func showMainWindow() {
        NSLog("[AppDelegate] showMainWindow, currentPolicy=%ld", NSApp.activationPolicy().rawValue)
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        // 将所有窗口带到前台
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
 
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.shouldTerminate {
            return .terminateNow
        }

        NSLog("[AppDelegate] Dock quit, hiding to menu bar, windows=%ld", sender.windows.count)
        // 先隐藏窗口，再移除 Dock 图标
        sender.hide(nil)
        NSApp.setActivationPolicy(.accessory)

        return .terminateCancel
    }
}
