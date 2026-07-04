# Meow - MenuBar 菜单列表增强设计

## 背景

当前 Meow 的 `MenuBarExtra` 只有「首页」和「退出」两个入口，功能过于单薄。用户希望增加更多快捷操作入口，让 menubar 成为真正的高频操作面板。

## 目标

在现有 `MenuBarExtra` 之上，扩展为一个包含导航入口、状态 toggle、退出的分组菜单，无需自定义 popover 面板，保持原生 macOS 菜单外观。

## 菜单结构

```
pawprint.fill
├── 首页
├── 快捷键管理
├── 宠物管理
├─────────
├── 快捷键监听  ✓   (toggle 选中状态表示正在监听)
├─────────
└── 退出
```

## 每项行为

| 菜单项 | 行为 |
|--------|------|
| 首页 | 主窗口带到前台（保留现有 `showMainWindow()` 逻辑） |
| 快捷键管理 | 主窗口带到前台 + 通过 `NotificationCenter` post `navigateToSection` 切换到 `shortcuts` section |
| 宠物管理 | 主窗口带到前台 + 通过 `NotificationCenter` post `navigateToSection` 切换到 `pets` section |
| 快捷键监听 | Toggle 菜单项。选中状态 = 正在监听，调用 `GlobalShortcutMonitor.shared.resume()`；取消选中 = 暂停，调用 `GlobalShortcutMonitor.shared.pause()`。默认选中 |
| 退出 | `NSApplication.shared.terminate(nil)` |

## 实现要点

1. 使用 `Toggle(isOn:)` 而非 `Button` 实现监听开关，这样系统自动管理勾选状态
2. 全局快捷键的监听状态存储在 `GlobalShortcutMonitor` 中，不需要额外持久化
3. 导航入口复用 `AppMenuAction.postNavigation(_:)` 模式（已存在）
4. 改动范围仅限于 `MeowApp.swift` 中的 `MenuBarExtra` 闭包
5. 不需要新增文件，不需要修改 SwiftData / ViewModel

## 非目标

- 不做自定义 popover 面板
- 不做动态菜单项（如最近使用的快捷键列表）
- 不修改主窗口的行为
- 不添加宠物相关的新功能入口（仅导航）
