//
//  ContentView.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import SwiftUI
import SwiftData

// MARK: - 侧边栏选项

enum SidebarSection: String, CaseIterable, Identifiable {
    case shortcuts = "快捷键"
    case pets = "宠物"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .shortcuts: return "keyboard"
        case .pets:     return "pawprint"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: SidebarSection? = .shortcuts

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section as SidebarSection?)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detailView(for: selectedSection)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSection)) { notification in
            if let rawValue = notification.userInfo?["section"] as? String,
               let section = SidebarSection(rawValue: rawValue) {
                selectedSection = section
            }
        }
    }

    @ViewBuilder
    private func detailView(for section: SidebarSection?) -> some View {
        switch section {
        case .shortcuts:
            ShortcutsView()
        case .pets:
            PetsView()
        case nil:
            Text("请从侧边栏选择一个功能")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 宠物页面

struct PetsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("宠物")
                .font(.title)
                .fontWeight(.semibold)

            Text("在此管理您的宠物")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: ShortcutItem.self, inMemory: true)
}
