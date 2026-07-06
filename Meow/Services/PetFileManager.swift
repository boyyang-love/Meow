
//
//  PetFileManager.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import Lottie

/// 管理用户上传的自定义 Lottie 动画文件
final class PetFileManager {

    static let shared = PetFileManager()

    private init() {}

    /// 自定义 Lottie 文件的存放目录 (Documents/Pets/)
    private var customDirectory: URL? {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Pets", isDirectory: true)
        if let dir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 返回自定义 Lottie 文件在 Documents 中的 URL
    func customLottieURL(filename: String) -> URL? {
        customDirectory?.appendingPathComponent("\(filename).json")
    }

    /// 让用户通过 NSOpenPanel 选择一个 .json 文件，复制到 Documents/Pets/ 并返回 UUID 文件名
    func importLottieFile() -> (uuid: String, originalName: String)? {
        let panel = NSOpenPanel()
        panel.title = "导入 Lottie 动画"
        panel.message = "选择一个 Lottie 动画 JSON 文件"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return nil }

        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let uuid = UUID().uuidString
        guard let destDir = customDirectory else { return nil }
        let destURL = destDir.appendingPathComponent("\(uuid).json")

        // 如果目标已存在，先删除
        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return (uuid, originalName)
        } catch {
            print("[PetFileManager] 导入失败: \(error)")
            return nil
        }
    }

    /// 从 URL 加载 LottieAnimation
    func loadLottie(from url: URL) -> LottieAnimation? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let animation = try? LottieAnimation(dictionary: json) else {
            return nil
        }
        return animation
    }

    /// 删除自定义 Lottie 文件
    func deleteCustomFile(filename: String) {
        guard let url = customLottieURL(filename: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
