//
//  LottieView.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import SwiftUI
import Lottie

/// SwiftUI 包装器，用于在 macOS 上显示 Lottie 动画
struct LottieView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    typealias NSViewType = NSView
    
    let filename: String
    var isAnimating: Bool = true
    var loopMode: LottieLoopMode = .loop
    
    func makeNSView(context: Context) -> NSView {
        let animationView = LottieAnimationView(animation: nil)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        context.coordinator.lastFilename = filename
        reloadAnimation(animationView)
        if !isAnimating {
            animationView.pause()
        }
        return animationView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let animationView = nsView as? LottieAnimationView else { return }
        guard context.coordinator.lastFilename != filename else {
            animationView.contentMode = .scaleAspectFit
            if !isAnimating { animationView.pause() }
            return
        }
        context.coordinator.lastFilename = filename
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        reloadAnimation(animationView)
        if !isAnimating {
            animationView.pause()
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
    
    private func reloadAnimation(_ view: LottieAnimationView) {
        view.contentMode = .scaleAspectFit
        // 1) 优先尝试 Documents/Pets/ (用户上传的自定义文件)
        if let docsURL = PetFileManager.shared.customLottieURL(filename: filename),
           let animation = PetFileManager.shared.loadLottie(from: docsURL) {
            view.animation = animation
            view.play()
            return
        }
        // 2) 尝试 bundle 内 Pets/ 子目录
        if let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Pets"),
           let animation = PetFileManager.shared.loadLottie(from: url) {
            view.animation = animation
            view.play()
            return
        }
        // 3) 尝试 bundle 根目录
        if let url = Bundle.main.url(forResource: filename, withExtension: "json"),
           let animation = PetFileManager.shared.loadLottie(from: url) {
            view.animation = animation
            view.play()
            return
        }
        view.play()
    }
}

// MARK: - Coordinator

extension LottieView {
    class Coordinator {
        var lastFilename: String?
    }
}
