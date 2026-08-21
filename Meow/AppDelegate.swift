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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// 由 menubar「退出」按钮设为 true，表示本次是真正的退出
    static var shouldTerminate = false
    
    /// 静态引用，供菜单等非 App 内视图直接访问
    static weak var shared: AppDelegate?
    
    override init() {
        super.init()
        Self.shared = self
    }
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
    
    private func registerWindowDelegate() {
        for win in NSApp.windows where win.styleMask.contains(.titled) {
            win.delegate = self
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }
    
    @objc func windowDidBecomeKey(_ note: Notification) {
        guard let win = note.object as? NSWindow, win.styleMask.contains(.titled) else { return }
        win.delegate = self
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !isPreview else { return }
        // 在 SwiftUI 设置场景之前强制 regular 模式（保证 Dock 图标 + 主窗口显示）
        NSApp.setActivationPolicy(.regular)
        NSLog("[AppDelegate] willFinishLaunching, forced regular")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] didFinishLaunching")
        guard !isPreview else { return }
        GlobalShortcutMonitor.shared.start(with: _sharedModelContainer)
        _ = MenuBarController.shared   // 菜单栏图标 + 弹出面板（箭头指向图标，面板居中对齐）
        showMainWindow()
        registerWindowDelegate()
        NSLog("[AppDelegate] post-didFinishLaunching windows=%ld isHidden=%d", NSApp.windows.count, NSApp.isHidden)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            showMainWindow()
            return true
        }
        NSLog("[AppDelegate] handleReopen: no visible windows, deferring to system")
        return false
    }
    
    /// 隐藏主窗口到菜单栏（调回 accessory 模式）
    func hideToMenuBar() {
        NSApp.setActivationPolicy(.accessory)
        for window in NSApp.windows where window.level != .floating {
            window.orderOut(nil)
        }
    }
    
    /// 显示主窗口（创建或恢复）
    func showMainWindow() {
        // 1) 先 unhide（setPolicy(.regular) 会消除 isHidden，导致 unhide 空转）
        if NSApp.isHidden { NSApp.unhide(nil) }
        // 2) 再回复 Dock 图标
        NSApp.setActivationPolicy(.regular)
        
        let totalWindows = NSApp.windows.count
        let titledWins = NSApp.windows.filter { $0.styleMask.contains(.titled) }
        let visibleTitled = titledWins.filter { $0.isVisible || $0.isMiniaturized }
        let hasTitledWindow = !titledWins.isEmpty
        
        NSLog("[AppDelegate] showMainWindow: total=%ld titled=%ld visible=%ld",
              totalWindows, titledWins.count, visibleTitled.count)
        
        let win: NSWindow
        if let visible = visibleTitled.first {
            win = visible
            NSLog("[AppDelegate] showMainWindow: using visible titled win")
        } else if let closed = titledWins.first {
            win = closed
            NSLog("[AppDelegate] showMainWindow: restoring closed titled win")
        } else {
            NSLog("[AppDelegate] showMainWindow: no titled window, creating new main window")
            win = createMainWindow()
        }
        // 标准 macOS 标题栏，由系统自动处理交通灯安全区域
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
        
        // 1) 切换到menubar模式，移除 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        // 2) 只隐藏主窗口，浮动宠物窗口保持可见
        for window in NSApp.windows where window.level != .floating {
            window.orderOut(nil)
        }
        
        NSLog("[AppDelegate] shouldTerminate: switched to accessory, pet kept visible")
        return .terminateCancel
    }
}
