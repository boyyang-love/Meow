//
//  MenuBarController.swift
//  Meow
//
//  菜单栏图标控制器：NSStatusItem + 无边框 NSPanel。
//  相比 NSPopover：面板设置 .canJoinAllSpaces + .fullScreenAuxiliary，
//  在其它 App 的全屏 Space 点击图标时也能正常显示在当前页面。
//

import AppKit
import SwiftData
import SwiftUI

/// 菜单栏图标与弹出面板控制器
@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {

    static let shared = MenuBarController()

    private var panel: NSPanel?
    private var statusItem: NSStatusItem?

    /// 上次关闭时间：抑制 transient 自动关闭后按钮 action 立即重开导致的闪烁
    private var lastCloseTime = Date.distantPast

    /// 全局/本地事件监听：点击面板外自动关闭
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private override init() {
        super.init()
        setupStatusItem()
    }

    // MARK: - 设置

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Meow")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Meow"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        statusItem = item
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 449),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // 关键：跟随当前 Space，并允许显示在全屏页面之上
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    /// 箭头相对面板左边缘的偏移：每次弹出前按图标实际位置更新
    private var arrowOffset: CGFloat = 150

    // MARK: - 显示 / 关闭

    @objc private func togglePopover(_ sender: Any?) {
        if isPanelShown {
            closePanel()
        } else if Date().timeIntervalSince(lastCloseTime) > 0.15 {
            showPanel()
        }
    }

    private var isPanelShown: Bool {
        guard let panel else { return false }
        return panel.isVisible && panel.parent == nil
    }

    private func showPanel() {
        guard let button = statusItem?.button, let window = button.window else { return }

        let panel = self.panel ?? makePanel()
        self.panel = panel

        // 面板定位：图标正下方居中，顶部贴在菜单栏下沿
        let iconFrameInScreen = window.convertToScreen(button.frame)
        let screenFullHeight = window.screen?.frame.maxY ?? NSScreen.main?.frame.maxY ?? 0
        // 菜单栏高度 = 屏幕总高 - 可视区高（可视区已排除菜单栏）
        let menuBarHeight = screenFullHeight
            - (window.screen?.visibleFrame.maxY ?? NSScreen.main?.visibleFrame.maxY ?? 0)
        let size = panel.frame.size
        let x = iconFrameInScreen.midX - size.width / 2
        // 边界保护：不让面板超出屏幕左右边缘
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let clampedX = min(max(x, screenFrame.minX + 8), screenFrame.maxX - size.width - 8)

        // 箭头对准图标中心：偏移 = 图标中心x - 面板左边缘x（面板未移动时即 clampedX）
        arrowOffset = iconFrameInScreen.midX - clampedX
        // 每次弹出用最新箭头位置重建 contentView（SwiftUI 视图不会自动感知变量变化）
        panel.contentView = NSHostingView(
            rootView: PanelContainer(arrowOffset: arrowOffset)
        )

        let origin = NSPoint(x: clampedX, y: screenFullHeight - menuBarHeight - size.height - 2)

        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        statusItem?.button?.isHighlighted = true
        installDismissMonitors()
    }

    private func closePanel() {
        removeDismissMonitors()
        lastCloseTime = Date()
        panel?.orderOut(nil)
        statusItem?.button?.isHighlighted = false
    }

    // MARK: - 点击外部关闭（替代 .transient 行为）

    private func installDismissMonitors() {
        removeDismissMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
        // 本地监听：点击本 App 其它窗口时也关闭；点在面板自身上则忽略
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let panel = self?.panel, !panel.isVisible || event.window !== panel {
                self?.closePanel()
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }
}

/// 面板容器：一体化「圆角卡片 + 凸起箭头」背景 + 实际内容
private struct PanelContainer: View {
    /// 箭头中心相对面板左边缘的偏移
    let arrowOffset: CGFloat

    var body: some View {
        PanelBubbleShape(arrowOffset: arrowOffset)
            .fill(.ultraThinMaterial)
            .frame(width: 340, height: 449)
            // 细描边：深色壁纸上边缘更清晰（系统弹窗同款细节）
            .overlay {
                PanelBubbleShape(arrowOffset: arrowOffset)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            }
            .overlay(alignment: .bottom) {
                MenuBarPanelView()
                    .modelContainer(_sharedModelContainer)
                    .frame(width: 340, height: 440)
            }
    }
}

/// 带顶部凸起箭头的一体化圆角矩形（气泡形状）
private struct PanelBubbleShape: Shape {
    /// 箭头中心相对形状左边缘的偏移
    let arrowOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 14
        let arrowWidth: CGFloat = 22
        let arrowHeight: CGFloat = 9
        // 箭头中心 x（限制在顶部圆角以内，避免和圆角重叠）
        let cx = min(max(arrowOffset, radius + arrowWidth / 2), rect.maxX - radius - arrowWidth / 2)
        let left = cx - arrowWidth / 2
        let right = cx + arrowWidth / 2
        // 气泡主体矩形：rect 顶部向下让出箭头高度
        let bodyTop = rect.minY + arrowHeight

        var p = Path()
        // 左上圆角
        p.move(to: CGPoint(x: rect.minX, y: bodyTop + radius))
        p.addArc(
            center: CGPoint(x: rect.minX + radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        // 顶边 → 箭头左根
        p.addLine(to: CGPoint(x: left, y: bodyTop))
        // 凸起箭头（带小圆角根部更柔和）
        p.addLine(to: CGPoint(x: cx, y: rect.minY))
        p.addLine(to: CGPoint(x: right, y: bodyTop))
        // 顶边 → 右上圆角
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: bodyTop))
        p.addArc(
            center: CGPoint(x: rect.maxX - radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false
        )
        // 右边、右下圆角、底边、左下圆角、左边闭合
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        p.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        p.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        p.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        p.closeSubpath()
        return p
    }

}
