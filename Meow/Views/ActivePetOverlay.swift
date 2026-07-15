//
//  ActivePetOverlay.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import SwiftUI
import AppKit
import SwiftData

/// 管理活跃宠物的浮动窗口
@MainActor
final class ActivePetManager {
    static let shared = ActivePetManager()
    
    private(set) var window: NSWindow?
    private var modelContext: ModelContext?
    private var currentPet: PetItem?
    
    private let defaultWidth: CGFloat = 150
    private let defaultHeight: CGFloat = 150
    
    /// 计算默认右下角位置
    private var defaultOrigin: CGPoint {
        guard let screen = NSScreen.main?.visibleFrame else { return .zero }
        return CGPoint(
            x: screen.maxX - defaultWidth - 20,
            y: screen.minY + 20
        )
    }
    
    func setup(with context: ModelContext) {
        self.modelContext = context
    }
    
    /// 显示指定宠物的浮动窗口
    func showPet(_ pet: PetItem) {
        currentPet = pet
        ensureWindow()
        
        let scale = pet.scale ?? 1.0
        let w = defaultWidth * scale
        let h = defaultHeight * scale
        
        let savedX = pet.positionX
        let savedY = pet.positionY
        let origin: CGPoint
        if let sx = savedX, let sy = savedY {
            origin = CGPoint(x: sx, y: sy)
        } else {
            origin = defaultOrigin
            // 保存默认位置
            pet.positionX = origin.x
            pet.positionY = origin.y
            try? modelContext?.save()
        }
        
        window?.setFrame(CGRect(origin: origin, size: CGSize(width: w, height: h)), display: true)
        window?.contentView = NSHostingView(rootView: makeContentView(for: pet))
        window?.orderFront(nil)
    }
    
    /// 将宠物浮窗置于前台（重新打开应用时调用）
    func bringWindowToFront() {
        guard let win = window, currentPet != nil else { return }
        win.orderFront(nil)
    }
    
    /// 隐藏浮动窗口
    func hidePet() {
        window?.orderOut(nil)
        currentPet = nil
    }
    
    /// 更新窗口位置（拖拽时调用）
    func updatePosition(_ origin: CGPoint) {
        window?.setFrameOrigin(origin)
    }
    
    /// 保存位置到模型（拖拽结束时调用）
    func savePosition(_ origin: CGPoint) {
        guard let pet = currentPet, let ctx = modelContext else { return }
        let scale = pet.scale ?? 1.0
        // 将窗口原点转换为宠物位置（宠物位置 = 窗口原点）
        pet.positionX = origin.x
        pet.positionY = origin.y
        // 更新窗口大小（考虑现有 scale）
        let w = defaultWidth * scale
        let h = defaultHeight * scale
        window?.setFrame(CGRect(origin: origin, size: CGSize(width: w, height: h)), display: true)
        try? ctx.save()
    }
    
    /// 调整缩放
    func updateScale(_ scale: Double) {
        guard let pet = currentPet else { return }
        pet.scale = scale
        if let origin = window?.frame.origin {
            window?.setFrame(CGRect(origin: origin, size: CGSize(width: defaultWidth * scale, height: defaultHeight * scale)), display: true)
        }
        // 防抖批量保存，避免每次缩放都触发 @Query 重新取值
        debouncedSave()
    }
    
    private var saveTask: Task<Void, Never>?
    
    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let ctx = modelContext else { return }
            try? ctx.save()
        }
    }
    
    // MARK: - Private
    
    private func ensureWindow() {
        if window == nil {
            let win = NSWindow(
                contentRect: CGRect(origin: defaultOrigin, size: CGSize(width: defaultWidth, height: defaultHeight)),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.level = .floating
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.ignoresMouseEvents = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.isMovableByWindowBackground = true
            window = win
        }
    }
    
    private func makeContentView(for pet: PetItem) -> some View {
        ActivePetOverlayView(pet: pet, manager: self)
    }
}

// MARK: - 浮动窗口内容视图

private struct ActivePetOverlayView: View {
    let pet: PetItem
    let manager: ActivePetManager
    
    @State private var scale: Double
    
    init(pet: PetItem, manager: ActivePetManager) {
        self.pet = pet
        self.manager = manager
        _scale = State(initialValue: pet.scale ?? 1.0)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 动画视图
            LottieView(filename: pet.effectiveLottieFileName)
                .frame(width: 150 * scale, height: 150 * scale)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let win = manager.window else { return }
                            let newOrigin = CGPoint(
                                x: win.frame.origin.x + value.translation.width,
                                y: win.frame.origin.y - value.translation.height
                            )
                            manager.updatePosition(newOrigin)
                        }
                        .onEnded { value in
                            guard let win = manager.window else { return }
                            let newOrigin = CGPoint(
                                x: win.frame.origin.x + value.translation.width,
                                y: win.frame.origin.y - value.translation.height
                            )
                            manager.updatePosition(newOrigin)
                            manager.savePosition(newOrigin)
                        }
                )
            
            // 悬停时显示控制按钮
            VStack(spacing: 4) {
                Button {
                    scale = max(0.3, scale - 0.1)
                    manager.updateScale(scale)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("缩小")
                
                Button {
                    scale = min(3.0, scale + 0.1)
                    manager.updateScale(scale)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("放大")
            }
            .padding(4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
            .opacity(0) // 默认隐藏，后续可改为悬停显示
        }
        .frame(width: 150 * scale, height: 150 * scale)
        .onChange(of: pet.scale) { _, newScale in
            if let newScale, abs(newScale - scale) > 0.001 {
                scale = newScale
            }
        }
    }
}
