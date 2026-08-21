//
//  MenuBarController.swift
//  Meow
//
//  菜单栏图标控制器：NSStatusItem + NSPopover。
//  相比 MenuBarExtra(.window)：
//  - 面板自动居中对齐在图标正下方（箭头对准图标中心）
//  - 自带指向图标的原生箭头效果
//

import AppKit
import SwiftData
import SwiftUI

/// 菜单栏图标与弹出面板控制器
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {

    static let shared = MenuBarController()

    private let popover = NSPopover()
    private var statusItem: NSStatusItem?

    /// 上次关闭时间：抑制 transient 自动关闭后按钮 action 立即重开导致的闪烁
    private var lastCloseTime = Date.distantPast

    private override init() {
        super.init()
        setupStatusItem()
        setupPopover()
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

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPanelView().modelContainer(_sharedModelContainer)
        )
        popover.delegate = self
    }

    // MARK: - 显示 / 关闭

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else if Date().timeIntervalSince(lastCloseTime) > 0.15 {
            showPopover(from: button)
        }
    }

    private func showPopover(from button: NSStatusBarButton) {
        NSApp.activate(ignoringOtherApps: true)
        button.isHighlighted = true
        // preferredEdge: .minY → 面板出现在图标下方，箭头朝上指向图标
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        lastCloseTime = Date()
        statusItem?.button?.isHighlighted = false
    }
}
