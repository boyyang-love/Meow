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
    @Environment(\.scenePhase) private var scenePhase
    @State private var axTrusted = PermissionGate.isAccessibilityTrusted
    @State private var appControlStatus: AppControlPermissionStatus = .notDetermined
    @State private var isProbingAppControl = false
    
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

                permissionSection
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
        .onAppear { refreshPermissions() }
        .onChange(of: scenePhase) { _, _ in refreshPermissions() }
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
    
    // MARK: - 权限状态

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                Text("权限状态")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(spacing: 0) {
                accessibilityPermissionRow

                Divider()
                    .padding(.leading, 56)

                appControlPermissionRow
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityPermissionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "accessibility")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("辅助功能")
                    .font(.body)
                Text("全局快捷键监听所需")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            permissionBadge(ok: axTrusted, text: axTrusted ? "已授权" : "未授权")

            Button("打开系统设置") { PermissionGate.openAccessibilitySettings() }
                .controlSize(.small)
        }
        .padding(16)
    }

    private var appControlPermissionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("控制其他 App")
                    .font(.body)
                Text("优雅退出其它应用所需，未授权时仍可强制关闭")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isProbingAppControl {
                ProgressView()
                    .controlSize(.small)
            } else {
                switch appControlStatus {
                case .granted:
                    permissionBadge(ok: true, text: "已授权")
                case .notDetermined:
                    permissionBadge(ok: false, text: "未询问")
                        .help("从未询问过授权，点击「请求授权」可弹出系统授权框")
                case .denied:
                    permissionBadge(ok: false, text: "未授权")
                        .help("已拒绝或仅授权了部分 App，请到系统设置重新添加")
                }
            }

            Button("请求授权") {
                Task {
                    isProbingAppControl = true
                    appControlStatus = await PermissionGate.requestAppControl()
                    isProbingAppControl = false
                }
            }
            .controlSize(.small)

            Button("打开系统设置") { PermissionGate.openAppControlSettings() }
                .controlSize(.small)
        }
        .padding(16)
    }

    private func permissionBadge(ok: Bool, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.callout)
                .foregroundStyle(ok ? Color.green : Color.orange)
        }
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
    
    // MARK: - 刷新权限状态

    private func refreshPermissions() {
        axTrusted = PermissionGate.isAccessibilityTrusted
        isProbingAppControl = true
        Task {
            appControlStatus = await PermissionGate.probeAppControl()
            isProbingAppControl = false
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
