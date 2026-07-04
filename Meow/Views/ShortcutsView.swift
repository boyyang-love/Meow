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
    @State private var deleteConfirmationItem: ShortcutItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        .onChange(of: editingID) { _, newValue in
            if newValue == nil {
                // 编辑结束 → 确保 @Bindable 变更已写入存储
                try? modelContext.save()
                notifyShortcutsChanged()
            }
        }

        }
        .alert("确认删除", isPresented: .init(
            get: { deleteConfirmationItem != nil },
            set: { if !$0 { deleteConfirmationItem = nil } }
        )) {
            Button("取消", role: .cancel) { deleteConfirmationItem = nil }
            Button("删除", role: .destructive) {
                if let item = deleteConfirmationItem {
                    deleteItem(item)
                }
                deleteConfirmationItem = nil
            }
        } message: {
            if let item = deleteConfirmationItem {
                Text("确定要删除「\(item.appName)」的快捷键配置吗？")
            }
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack {
            Text("快捷键")
                .font(.title)
                .fontWeight(.semibold)

            Spacer()

            Button(action: pickAppAndAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
            .help("添加应用程序快捷键")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var content: some View {
        if shortcuts.isEmpty {
            Spacer()
            ContentUnavailableView(
                "暂无快捷键",
                systemImage: "keyboard",
                description: Text("点击右上角 + 添加应用程序快捷键")
            )
            Spacer()
        } else {
            List {
                ForEach(shortcuts) { item in
                    ShortcutRow(
                        item: item,
                        isEditing: editingID == item.id,
                        onStartEdit: { editingID = item.id },
                        onEndEdit: { editingID = nil },
                        onDelete: { deleteConfirmationItem = item }
                    )
                    .contextMenu {
                        Button("配置快捷键") { editingID = item.id }
                        Button("启动应用") { launchApp(item) }
                        Divider()
                        Button("删除", role: .destructive) { deleteConfirmationItem = item }
                    }
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
                }
                .onDelete(perform: deleteItems)
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
        for index in offsets {
            deleteItem(shortcuts[index])
        }
    }

    private func deleteItem(_ item: ShortcutItem) {
        if editingID == item.id { editingID = nil }
        modelContext.delete(item)
        notifyShortcutsChanged()
    }

    /// 启动应用
    private func launchApp(_ item: ShortcutItem) {
        let url = URL(fileURLWithPath: item.appPath)
        NSWorkspace.shared.open(url)
    }

    /// 通知全局监听重载
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
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.appPath))
                .resizable()
                .frame(width: 32, height: 32)

            // 应用名
            Text(item.appName)
                .font(.body)
                .lineLimit(1)

            Spacer()

            // 快捷键显示 / 录制器
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

            // 编辑按钮
            Button {
                if isEditing { onEndEdit() } else { onStartEdit() }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                    .font(.title3)
                    .foregroundStyle(isEditing ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isEditing ? "完成编辑" : "配置快捷键")

            // 删除按钮（始终可见）
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.borderless)
            .help("删除此快捷键")
            .opacity(isEditing ? 0.3 : 1)
            .disabled(isEditing)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditing else { return }
            let url = URL(fileURLWithPath: item.appPath)
            NSWorkspace.shared.open(url)
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
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

// MARK: - 将 ShortcutItem 修饰符转为 EventModifiers

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
