//
//  ShortcutsView.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import UniformTypeIdentifiers
import SwiftUI
import SwiftData

// MARK: - 快捷键主页

struct ShortcutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShortcutItem.appName) private var shortcuts: [ShortcutItem]

    @State private var editingID: ShortcutItem.ID?
    @State private var showDupAlert = false
    @State private var dupAlertMessage = ""

    /// 编辑前备份原始值：[itemID: (key, cmd, shift, opt, ctrl)]
    @State private var editBackup: [ShortcutItem.ID: (String, Bool, Bool, Bool, Bool)] = [:]

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .addShortcut)) { _ in
                pickAppAndAdd()
            }
        .onChange(of: editingID) { old, new in
            if new != nil {
                // 编辑开始 → 暂停快捷键监听
                GlobalShortcutMonitor.shared.pause()
            } else if let id = old {
                // 编辑结束 → 恢复监听 + 检查重复
                GlobalShortcutMonitor.shared.resume()
                defer {
                    editBackup[id] = nil
                    try? modelContext.save()
                    notifyShortcutsChanged()
                }

                guard let item = shortcuts.first(where: { $0.id == id }),
                      let back = editBackup[id] else { return }

                // 检查快捷键是否与其他应用重复
                let dup = shortcuts.first { other in
                    other.id != id
                    && other.keyEquivalent == item.keyEquivalent
                    && other.modifierCommand == item.modifierCommand
                    && other.modifierShift == item.modifierShift
                    && other.modifierOption == item.modifierOption
                    && other.modifierControl == item.modifierControl
                }

                if let dup {
                    // 回退到编辑前的值
                    item.keyEquivalent  = back.0
                    item.modifierCommand = back.1
                    item.modifierShift   = back.2
                    item.modifierOption  = back.3
                    item.modifierControl = back.4

                    dupAlertMessage = "快捷键「\(item.displayText)」已被「\(dup.appName)」使用"
                    showDupAlert = true
                }
            }
        }
        .alert("快捷键冲突", isPresented: $showDupAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(dupAlertMessage)
        }

    }

    @ViewBuilder
    private var content: some View {
        if shortcuts.isEmpty {
            ContentUnavailableView(
                "暂无快捷键",
                systemImage: "keyboard",
                description: Text("点击右上角 + 添加应用程序快捷键")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(shortcuts) { item in
                    ShortcutRow(
                        item: item,
                        isEditing: editingID == item.id,
                        onStartEdit: {
                            editBackup[item.id] = (item.keyEquivalent, item.modifierCommand, item.modifierShift, item.modifierOption, item.modifierControl)
                            editingID = item.id
                        },
                        onEndEdit: { editingID = nil },
                        onLaunchApp: { launchApp(item) },
                        onDelete: { deleteItem(item) }
                    )

                    .background {
                        if !item.keyEquivalent.isEmpty {
                            Button("") { launchApp(item) }
                                .keyboardShortcut(
                                    KeyEquivalent(Character(item.keyEquivalent)),
                                    modifiers: item.swiftUIModifiers
                                )
                                .hidden()
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }

            }
            .listStyle(.plain)
        }
    }

    // MARK: - 选择应用

    private func pickAppAndAdd() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "选择要添加快捷键的应用程序"
        panel.prompt = "添加"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let appName = url.deletingPathExtension().lastPathComponent
        let bundle = Bundle(url: url)
        let bundleId = bundle?.bundleIdentifier ?? ""

        let item = ShortcutItem(
            appName: appName,
            appPath: url.path,
            bundleIdentifier: bundleId
        )
        modelContext.insert(item)
        try? modelContext.save()
        notifyShortcutsChanged()
        editingID = item.id  // 添加后自动进入编辑
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets { deleteItem(shortcuts[index]) }
    }

    private func deleteItem(_ item: ShortcutItem) {
        if editingID == item.id { editingID = nil }
        modelContext.delete(item)
        notifyShortcutsChanged()
    }

    private func launchApp(_ item: ShortcutItem) {
        let url = URL(fileURLWithPath: item.appPath)
        NSWorkspace.shared.open(url)
    }

    private func notifyShortcutsChanged() {
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
    }
}

// MARK: - 单行

private struct ShortcutRow: View {
    @Bindable var item: ShortcutItem
    let isEditing: Bool
    let onStartEdit: () -> Void
    let onEndEdit: () -> Void
    var onLaunchApp: (() -> Void)?
    let onDelete: () -> Void
    @State private var showDeletePopover = false

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.appPath))
                .resizable()
                .frame(width: 32, height: 32)

            Text(item.appName)
                .font(.body)
                .lineLimit(1)

            Spacer()

            if isEditing {
                ShortcutRecorderView(
                    keyEquivalent: $item.keyEquivalent,
                    modifierCommand: $item.modifierCommand,
                    modifierShift: $item.modifierShift,
                    modifierOption: $item.modifierOption,
                    modifierControl: $item.modifierControl
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if !item.displayText.isEmpty {
                shortcutLabel(item.displayText)
            } else {
                Text("未设置")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }

            Button {
                if isEditing { onEndEdit() } else { onStartEdit() }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                    .font(.title3)
                    .foregroundStyle(isEditing ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isEditing ? "完成编辑" : "配置快捷键")

            Button(role: .destructive) { showDeletePopover = true } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.borderless)
            .help("删除此快捷键")
            .opacity(isEditing ? 0.3 : 1)
            .disabled(isEditing)
            .popover(isPresented: $showDeletePopover) {
                VStack(spacing: 14) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)
                    Text("确认删除")
                        .font(.headline)
                    Text("确定要删除「\(item.appName)」的快捷键配置吗？")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    HStack(spacing: 12) {
                        Button("取消") {
                            showDeletePopover = false
                        }
                        .keyboardShortcut(.escape)
                        Button("删除", role: .destructive) {
                            onDelete()
                            showDeletePopover = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding()
                .frame(width: 230)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditing else { return }
            let url = URL(fileURLWithPath: item.appPath)
            NSWorkspace.shared.open(url)
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .contextMenu {
            Button("配置快捷键") {
                onStartEdit()
            }
            Button("启动应用") {
                onLaunchApp?()
            }
            Divider()
            Button("删除", role: .destructive) {
                showDeletePopover = true
            }
        }
    }

    private func shortcutLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.1))
            )
    }
}

// MARK: - ShortcutItem 扩展

extension ShortcutItem {
    fileprivate var swiftUIModifiers: SwiftUI.EventModifiers {
        var result = SwiftUI.EventModifiers()
        if modifierCommand  { result.insert(.command) }
        if modifierShift    { result.insert(.shift) }
        if modifierOption   { result.insert(.option) }
        if modifierControl  { result.insert(.control) }
        return result
    }
}

// MARK: - Preview

#Preview {
    ShortcutsView()
        .frame(width: 500, height: 400)
        .modelContainer(for: ShortcutItem.self, inMemory: true)
}
