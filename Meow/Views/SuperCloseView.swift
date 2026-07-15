//
//  SuperCloseView.swift
//  Meow
//
//  Created by boyyang on 2026/7/15.
//

import SwiftUI

/// 超级关闭配置视图
struct SuperCloseView: View {
    @State private var shortcut = SuperCloseShortcut.load()
    @State private var isEnabled = SuperCloseShortcut.load().isEnabled
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                
                Divider()
                    .padding(.horizontal, 20)
                
                settingsGroup
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                
                Divider()
                    .padding(.horizontal, 20)
                
                infoSection
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
        .scrollIndicators(.never)
    }
    
    // MARK: - 头部
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.red.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("超级关闭")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("一键关闭 Dock 栏所有正在运行的程序")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
    }
    
    // MARK: - 设置组
    
    private var settingsGroup: some View {
        VStack(spacing: 0) {
            toggleRow
            
            if isEnabled {
                Divider()
                    .padding(.leading, 56)
                
                shortcutRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
    
    private var toggleRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "switch.programmable")
                .font(.title3)
                .foregroundStyle(.tint)
                .opacity(isEnabled ? 1 : 0.5)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("启用超级关闭")
                    .font(.body)
                Text("开启后，按下快捷键将关闭所有 Dock 应用程序")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .onChange(of: isEnabled) { _, newValue in
                    saveShortcut(isEnabled: newValue)
                }
        }
        .padding(16)
    }
    
    private var shortcutRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)
            
            Text("快捷键")
                .font(.body)
            
            Spacer()
            
            HStack(spacing: 8) {
                ShortcutRecorderView(
                    keyEquivalent: $shortcut.keyEquivalent,
                    modifierCommand: $shortcut.modifierCommand,
                    modifierShift: $shortcut.modifierShift,
                    modifierOption: $shortcut.modifierOption,
                    modifierControl: $shortcut.modifierControl
                )
                .onChange(of: shortcut.keyEquivalent) { _, _ in saveShortcut() }
                .onChange(of: shortcut.modifierCommand) { _, _ in saveShortcut() }
                .onChange(of: shortcut.modifierShift) { _, _ in saveShortcut() }
                .onChange(of: shortcut.modifierOption) { _, _ in saveShortcut() }
                .onChange(of: shortcut.modifierControl) { _, _ in saveShortcut() }
                
                if !shortcut.keyEquivalent.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            shortcut.keyEquivalent = ""
                            shortcut.modifierCommand = false
                            shortcut.modifierShift = false
                            shortcut.modifierOption = false
                            shortcut.modifierControl = false
                            saveShortcut()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.borderless)
                    .help("清除快捷键")
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - 说明区
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                Text("使用说明")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "app.badge", text: "关闭所有 Dock 栏中的应用程序（Finder 除外）")
                infoRow(icon: "lock.shield", text: "Meow 自身不会被关闭")
                infoRow(icon: "bell.badge", text: "关闭完成后会显示系统通知")
            }
            .padding(.leading, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.tint)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - 保存
    
    private func saveShortcut(isEnabled: Bool? = nil) {
        if let isEnabled {
            shortcut.isEnabled = isEnabled
        }
        shortcut.save()
    }
}

// MARK: - Preview

#Preview {
    SuperCloseView()
        .frame(width: 500, height: 400)
}
