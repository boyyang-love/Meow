//
//  PortsView.swift
//  Meow
//
//  端口诊断：查看本机端口占用情况，并支持一键终止占用端口的进程。
//

import Combine
import SwiftUI

struct PortsView: View {

    // MARK: - State

    @State private var entries: [PortEntry] = []
    @State private var groups: [PortGroup] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var autoRefresh = true
    @State private var lastRefresh = Date.distantPast
    /// 折叠中的分组 ID
    @State private var collapsedGroupIDs: Set<String> = []
    @State private var hoveredEntryID: String?

    @State private var pendingKill: PortEntry?
    @State private var showKillConfirm = false
    @State private var errorMessage: String?
    @State private var showError = false

    /// 自动刷新定时器（每 5 秒监听端口变化）
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        Group {
            if entries.isEmpty && !isLoading {
                ContentUnavailableView(
                    "暂无监听端口",
                    systemImage: "network",
                    description: Text("当前没有进程在监听端口，点击右上角刷新重试")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .searchable(text: $searchText, prompt: "搜索端口 / 进程 / PID / 地址")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Toggle(isOn: $autoRefresh) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .help("自动刷新（每 5 秒）")
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .help("立即刷新")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { statusBar }
        .task { await refresh() }
        .onReceive(refreshTimer) { _ in
            guard autoRefresh, !isLoading else { return }
            Task { await refresh() }
        }
        .alert("结束进程", isPresented: $showKillConfirm, presenting: pendingKill) { entry in
            Button("结束进程", role: .destructive) {
                Task { await performKill(entry) }
            }
            Button("取消", role: .cancel) {}
        } message: { entry in
            Text("确定要结束「\(entry.processName)」(PID \(String(entry.pid))) 吗？\n该进程正在监听端口 \(String(entry.port))（\(entry.proto)），结束后相关服务将停止。")
        }
        .alert("操作失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 内容

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                statsBar

                ForEach(filteredGroups) { group in
                    PortGroupCard(
                        group: group,
                        isCollapsed: !searchText.isEmpty ? false : collapsedGroupIDs.contains(group.id),
                        hoveredEntryID: hoveredEntryID,
                        searchText: searchText,
                        onToggleCollapse: { toggleCollapse(group.id) },
                        onEntryHover: { id in hoveredEntryID = id },
                        onKill: { entry in
                            pendingKill = entry
                            showKillConfirm = true
                        }
                    )
                }
            }
            .padding(12)
        }
        .overlay {
            if filteredGroups.isEmpty && !groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if isLoading && entries.isEmpty {
                ProgressView("正在扫描端口…")
            }
        }
    }

    // MARK: - 统计条

    private var statsBar: some View {
        HStack(spacing: 8) {
            statChip(systemImage: "network", value: totalPortCount, label: "端口")
            statChip(systemImage: "app.badge", value: filteredGroups.count, label: "应用")
            Divider()
                .frame(height: 16)
            statChip(systemImage: "circle.fill", value: tcpCount, label: "TCP", dot: .blue)
            statChip(systemImage: "circle.fill", value: udpCount, label: "UDP", dot: .orange)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func statChip(systemImage: String, value: Int, label: String, dot: Color? = nil) -> some View {
        HStack(spacing: 5) {
            if let dot {
                Circle()
                    .fill(dot)
                    .frame(width: 7, height: 7)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(String(value))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
    }

    // MARK: - 统计计算

    private var filteredGroups: [PortGroup] {
        guard !searchText.isEmpty else { return groups }
        let keyword = searchText.lowercased()
        return groups.compactMap { group in
            let matched = group.ports.filter { $0.searchText.lowercased().contains(keyword) }
            guard !matched.isEmpty else { return nil }
            return PortGroup(
                id: group.id,
                appName: group.appName,
                icon: group.icon,
                processPath: group.processPath,
                pids: group.pids,
                ports: matched
            )
        }
    }

    private var totalPortCount: Int {
        filteredGroups.reduce(0) { $0 + $1.ports.count }
    }

    private var tcpCount: Int {
        filteredGroups.reduce(0) { $0 + $1.ports.filter { $0.proto == "TCP" }.count }
    }

    private var udpCount: Int {
        filteredGroups.reduce(0) { $0 + $1.ports.filter { $0.proto == "UDP" }.count }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Text("\(String(totalPortCount)) 个端口 · \(String(filteredGroups.count)) 个应用")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !searchText.isEmpty {
                Text("（过滤自 \(String(entries.count)) 个端口）")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if lastRefresh != .distantPast {
                Text("更新于 \(lastRefresh.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - 动作

    private func toggleCollapse(_ id: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if collapsedGroupIDs.contains(id) {
                collapsedGroupIDs.remove(id)
            } else {
                collapsedGroupIDs.insert(id)
            }
        }
    }

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            entries = try await PortService.fetchListeningPorts()
            groups = PortService.groupPorts(entries)
            lastRefresh = Date()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performKill(_ entry: PortEntry) async {
        do {
            try PortService.killProcess(pid: entry.pid)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        // 无论成功与否都刷新一次
        await refresh()
    }
}

// MARK: - 分组卡片

private struct PortGroupCard: View {
    let group: PortGroup
    let isCollapsed: Bool
    let hoveredEntryID: String?
    let searchText: String
    let onToggleCollapse: () -> Void
    let onEntryHover: (String?) -> Void
    let onKill: (PortEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !isCollapsed {
                Divider()
                    .padding(.horizontal, 12)
                    .opacity(0.6)

                ForEach(group.ports) { entry in
                    PortRow(
                        entry: entry,
                        showPID: group.pids.count > 1,
                        isHovered: hoveredEntryID == entry.id,
                        searchText: searchText,
                        onHover: onEntryHover,
                        onKill: { onKill(entry) }
                    )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: 卡片头

    private var header: some View {
        Button(action: onToggleCollapse) {
            HStack(spacing: 10) {
                Group {
                    if let icon = group.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(highlightedText(group.appName, keyword: searchText))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("PID " + group.pids.map(String.init).joined(separator: ", "))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .help(group.processPath ?? "")
                }

                Spacer(minLength: 8)

                Text("\(String(group.portCount)) 个端口")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 端口行

private struct PortRow: View {
    let entry: PortEntry
    /// 组内存在多个 PID 时显示行级 PID，便于区分结束目标
    let showPID: Bool
    let isHovered: Bool
    let searchText: String
    let onHover: (String?) -> Void
    let onKill: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 端口号
            Text(highlightedText("\(entry.port)", keyword: searchText))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .frame(width: 56, alignment: .trailing)

            // 协议徽章
            Text(entry.proto)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(entry.proto == "TCP" ? Color.blue : Color.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill((entry.proto == "TCP" ? Color.blue : Color.orange).opacity(0.13))
                )

            // 监听地址
            Text(highlightedText(
                entry.addresses.map { "\($0):\(entry.port)" }.joined(separator: "  "),
                keyword: searchText
            ))
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(entry.addresses.map { "\($0):\(entry.port)" }.joined(separator: "\n"))

            Spacer(minLength: 12)

            if showPID {
                Text("PID \(String(entry.pid))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // 结束进程（悬停变红）
            Button(role: .destructive, action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(isHovered ? Color.red : Color.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("结束进程")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering ? entry.id : nil)
        }
    }
}

// MARK: - 搜索高亮

/// 将文本中命中关键词的部分以 accent 色高亮
private func highlightedText(_ text: String, keyword: String) -> AttributedString {
    var attr = AttributedString(text)
    guard !keyword.isEmpty else { return attr }

    var start = text.startIndex
    while let range = text.range(of: keyword, options: .caseInsensitive, range: start..<text.endIndex) {
        if let lower = AttributedString.Index(range.lowerBound, within: attr),
           let upper = AttributedString.Index(range.upperBound, within: attr) {
            attr[lower..<upper].foregroundColor = .accentColor
        }
        start = range.upperBound
    }
    return attr
}

// MARK: - Preview

#Preview {
    PortsView()
}
