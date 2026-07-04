//
//  GlobalShortcutMonitor.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import Cocoa
import SwiftData
import ApplicationServices
import OSLog

/// 全局快捷键监听器（使用 CGEventTap）
@MainActor
final class GlobalShortcutMonitor {
    static let shared = GlobalShortcutMonitor()
    private let log = Logger(subsystem: "com.meow", category: "ShortcutMonitor")

    // MARK: - CGEventTap 回调

    private static let eventTapCallback: CGEventTapCallBack = { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = monitor.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown, monitor.handleCGEvent(event) { return nil }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - 属性

    private var eventTap: CFMachPort?
    private var container: ModelContainer?

    private var _shortcuts: [ShortcutItem] = []
    private let shortcutsLock = NSLock()
    private var shortcuts: [ShortcutItem] {
        get { shortcutsLock.withLock { _shortcuts } }
        set { shortcutsLock.withLock { _shortcuts = newValue } }
    }

    private(set) var isRunning = false
    private var retryTimer: DispatchSourceTimer?
    private var notificationObserver: NSObjectProtocol?
    private var _isMonitoringEnabled = true
    private let enableLock = NSLock()

    func pause() { enableLock.withLock { _isMonitoringEnabled = false }; log.info("⏸️ 监听暂停") }
    func resume() { enableLock.withLock { _isMonitoringEnabled = true }; log.info("▶️ 监听恢复") }


    private init() {}

    // MARK: - 启动

    func start(with container: ModelContainer) {
        self.container = container
        reloadShortcuts()
        log.info("✅ start() 被调用，短加载数量：\(self.shortcuts.count)")

        requestAccessibilityPermission()
        tryCreateEventTap()

        // 监听快捷键变更通知，block 方式避免 @objc 问题
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .shortcutsDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reloadShortcuts()
        }
    }

    // MARK: - CGEventTap

    private func tryCreateEventTap() {
        if eventTap != nil { return }
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(eventMask),
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("❌ CGEvent.tapCreate 失败，3 秒后重试")
            scheduleRetry()
            return
        }

        eventTap = tap
        let rlSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), rlSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        log.info("✅ CGEventTap 启动成功")
    }

    private func scheduleRetry() {
        retryTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        t.schedule(deadline: .now() + 3, repeating: 3)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            if self.eventTap == nil { self.log.info("⏳ 重试..."); self.tryCreateEventTap() }
            else { t.cancel() }
        }
        t.resume()
        retryTimer = t
    }

    // MARK: - 重载

    func reloadShortcuts() {
        guard let container else { return }
        let items = (try? container.mainContext.fetch(FetchDescriptor<ShortcutItem>())) ?? []
        shortcuts = items
        log.info("📋 重载快捷键：\(items.count) 个")
    }

    // MARK: - 事件匹配

    private func handleCGEvent(_ cgEvent: CGEvent) -> Bool {
        guard enableLock.withLock({ _isMonitoringEnabled }) else { return false }

        guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return false }
        guard let chars = nsEvent.charactersIgnoringModifiers?.lowercased() else { return false }
        let flags = nsEvent.modifierFlags
        let snapshot: [(ShortcutItem)] = shortcutsLock.withLock { Array(_shortcuts) }

        for item in snapshot where !item.keyEquivalent.isEmpty && item.keyEquivalent.lowercased() == chars {
            let matched = flags.contains(.command) == item.modifierCommand
                       && flags.contains(.shift)   == item.modifierShift
                       && flags.contains(.option)  == item.modifierOption
                       && flags.contains(.control) == item.modifierControl
            if matched {
                self.log.info("⚡️ 命中：\(item.displayText, privacy: .public) → \(item.appName, privacy: .public)")
                DispatchQueue.main.async { [weak self] in self?.launchOrActivate(item) }
                return true
            }
        }
        return false
    }

    // MARK: - 启动 / 激活

    private func launchOrActivate(_ item: ShortcutItem) {
        let appURL = URL(fileURLWithPath: item.appPath)
        if let app = findRunningApp(item, appURL: appURL) { activateApp(app); return }
        launchApp(appURL: appURL)
    }

    private func activateApp(_ app: NSRunningApplication) {
        if app.isHidden { app.unhide() }
        if let url = app.bundleURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(url, configuration: config)
        }
        app.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func launchApp(appURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
            if let error {
                self.log.error("⚠️ openApplication 失败：\(error.localizedDescription)")
                NSWorkspace.shared.open(appURL)
            }
        }
    }

    private func findRunningApp(_ item: ShortcutItem, appURL: URL) -> NSRunningApplication? {
        if !item.bundleIdentifier.isEmpty {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleIdentifier)
                .first(where: { !$0.isTerminated }) { return app }
        }
        let resolvedURL = appURL.resolvingSymlinksInPath()
        return NSWorkspace.shared.runningApplications.first { app in
            guard let bURL = app.bundleURL else { return false }
            return bURL.path == item.appPath || bURL.resolvingSymlinksInPath() == resolvedURL
        }
    }

    // MARK: - 辅助功能权限

    private func requestAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        log.info("🔐 辅助功能权限：\(trusted ? "已授权 ✅" : "未授权 ❌")")
        if trusted { return }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        AXIsProcessTrustedWithOptions([key: true] as NSDictionary as CFDictionary)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            if !AXIsProcessTrusted() { self.showPermissionGuide() }
        }
    }

    private func showPermissionGuide() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "「Meow」需要「辅助功能」权限才能全局监听快捷键。\n\n请到系统设置 → 隐私与安全性 → 辅助功能 → 勾选 Meow"
        alert.addButton(withTitle: "打开辅助功能设置")
        alert.addButton(withTitle: "稍后再说")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn { openAccessibilitySettings() }
    }

    private func openAccessibilitySettings() {
        var url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url { NSWorkspace.shared.open(url); return }
        url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity?Privacy_Accessibility")
        if let url { NSWorkspace.shared.open(url) }
    }
}
