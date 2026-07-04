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
        // 1) 先 unhide（setPolicy(.regular) 会消除 isHidden，导致 unhide 空转）
        if NSApp.isHidden { NSApp.unhide(nil) }
        // 2) 再回复 Dock 图标
        NSApp.setActivationPolicy(.regular)

        // 3) 找窗口：可见/最小化 → 隐藏 → 重建
        let hasTitledWindow = NSApp.windows.contains { $0.styleMask.contains(.titled) }
        let win: NSWindow
        if hasTitledWindow {
            win = NSApp.windows.first(where: { $0.isVisible || $0.isMiniaturized })
                ?? NSApp.windows.first!
        } else {
            // 用户关闭了主窗口，内部窗口都是无标题的 → 重建
            NSLog("[AppDelegate] no titled window, creating new main window")
            win = createMainWindow()
        }
        // 透明标题栏（toolbar 背景色透出内容区）
        win.titlebarAppearsTransparent = true
        win.makeKeyAndOrderFront(nil)

        NSApplication.shared.activate(ignoringOtherApps: true)
        NSLog("[AppDelegate] showMainWindow done policy=%ld win=%@", NSApp.activationPolicy().rawValue, win)
    }
 
    private func createMainWindow() -> NSWindow {
        let hostingCtrl = NSHostingController(
            rootView: ContentView().modelContainer(_sharedModelContainer)
        )
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "Meow"
        window.setFrameAutosaveName("MainWindow")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.center()
        return window
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.shouldTerminate {
            NSLog("[AppDelegate] shouldTerminate: returning NOW")
            return .terminateNow
        }

        // 1) 先隐藏窗口
        sender.hide(nil)
        // 2) 再移除 Dock 图标（与 showMainWindow 对称）
        NSApp.setActivationPolicy(.accessory)

        NSLog("[AppDelegate] shouldTerminate: done isHidden=%d", NSApp.isHidden)
        return .terminateCancel
    }
}
