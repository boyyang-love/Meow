//
//  MenuBarPanelView.swift
//  Meow
//
//  菜单栏弹出面板：点击图标弹出，顶部 Tab 切换快捷键列表与端口诊断。
//

import Combine
import SwiftData
import SwiftUI

struct MenuBarPanelView: View {

    // MARK: - Tab

    enum PanelTab: String, CaseIterable, Identifiable {
        case shortcuts = "快捷键"
        case ports = "端口诊断"
        case superClose = "超级关闭"
        case pets = "宠物"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .shortcuts: return "keyboard"
            case .ports: return "network"
            case .superClose: return "xmark.circle"
            case .pets: return "pawprint"
            }
        }
    }

    // MARK: - State

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShortcutItem.appName) private var shortcuts: [ShortcutItem]
    @Query(sort: \PetItem.createdAt, order: .forward) private var pets: [PetItem]

    @State private var selectedTab: PanelTab = .shortcuts
    @State private var isMonitoringEnabled = GlobalShortcutMonitor.shared.isMonitoringEnabled
    @State private var superClose = SuperCloseShortcut.load()
    @State private var groups: [PortGroup] = []
    @State private var isLoadingPorts = false

    /// 端口自动刷新定时器（每 5 秒）
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 4) {
                ForEach(PanelTab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.15), value: selectedTab)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
        }
        .frame(width: 340, height: 440)
        .task(id: selectedTab) {
            if selectedTab == .ports { await refreshPorts() }
        }
        .onReceive(refreshTimer) { _ in
            guard selectedTab == .ports, !isLoadingPorts else { return }
            Task { await refreshPorts() }
        }
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private func tabButton(for tab: PanelTab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // Home 图标：点击显示主窗口
            Button {
                AppDelegate.shared?.showMainWindow()
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .help("显示主窗口")

            Spacer()

            // 全局快捷键监听状态（点击文字切换）
            Button {
                if GlobalShortcutMonitor.shared.isMonitoringEnabled {
                    GlobalShortcutMonitor.shared.pause()
                } else {
                    GlobalShortcutMonitor.shared.resume()
                }
                isMonitoringEnabled = GlobalShortcutMonitor.shared.isMonitoringEnabled
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isMonitoringEnabled ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(isMonitoringEnabled ? "监听中" : "已暂停")
                        .font(.system(size: 10))
                        .foregroundStyle(isMonitoringEnabled ? .secondary : .tertiary)
                }
            }
            .buttonStyle(.plain)
            .help("点击切换全局快捷键监听")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .shortcuts:
            shortcutContent
        case .ports:
            portContent
        case .superClose:
            superCloseContent
        case .pets:
            petContent
        }
    }

    // 快捷键列表（点击行启动应用）
    private var shortcutContent: some View {
        Group {
            if shortcuts.isEmpty {
                ContentUnavailableView(
                    "暂无快捷键",
                    systemImage: "keyboard",
                    description: Text("前往主窗口添加应用快捷键")
                )
            } else {
                List(shortcuts) { item in
                    HStack(spacing: 8) {
                        // 应用图标
                        Group {
                            if let icon = appIcon(for: item) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "app.dashed")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.appName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            if !item.appPath.isEmpty {
                                Text(item.appPath)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Spacer()
                        if !item.displayText.isEmpty {
                            Text(item.displayText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        launch(item)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // 端口诊断（紧凑分组卡片）
    private var portContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if isLoadingPorts && groups.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("正在扫描端口…")
                        Spacer()
                    }
                    .padding(.top, 40)
                }

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        // 组头
                        HStack(spacing: 6) {
                            if let icon = group.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            Text(group.appName)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Text(String(group.ports.count))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.primary.opacity(0.06)))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)

                        // 端口行
                        ForEach(group.ports) { entry in
                            HStack(spacing: 8) {
                                Text(String(entry.port))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .frame(width: 52, alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(entry.proto)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(entry.proto == "TCP" ? Color.blue : Color.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule().fill((entry.proto == "TCP" ? Color.blue : Color.orange).opacity(0.13))
                                    )
                                Text(entry.addresses.map { "\($0):\(entry.port)" }.joined(separator: "  "))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .minimumScaleFactor(0.75)
                                Spacer(minLength: 4)
                                Button(role: .destructive) {
                                    confirmKill(entry)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help("结束进程")
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .padding(10)
        }
    }

    // MARK: - 超级关闭

    private var superCloseContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 开关行：点击整行切换（无 Switch，状态用文字显示）
                Button {
                    superClose.isEnabled.toggle()
                    superClose.save()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("启用超级关闭")
                                .font(.system(size: 12, weight: .medium))
                            Text("按下快捷键关闭所有 Dock 应用")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(superClose.isEnabled ? "已启用" : "已关闭")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(superClose.isEnabled ? Color.green : Color.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if superClose.isEnabled {
                    Divider()
                        .padding(.leading, 12)

                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12))
                            .foregroundStyle(.tint)
                            .frame(width: 20)
                        Text("快捷键")
                            .font(.system(size: 12))
                        Spacer()
                        Text(superClose.displayText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tint)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                Divider()

                // 立即执行
                Button {
                    GlobalShortcutMonitor.shared.superCloseAllApps()
                } label: {
                    Label("立即关闭所有应用", systemImage: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .help("关闭所有 Dock 应用程序（Finder 除外）")
                .padding(.top, 10)

                // 说明
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tint)
                    Text("Meow 与 Finder 不会被关闭，完成后有系统通知")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            .animation(.easeInOut(duration: 0.2), value: superClose.isEnabled)
            .padding(10)
        }
    }

    // MARK: - 宠物

    private var petContent: some View {
        Group {
            if pets.isEmpty {
                ContentUnavailableView(
                    "暂无宠物",
                    systemImage: "pawprint",
                    description: Text("前往主窗口添加宠物")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // 顶部：当前启用宠物的预览 + 缩放按钮
                        if let activePet = pets.first(where: { $0.isActive }) {
                            activePetPreviewSection(for: activePet)
                        }

                        ForEach(pets) { pet in
                            PetCardView(pet: pet, onToggle: togglePet)
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    /// 当前启用宠物的预览区：固定大小预览（无背景）+ 下方缩放按钮
    private func activePetPreviewSection(for pet: PetItem) -> some View {
        let scale = pet.scale ?? 1.0
        return VStack(spacing: 10) {
            // 动画预览（固定大小，不随缩放变化）
            LottieView(filename: pet.effectiveLottieFileName)
                .frame(width: 120, height: 120)

            // 缩放按钮（预览下方居中）
            HStack(spacing: 20) {
                Button {
                    changePetScale(pet, step: -1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("缩小")
                .disabled(scale <= 0.5)

                Text("\(Int(round(scale * 100)))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    changePetScale(pet, step: 1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("放大")
                .disabled(scale >= 2.0)
            }
            .foregroundStyle(.tint)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                AppDelegate.shared?.hideToMenuBar()
            } label: {
                Label("隐藏窗口", systemImage: "eye.slash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("隐藏到菜单栏")

            Spacer()

            Button(role: .destructive) {
                AppDelegate.shouldTerminate = true
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 动作

    /// 结束进程确认（用 NSAlert：SwiftUI .alert 在 MenuBarExtra 面板中不显示）
    private func confirmKill(_ entry: PortEntry) {
        let alert = NSAlert()
        alert.messageText = "结束进程"
        alert.informativeText = "确定要结束「\(entry.processName)」(PID \(String(entry.pid))) 吗？\n该进程正在监听端口 \(String(entry.port))（\(entry.proto)）。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "结束进程")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            Task { await performKill(entry) }
        }
    }

    /// 显示错误提示（NSAlert）
    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "操作失败"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    /// 获取快捷键对应的应用图标（基于 .app 路径）
    private func appIcon(for item: ShortcutItem) -> NSImage? {
        guard !item.appPath.isEmpty else { return nil }
        return NSWorkspace.shared.icon(forFile: item.appPath)
    }

    private func launch(_ item: ShortcutItem) {
        let url = URL(fileURLWithPath: item.appPath)
        NSWorkspace.shared.open(url)
    }

    /// 切换宠物活跃状态（与主窗口逻辑一致）
    private func togglePet(_ pet: PetItem) {
        if pet.isActive {
            pet.isActive = false
            ActivePetManager.shared.hidePet()
        } else {
            for p in pets where p.isActive {
                p.isActive = false
            }
            pet.isActive = true
            ActivePetManager.shared.showPet(pet)
        }
        try? modelContext.save()
    }

    /// 调整宠物缩放（步进 ±1 十分位，范围 0.5 ~ 2.0，与主窗口一致）
    private func changePetScale(_ pet: PetItem, step: Int) {
        let tenths = max(5, min(20, Int(round((pet.scale ?? 1.0) * 10)) + step))
        let newScale = Double(tenths) / 10.0
        pet.scale = newScale
        try? modelContext.save()
        // 同步桌面浮动窗口（仅当此宠物正显示在桌面）
        if pet.isActive {
            ActivePetManager.shared.updateScale(newScale)
        }
    }

    private func refreshPorts() async {
        guard !isLoadingPorts else { return }
        isLoadingPorts = true
        defer { isLoadingPorts = false }

        do {
            let entries = try await PortService.fetchListeningPorts()
            groups = PortService.groupPorts(entries)
        } catch {
            showErrorAlert(error.localizedDescription)
        }
    }

    private func performKill(_ entry: PortEntry) async {
        do {
            try PortService.killProcess(pid: entry.pid)
        } catch {
            showErrorAlert(error.localizedDescription)
        }
        // 无论成功与否都刷新一次
        await refreshPorts()
    }
}

// MARK: - 宠物卡片（菜单栏弹框用）

/// 宠物卡片：固定小预览 + 名字 + 状态标记（缩放控制在上方预览区）
private struct PetCardView: View {
    let pet: PetItem
    let onToggle: (PetItem) -> Void

    private var isActive: Bool { pet.isActive }

    var body: some View {
        HStack(spacing: 12) {
            // 动画预览（固定大小）
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quinary)
                LottieView(filename: pet.effectiveLottieFileName)
                    .frame(width: 56, height: 56)
            }
            .frame(width: 64, height: 64)

            // 名字 + 状态标记
            HStack(spacing: 6) {
                Text(pet.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                // 状态标记：常显（活跃绿 / 停用灰）
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 6, height: 6)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(pet)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarPanelView()
        .modelContainer(for: ShortcutItem.self, inMemory: true)
}
