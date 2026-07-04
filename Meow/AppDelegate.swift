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

    /// SwiftData 容器引用（由 MeowApp 启动时注入）
    var modelContainer: ModelContainer?
 
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 注入全局 ModelContainer
        modelContainer = _sharedModelContainer
        // 启动全局快捷键监听
        GlobalShortcutMonitor.shared.start(with: _sharedModelContainer)
        // 首次启动显示主窗口
        showMainWindow()
    }

    /// 手动管理的主窗口（不依赖 WindowGroup，解决 policy 切换后窗口不重建的问题）
    private var mainWindowController: NSWindowController?
 
    /// 显示主窗口（创建或恢复）
    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
 
        if let wc = mainWindowController, let window = wc.window {
            window.makeKeyAndOrderFront(nil)
        } else {
            createMainWindow()
        }
 
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
 
    private func createMainWindow() {
        guard let container = modelContainer else { return }
 
        let contentView = ContentView()
            .modelContainer(container)
        let hostingCtrl = NSHostingController(rootView: contentView)
 
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "Meow"
        window.setFrameAutosaveName("MainWindow")
        window.tabbingMode = .disallowed
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
 
        let wc = NSWindowController(window: window)
        wc.shouldCascadeWindows = false
        wc.windowFrameAutosaveName = "MainWindow"
 
        mainWindowController = wc
        window.makeKeyAndOrderFront(nil)
    }
 
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.shouldTerminate {
            return .terminateNow
        }

        // 隐藏窗口 + 从 Dock 移除
        mainWindowController?.window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)

        return .terminateCancel
    }
}
