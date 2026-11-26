//
//  PermissionGate.swift
//  Meow
//
//  Created by boyyang on 2026/11/26.
//

import AppKit
import ApplicationServices
import CoreServices
import OSLog

/// 「控制其他 App」授权状态（macOS 27.3 起对应「系统与 App 保护覆盖」）
enum AppControlPermissionStatus: Equatable {
    /// 已授权（完整覆盖，或包含探测目标）
    case granted
    /// 尚未询问过，可直接请求授权
    case notDetermined
    /// 已拒绝或仅授权了部分 App
    case denied
}

/// 超级关闭所需权限的检测与授权入口
enum PermissionGate {
    private nonisolated static let log = Logger(subsystem: "com.meow", category: "PermissionGate")

    // MARK: - 辅助功能（全局快捷键监听）

    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
           NSWorkspace.shared.open(url) { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 控制其他 App（优雅退出其它应用）

    /// 以 Finder 为探测目标近似判断授权状态（系统无公开的状态查询 API）
    static func probeAppControl() async -> AppControlPermissionStatus {
        await Task.detached(priority: .utility) {
            determineAppControl(askUserIfNeeded: false)
        }.value
    }

    /// 重新触发系统授权弹框；仅「未询问」状态会弹出，已拒绝需到系统设置重新添加
    static func requestAppControl() async -> AppControlPermissionStatus {
        await Task.detached(priority: .userInitiated) {
            determineAppControl(askUserIfNeeded: true)
        }.value
    }

    static func openAppControlSettings() {
        // 新面板无公开 URL 锚点，锚点无效时会落在「隐私与安全性」根面板
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SystemAppProtectionOverride"),
           NSWorkspace.shared.open(url) { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private nonisolated static func determineAppControl(askUserIfNeeded: Bool) -> AppControlPermissionStatus {
        var address = AEAddressDesc()
        let bytes = Array("com.apple.finder".utf8)
        let createStatus = AECreateDesc(typeApplicationBundleID, bytes, bytes.count, &address)
        guard createStatus == noErr else {
            log.error("❌ AECreateDesc 失败")
            return .denied
        }
        defer { AEDisposeDesc(&address) }

        let status = AEDeterminePermissionToAutomateTarget(&address, typeWildCard, typeWildCard, askUserIfNeeded)
        log.info("🔐 控制其他 App 探测：\(status, privacy: .public)")
        switch status {
        case 0:     return .granted        // noErr
        case -1744: return .notDetermined  // errAEEventWouldRequireUserConsent
        default:    return .denied         // errAEEventNotPermitted 等
        }
    }
}
