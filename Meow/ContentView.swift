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
    @State private var showAddPetSheet = false
    @State private var showToolbarPopover = false
    @State private var pendingImportUuid: String?
    @State private var pendingImportName: String?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(SidebarSection.allCases, id: \.self) { section in
                    sidebarRow(for: section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
        } detail: {
            detailView(for: selectedSection)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                VStack(spacing: 0) {
                    Button(action: {
                        switch selectedSection {
                        case .shortcuts: NotificationCenter.default.post(name: .addShortcut, object: nil)
                        case .pets: showToolbarPopover.toggle()
                        case nil: break
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                    .popover(isPresented: $showToolbarPopover, arrowEdge: .bottom) {
                        toolbarPopoverContent
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSection)) { notification in
            if let rawValue = notification.userInfo?["section"] as? String,
               let section = SidebarSection(rawValue: rawValue) {
                selectedSection = section
            }
        }
    }
    
    // MARK: - Sidebar Row
    
    private func sidebarRow(for section: SidebarSection) -> some View {
        let isSelected = selectedSection == section
        
        return Label(section.rawValue, systemImage: section.icon)
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .labelStyle(.titleAndIcon)
            .padding(.vertical, 2)
            .padding(.leading, 4)
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var toolbarPopoverContent: some View {
        switch selectedSection {
        case .shortcuts:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                    Text("添加快捷键")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Divider()
                Label("选择一个应用并配置快捷键", systemImage: "app.badge")
                    .font(.caption)
            }
            .padding(12)
            .frame(width: 200)
            
        case .pets:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                    Text("添加新宠物")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Divider()
                
                Button(action: {
                    if let result = PetFileManager.shared.importLottieFile() {
                        pendingImportUuid = result.uuid
                        pendingImportName = result.originalName
                        showAddPetSheet = true
                    }
                    showToolbarPopover = false
                }) {
                    Label("选择 Lottie 动画文件", systemImage: "square.and.arrow.down")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: {
                    pendingImportUuid = nil
                    pendingImportName = nil
                    showAddPetSheet = true
                    showToolbarPopover = false
                }) {
                    Label("直接添加", systemImage: "plus")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(12)
            .frame(width: 200)
            
        case nil:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func detailView(for section: SidebarSection?) -> some View {
        ZStack {
            ShortcutsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(section == .shortcuts ? 1 : 0)
                .allowsHitTesting(section == .shortcuts)
            
            PetsView(showAddSheet: $showAddPetSheet, pendingImportUuid: $pendingImportUuid, pendingImportName: $pendingImportName)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(section == .pets ? 1 : 0)
                .allowsHitTesting(section == .pets)
            
            if section == nil {
                emptySelectionView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(section?.rawValue ?? "")
    }
    
    private var emptySelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("从侧边栏选择一个功能")
                .font(.body)
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
