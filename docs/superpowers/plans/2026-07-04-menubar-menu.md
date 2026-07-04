# MenuBar 菜单列表扩展 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扩展 Meow 的 MenuBarExtra 菜单，增加快捷键管理/宠物管理的快捷导航，以及快捷键监听开关 toggle。

**Architecture:** 将 `MenuBarExtra` 的内容提取为独立 `MeowMenuView`，在其中使用 `@State` 管理监听开关状态。导航入口通过 `showMainWindow()` + `NotificationCenter` 实现，toggle 调用 `GlobalShortcutMonitor.shared.pause()/resume()`。

**Tech Stack:** SwiftUI, AppKit (macOS)

**File Structure:**

| 文件 | 状态 | 职责 |
|------|------|------|
| `Meow/MeowApp.swift` | Modify | 提取 MenuBarExtra 内容 + 添加 `MeowMenuView` |
| `Meow/AppMenus.swift` | Unchanged | 导航通知模式已存在，无需修改 |
| `Meow/Services/GlobalShortcutMonitor.swift` | Unchanged | `pause()/resume()` 已存在，直接调用 |

---

### Task 1: 重写 MenuBarExtra 菜单结构

**Files:**
- Modify: `Meow/MeowApp.swift`

**上下文：** 当前 MenuBarExtra 的内容是内联在 Scene body 中的。为了支持 `@State`（Toggle 需要 Binding），将菜单内容提取为一个独立的 `MeowMenuView` struct。

- [ ] **Step 1: 创建 MeowMenuView struct**

在 `MeowApp.swift` 末尾添加一个新 struct，包含完整的菜单结构和导航逻辑。

追加的代码如下：

```swift
// MARK: - MenuBar 菜单视图

private struct MeowMenuView: View {
    @State private var isMonitoringEnabled = GlobalShortcutMonitor.shared.isRunning

    var body: some View {
        Button("首页") {
            showMainWindow()
        }

        Button("快捷键管理") {
            navigateTo(.shortcuts)
        }

        Button("宠物管理") {
            navigateTo(.pets)
        }

        Divider()

        Toggle("快捷键监听", isOn: $isMonitoringEnabled)
            .onChange(of: isMonitoringEnabled) { _, newValue in
                if newValue {
                    GlobalShortcutMonitor.shared.resume()
                } else {
                    GlobalShortcutMonitor.shared.pause()
                }
            }

        Divider()

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible || $0.isMiniaturized }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func navigateTo(_ section: SidebarSection) {
        showMainWindow()
        NotificationCenter.default.post(
            name: .navigateToSection,
            object: nil,
            userInfo: ["section": section.rawValue]
        )
    }
}
```

- [ ] **Step 2: 替换 MenuBarExtra 内容**

将 `MeowApp.swift` 中 `MenuBarExtra` 的闭包内容从内联按钮替换为 `MeowMenuView()`。同时删除不再需要的 `showMainWindow()` 私有方法（已移到 `MeowMenuView` 中）。

原代码：

```swift
MenuBarExtra("Meow", systemImage: "pawprint.fill") {
    Button("首页") {
        showMainWindow()
    }

    Divider()

    Button("退出") {
        NSApplication.shared.terminate(nil)
    }
}
.modelContainer(sharedModelContainer)

...

/// 将主窗口显示到前台（从最小化/后台恢复）
private func showMainWindow() {
    NSApplication.shared.activate(ignoringOtherApps: true)
    if let window = NSApplication.shared.windows.first(where: { $0.isVisible || $0.isMiniaturized }) {
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
```

替换为：

```swift
MenuBarExtra("Meow", systemImage: "pawprint.fill") {
    MeowMenuView()
}
.modelContainer(sharedModelContainer)
```

注意：删除原 `private func showMainWindow()`。

- [ ] **Step 3: Build 验证**

Run: `xcodebuild -project Meow.xcodeproj -scheme Meow build 2>&1 | tail -30`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Meow/MeowApp.swift
git commit -m "feat: 扩展 menubar 菜单，增加导航入口与监听开关"
```
