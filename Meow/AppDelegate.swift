//
//  AppDelegate.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import AppKit
import SwiftData
import SwiftUI

/// 应用委托：拦截 Dock/CMD+Q 的退出，改为隐藏到后台（menubar 模式）
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 由 menubar「退出」按钮设为 true，表示本次是真正的退出
    static var shouldTerminate = false

    /// 静态引用，供菜单等非 App 内视图直接访问
    static weak var shared: AppDelegate?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 在 SwiftUI 设置场景之前强制 regular 模式（新版 macOS 中
        // MenuBarExtra + WindowGroup 共存时可能默认走 accessory）
        NSApp.setActivationPolicy(.regular)
        NSLog("[AppDelegate] willFinishLaunching, forced regular")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] didFinishLaunching")
        GlobalShortcutMonitor.shared.start(with: _sharedModelContainer)
        showMainWindow()
        NSLog("[AppDelegate] post-didFinishLaunching windows=%ld isHidden=%d", NSApp.windows.count, NSApp.isHidden)
    }

    /// 显示主窗口（创建或恢复）
    func showMainWindow() {
        NSLog("[AppDelegate] showMainWindow policy=%ld windows=%ld isHidden=%d",
              NSApp.activationPolicy().rawValue, NSApp.windows.count, NSApp.isHidden)
        NSApp.setActivationPolicy(.regular)

        // 先 unhide（如果被 NSApp.hide 隐藏过），否则窗口恢复后会停留在非活跃状态
        if NSApp.isHidden { NSApp.unhide(nil) }

        // 恢复已有窗口
        let win = NSApp.windows.first(where: { $0.isVisible || $0.isMiniaturized })
            ?? NSApp.windows.first  // hidden window after hide/unhide
            ?? createMainWindow()   // all windows closed by user
        win.makeKeyAndOrderFront(nil)

        NSApplication.shared.activate(ignoringOtherApps: true)
        NSLog("[AppDelegate] showMainWindow done isHidden=%d", NSApp.isHidden)
    }
 
    private func createMainWindow() -> NSWindow {
        let hostingCtrl = NSHostingController(
            rootView: ContentView().modelContainer(_sharedModelContainer)
        )
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "Meow"
        window.setFrameAutosaveName("MainWindow")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        return window
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.shouldTerminate {
            NSLog("[AppDelegate] shouldTerminate: returning NOW")
            return .terminateNow
        }

        NSLog("[AppDelegate] shouldTerminate: Dock quit, hiding to menu bar, windows=%ld", sender.windows.count)
        // 先隐藏窗口，再移除 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        sender.hide(nil)

        NSLog("[AppDelegate] shouldTerminate: done, isHidden=%d", NSApp.isHidden)
        return .terminateCancel
    }
}
