//
//  SuperCloseShortcut.swift
//  Meow
//
//  Created by boyyang on 2026/7/15.
//

import Foundation

/// 超级关闭快捷键配置（UserDefaults 持久化）
struct SuperCloseShortcut: Codable, Equatable {
    var keyEquivalent: String
    var modifierCommand: Bool
    var modifierShift: Bool
    var modifierOption: Bool
    var modifierControl: Bool
    var isEnabled: Bool

    /// 清空状态
    static let empty = SuperCloseShortcut(
        keyEquivalent: "",
        modifierCommand: false,
        modifierShift: false,
        modifierOption: false,
        modifierControl: false,
        isEnabled: false
    )

    var displayText: String {
        guard !keyEquivalent.isEmpty else { return "未设置" }
        var parts = ""
        if modifierControl { parts += "⌃" }
        if modifierOption  { parts += "⌥" }
        if modifierShift   { parts += "⇧" }
        if modifierCommand { parts += "⌘" }
        parts += keyEquivalent.uppercased()
        return parts
    }
}

// MARK: - UserDefaults 存取
extension SuperCloseShortcut {
    private static let storageKey = "com.meow.superCloseShortcut"

    static func load() -> SuperCloseShortcut {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return .empty }
        return (try? JSONDecoder().decode(SuperCloseShortcut.self, from: data)) ?? .empty
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        NotificationCenter.default.post(name: .superCloseShortcutDidChange, object: nil)
    }
}
