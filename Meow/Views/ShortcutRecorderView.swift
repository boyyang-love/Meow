//
//  ShortcutRecorderView.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import SwiftUI

/// 快捷键录制器
/// 点击后进入录制模式，捕获下一次按键组合
struct ShortcutRecorderView: View {
    @Binding var keyEquivalent: String
    @Binding var modifierCommand: Bool
    @Binding var modifierShift: Bool
    @Binding var modifierOption: Bool
    @Binding var modifierControl: Bool
    
    @State private var isRecording = false
    @FocusState private var isFocused
    
    var body: some View {
        Text(isRecording ? "按下快捷键…" : displayText)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(isRecording ? .secondary : .primary)
            .frame(minWidth: 100, alignment: .center)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .onTapGesture {
                isRecording = true
                isFocused = true
            }
            .focusable()
            .focused($isFocused)
            .onKeyPress(phases: [.down]) { press in
                guard isRecording else { return .ignored }
                return handleKeyPress(press)
            }
    }
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let char = press.key.character
        
        // Escape → 取消录制
        if char == "\u{001B}" {
            isRecording = false
            return .handled
        }
        
        // 无效字符（纯修饰键事件）
        guard char != "\u{FFFF}" else { return .ignored }
        // 必须至少有一个修饰键
        guard press.modifiers.contains(.command) ||
                press.modifiers.contains(.shift)   ||
                press.modifiers.contains(.option)  ||
                press.modifiers.contains(.control) else { return .ignored }
        
        keyEquivalent = String(char).lowercased()
        modifierCommand  = press.modifiers.contains(.command)
        modifierShift    = press.modifiers.contains(.shift)
        modifierOption   = press.modifiers.contains(.option)
        modifierControl  = press.modifiers.contains(.control)
        
        isRecording = false
        isFocused = false
        return .handled
    }
    
    private var displayText: String {
        guard !keyEquivalent.isEmpty else { return "点击录制" }
        var parts = ""
        if modifierControl { parts += "⌃" }
        if modifierOption  { parts += "⌥" }
        if modifierShift   { parts += "⇧" }
        if modifierCommand { parts += "⌘" }
        parts += keyEquivalent.uppercased()
        return parts
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var key = "a"
    @Previewable @State var cmd = true
    @Previewable @State var shift = true
    @Previewable @State var opt = false
    @Previewable @State var ctrl = false
    
    ShortcutRecorderView(
        keyEquivalent: $key,
        modifierCommand: $cmd,
        modifierShift: $shift,
        modifierOption: $opt,
        modifierControl: $ctrl
    )
    .padding()
}
