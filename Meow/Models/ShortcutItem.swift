//
//  ShortcutItem.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import Foundation
import SwiftData

@Model
final class ShortcutItem {
    var appName: String
    var appPath: String
    var bundleIdentifier: String
    var keyEquivalent: String
    var modifierCommand: Bool
    var modifierShift: Bool
    var modifierOption: Bool
    var modifierControl: Bool

    init(
        appName: String,
        appPath: String,
        bundleIdentifier: String = "",
        keyEquivalent: String = "",
        modifierCommand: Bool = false,
        modifierShift: Bool = false,
        modifierOption: Bool = false,
        modifierControl: Bool = false
    ) {
        self.appName = appName
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
        self.keyEquivalent = keyEquivalent
        self.modifierCommand = modifierCommand
        self.modifierShift = modifierShift
        self.modifierOption = modifierOption
        self.modifierControl = modifierControl
    }

    /// 格式化显示快捷键文本，如 "⌘⇧A"
    var displayText: String {
        guard !keyEquivalent.isEmpty else { return "" }
        var parts = ""
        if modifierControl { parts += "⌃" }
        if modifierOption  { parts += "⌥" }
        if modifierShift   { parts += "⇧" }
        if modifierCommand { parts += "⌘" }
        parts += keyEquivalent.uppercased()
        return parts
    }
}
