//
//  AppDelegate.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import AppKit

/// 应用委托：拦截 Dock/CMD+Q 的退出，改为隐藏到后台（menubar 模式）
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 由 menubar「退出」按钮设为 true，表示本次是真正的退出
    static var shouldTerminate = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.shouldTerminate {
            return .terminateNow
        }

        // Dock/CMD+Q → 隐藏到后台
        NSApp.setActivationPolicy(.accessory)

        // 隐藏所有窗口（不销毁，保留窗口对象以便从 menubar 恢复）
        sender.windows.forEach { $0.orderOut(nil) }

        return .terminateCancel
    }
}
