
//
//  PetItem.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import Foundation
import SwiftData

/// 宠物种类枚举
enum PetType: String, CaseIterable, Identifiable, Codable {
    case cat = "cat"
    case dog = "dog"
    case fox = "fox"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cat: return "猫猫"
        case .dog: return "狗狗"
        case .fox: return "狐狸"
        }
    }

    /// 对应的 Lottie 文件名（不含扩展名）
    var lottieFileName: String { rawValue }

    /// SF Symbols 图标名
    var iconName: String {
        switch self {
        case .cat: return "cat"
        case .dog: return "dog"
        case .fox: return "fox"
        }
    }
}

@Model
final class PetItem {
    /// 宠物名字
    var name: String

    /// 宠物种类
    var petTypeRaw: String

    /// 自定义 Lottie 文件名（可选，为空时使用 petType 的默认文件）
    var customLottieFileName: String?

    /// 创建时间
    var createdAt: Date

    /// 备注
    var notes: String

    /// 是否启用
    var isActive: Bool

    /// 浮动窗口 X 坐标（nil 时使用默认右下角位置）
    var positionX: Double?

    /// 浮动窗口 Y 坐标（nil 时使用默认右下角位置）
    var positionY: Double?

    /// 浮动窗口尺寸倍数（nil 时使用默认 1.0）
    var scale: Double?

    var petType: PetType {
        get { PetType(rawValue: petTypeRaw) ?? .cat }
        set { petTypeRaw = newValue.rawValue }
    }

    /// 实际使用的 Lottie 文件名
    var effectiveLottieFileName: String {
        customLottieFileName ?? petType.lottieFileName
    }

    init(
        name: String,
        petType: PetType = .cat,
        customLottieFileName: String? = nil,
        notes: String = "",
        isActive: Bool = true,
        positionX: Double? = nil,
        positionY: Double? = nil,
        scale: Double? = nil
    ) {
        self.name = name
        self.petTypeRaw = petType.rawValue
        self.customLottieFileName = customLottieFileName
        self.createdAt = Date()
        self.notes = notes
        self.isActive = isActive
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
    }
}
