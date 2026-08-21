//
//  GlobalShortcutMonitor.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import Cocoa
import UserNotifications
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
    private(set) var superCloseShortcut: SuperCloseShortcut = .empty
 private var _isMonitoringEnabled = true
    private let enableLock = NSLock()

    func pause() { enableLock.withLock { _isMonitoringEnabled = false }; log.info("⏸️ 监听暂停") }
    func resume() { enableLock.withLock { _isMonitoringEnabled = true }; log.info("▶️ 监听恢复") }

    /// 用户是否启用了快捷键监听（由 pause/resume 控制，与底层 tap 是否创建成功无关）
    var isMonitoringEnabled: Bool {
        enableLock.withLock { _isMonitoringEnabled }
    }


    private init() {}

    // MARK: - 启动

   func start(with container: ModelContainer) {
       self.container = container
       reloadShortcuts()
        reloadSuperCloseShortcut()
        log.info("✅ start() 被调用，快捷键数量：\(self.shortcuts.count)")

        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { self.log.warning("通知权限请求失败：\(error.localizedDescription)") }
        }


       requestAccessibilityPermission()
       tryCreateEventTap()

        // 监听快捷键变更通知
        NotificationCenter.default.addObserver(
           forName: .shortcutsDidChange, object: nil, queue: .main
       ) { [weak self] _ in
           self?.reloadShortcuts()
       }
        NotificationCenter.default.addObserver(
            forName: .superCloseShortcutDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reloadSuperCloseShortcut()
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


       // 检查超级关闭快捷键
       let closeShortcut = superCloseShortcut

       if closeShortcut.isEnabled && !closeShortcut.keyEquivalent.isEmpty
           && closeShortcut.keyEquivalent.lowercased() == chars
            && flags.contains(.command) == closeShortcut.modifierCommand
            && flags.contains(.shift)   == closeShortcut.modifierShift
            && flags.contains(.option)  == closeShortcut.modifierOption
            && flags.contains(.control) == closeShortcut.modifierControl
        {
            self.log.info("⚡️ 超级关闭命中")
            DispatchQueue.main.async { [weak self] in self?.superCloseAllApps() }
            return true
        }

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
    // MARK: - 超级关闭

    func reloadSuperCloseShortcut() {
        superCloseShortcut = SuperCloseShortcut.load()
        log.info("📋 超级关闭快捷键：\\(self.superCloseShortcut.displayText, privacy: .public)")
    }

    func superCloseAllApps() {
        let meowBundle = Bundle.main.bundleIdentifier ?? "com.meow.MeowApp"
        let excludedIDs: Set<String> = [
            meowBundle,
            "com.apple.finder",
            "com.apple.loginwindow",
            "com.apple.dock",
            "com.apple.systempreferences",
            "com.apple.systemuiserver",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui",
        ]

        let apps = NSWorkspace.shared.runningApplications
        var closedCount = 0
        var failedApps: [String] = []
        var sigkillUsed = false

        for app in apps {
            guard !app.isTerminated else { continue }
            guard app.activationPolicy == .regular else { continue }
            guard let bundleID = app.bundleIdentifier, !excludedIDs.contains(bundleID) else { continue }
            let name = app.localizedName ?? bundleID
            log.info("🔄 正在关闭: \(name, privacy: .public) (\(bundleID, privacy: .public))")
            
            // 1) 先尝试 NSRunningApplication.terminate()（优雅退出）
            if app.terminate() {
                closedCount += 1
                log.info("✅ terminate() 成功: \(name, privacy: .public)")
                continue
            }
            
            // 2) 失败 → POSIX kill(SIGTERM)
            let pid = app.processIdentifier
            guard pid > 0 else { failedApps.append(name); continue }
            let sigtermResult = kill(pid, SIGTERM)
            if sigtermResult == 0 {
                closedCount += 1
                log.info("✅ kill(SIGTERM) 成功: \(name, privacy: .public)")
                continue
            }
            
            // 3) SIGTERM 失败 → POSIX kill(SIGKILL)
            sigkillUsed = true
            let sigkillResult = kill(pid, SIGKILL)
            if sigkillResult == 0 {
                closedCount += 1
                log.info("⚠️ kill(SIGKILL) 强制关闭: \(name, privacy: .public)")
            } else {
                failedApps.append(name)
                log.info("❌ 所有方式最终失败: \(name, privacy: .public) errno=\(errno)")
            }
        }

        if failedApps.isEmpty {
            let mode = sigkillUsed ? "（含强制关闭）" : ""
            log.info("🛑 超级关闭完成，关闭了 \(closedCount) 个应用\(mode)")
        } else {
            log.info("🛑 超级关闭完成，关闭了 \(closedCount) 个应用，\(failedApps.count) 个关闭失败：\(failedApps.joined(separator: ", "), privacy: .public)")
        }

        if closedCount > 0 {
            let content = UNMutableNotificationContent()
            content.title = "超级关闭"
            if failedApps.isEmpty {
                let mode = sigkillUsed ? "（含强制关闭）" : ""
                content.body = "已关闭 \(closedCount) 个应用\(mode)"
            } else {
                content.body = "已关闭 \(closedCount) 个，\(failedApps.count) 个失败"
            }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

}
