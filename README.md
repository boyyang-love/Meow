# 🐾 Meow

macOS 菜单栏效率工具 —— 全局快捷键、超级关闭、端口诊断、桌面宠物,一站式收纳在菜单栏里。

[![Release](https://img.shields.io/badge/Release-v1.2-blue)](https://github.com/boyyang-love/Meow/releases)
![Platform](https://img.shields.io/badge/Platform-macOS%2027-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6-orange)

## ✨ 功能特性

| 功能 | 说明 |
|------|------|
| ⌨️ **全局快捷键** | 为任意应用绑定全局快捷键,一键唤起;内置快捷键冲突检测,编辑时自动暂停监听 |
| 💥 **超级关闭** | 一个快捷键关闭所有 Dock 应用(Finder / Meow 除外),完成后系统通知 |
| 🔌 **端口诊断** | 实时扫描本机监听端口,lsof 解析 + 按应用分组,一键结束占用进程 |
| 🐱 **桌面宠物** | Lottie 动画宠物常驻桌面,可拖拽移动、缩放大小、自定义动画文件 |
| 📋 **菜单栏面板** | 点击菜单栏图标弹出面板,快捷键列表 / 端口诊断 / 超级关闭 / 宠物四个 Tab 即点即用 |

## 📥 下载安装

从 [GitHub Releases](https://github.com/boyyang-love/Meow/releases) 下载最新的 `Meow.dmg`:

1. 打开 DMG,将 `Meow.app` 拖入 `Applications`
2. 首次启动,在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许 Meow
3. 完成,菜单栏出现 🐾 图标

> 安装包已通过 Apple Developer ID 签名 + 公证,可直接分发。

## 🚀 使用说明

### 快捷键
- 点击「+」选择应用,按下想绑定的快捷键组合
- 绑定冲突时自动提示,监听期间随时暂停/恢复(菜单栏面板顶部可切换)

### 超级关闭
- 启用后按下设定快捷键,一键关闭所有 Dock 应用
- 可在菜单栏面板快速开关与执行

### 端口诊断
- 面板每 5 秒自动刷新;点击 `x` 结束占用进程(有确认弹窗)
- 主窗口也可通过顶部菜单 **端口 → 端口诊断** 打开

### 宠物
- 添加猫 / 狗 / 狐狸,或导入自定义 Lottie JSON 动画
- 宠物浮窗可拖拽移动;菜单栏面板可实时调整大小(50% ~ 200%)
- 关闭窗口或 ⌘Q 后 Meow 隐藏到菜单栏,宠物保持显示

## 🛠 从源码构建

```bash
git clone git@github.com:boyyang-love/Meow.git
cd Meow
open Meow.xcodeproj
# Xcode 中 ⌘R 运行
```

命令行构建(本机只有 Xcode-beta 时):

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project Meow.xcodeproj -scheme Meow -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## 📦 打包分发

一键完成 Release 构建 → 签名 → 公证 → 钉票 → DMG:

```bash
./scripts/distribute.sh          # 完整流程
./scripts/distribute.sh --check-only   # 只检查环境
```

先决条件:Developer ID 证书 + App Store Connect API Key(`~/private_keys/AuthKey_*.p8`,Issuer ID 存入钥匙串)。产物输出到 `dist/`。

## 🧩 技术栈

- **SwiftUI** + **SwiftData**(`ShortcutItem` / `PetItem` 持久化)
- **CGEventTap** 全局快捷键监听(需要辅助功能权限)
- **NSStatusItem + NSPopover** 菜单栏弹出面板(原生箭头、居中对齐)
- **Lottie**(lottie-spm)宠物动画
- **lsof / ps** 端口与进程诊断

## 📁 项目结构

```
Meow/
├── MeowApp.swift          # App 入口
├── AppDelegate.swift      # 窗口管理 / 隐藏到菜单栏
├── AppMenus.swift         # 主菜单命令
├── ContentView.swift      # 主窗口导航
├── Models/                # SwiftData 模型
│   ├── ShortcutItem.swift
│   ├── PetItem.swift
│   └── SuperCloseShortcut.swift
├── Services/
│   ├── GlobalShortcutMonitor.swift   # 全局快捷键 + 超级关闭
│   ├── MenuBarController.swift       # 菜单栏图标 + 弹出面板
│   ├── PortService.swift             # 端口扫描解析
│   └── PetFileManager.swift          # 自定义 Lottie 文件管理
├── Views/                 # 各功能视图 + 宠物浮窗
└── scripts/
    └── distribute.sh      # 打包分发脚本
```

## ❓ 常见问题

**Q: 快捷键没有反应?**
检查:系统设置 → 隐私与安全性 → 辅助功能 是否允许 Meow;面板顶部「监听中」是否为开启状态。

**Q: 提示「无法打开,因为无法验证开发者」?**
安装包已公证,正常情况下不会出现;若出现请确认下载的是 Releases 中的最新 DMG。

**Q: 宠物文件放在哪里?**
自定义 Lottie 文件保存在 `~/Documents/Pets/`,可在主窗口宠物详情中导入/重置。

## 📄 License

未指定。
