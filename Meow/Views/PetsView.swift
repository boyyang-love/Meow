//
//  PetsView.swift
//  Meow
//
//  Created by boyyang on 2026/7/4.
//

import SwiftUI
import SwiftData

// MARK: - 宠物管理主视图

struct PetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PetItem.createdAt, order: .forward) private var pets: [PetItem]
    @State private var selectedPet: PetItem?
    @Binding var showAddSheet: Bool
    @Binding var pendingImportUuid: String?
    @Binding var pendingImportName: String?

    var body: some View {
        petListView
            .frame(minWidth: 400, minHeight: 400)
            .onAppear {
                ActivePetManager.shared.setup(with: modelContext)
                if let activePet = pets.first(where: { $0.isActive }) {
                    ActivePetManager.shared.showPet(activePet)
                }
            }
    .sheet(isPresented: $showAddSheet) {
        AddPetView(preImportedFileName: pendingImportUuid, preImportedName: pendingImportName)
            .onDisappear {
                pendingImportUuid = nil
                pendingImportName = nil
            }
    }
    }

    // MARK: - 宠物列表

    private var petListView: some View {
        VStack(spacing: 0) {
            if pets.isEmpty {
                emptyListPlaceholder
            } else {
                List(pets, selection: $selectedPet) { pet in
                    PetRowView(pet: pet, onToggle: togglePetActivation, onDelete: deletePet)
                        .tag(pet as PetItem?)
                       .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                           Button(role: .destructive) {
                               deletePet(pet)
                           } label: {
                               Image(systemName: "trash")
                           }
                       }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var emptyListPlaceholder: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.quinary)
                    .frame(width: 80, height: 80)
                Image(systemName: "pawprint")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 6) {
                Text("还没有宠物")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("添加一只宠物来开始陪伴")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }

            Button(action: { showAddSheet = true }) {
                Label("添加第一只宠物", systemImage: "plus")
            }
            .help("添加一只宠物，可自定义 Lottie JSON 动画文件")
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func togglePetActivation(_ pet: PetItem) {
        if pet.isActive {
            pet.isActive = false
            ActivePetManager.shared.hidePet()
        } else {
            for p in pets where p.isActive {
                p.isActive = false
            }
            pet.isActive = true
            ActivePetManager.shared.showPet(pet)
        }
        try? modelContext.save()
    }


    private func deletePet(_ pet: PetItem) {
        // 清理自定义 Lottie 文件
        if let customFile = pet.customLottieFileName {
            PetFileManager.shared.deleteCustomFile(filename: customFile)
        }
        modelContext.delete(pet)
        if selectedPet?.id == pet.id {
            selectedPet = nil
        }
    }
}

// MARK: - 宠物详情视图

struct PetDetailView: View {
    @Bindable var pet: PetItem
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false

    private var isCustom: Bool { pet.customLottieFileName != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // 动画展示（带容器）
                VStack(spacing: 12) {
                    LottieView(filename: pet.effectiveLottieFileName)
                        .frame(width: 180, height: 180)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.quinary)
                                .frame(width: 200, height: 200)
                        )

                    // 自定义动画管理
                    HStack(spacing: 10) {
                        Button {
                            importCustomLottie()
                        } label: {
                            Label("导入 Lottie", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if isCustom {
                            Button(role: .destructive) {
                                resetToDefault()
                            } label: {
                                Label("重置默认", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if isCustom {
                        Label("当前使用自定义动画", systemImage: "square.and.pencil")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // 信息编辑区（分组卡片）
                VStack(spacing: 12) {
                    HStack {
                        Text("名字")
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                        TextField("宠物名字", text: $pet.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("种类")
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                        Text(pet.petType.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                    }

                    Divider()

                    Toggle(isOn: $pet.isActive) {
                        Label("在桌面显示", systemImage: "macbook")
                            .foregroundStyle(.primary)
                    }
                    .toggleStyle(.switch)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                )
                .padding(.horizontal)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("删除「\(pet.name)」", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    performDelete()
                }
            } message: {
                Text("确定要删除「\(pet.name)」吗？此操作不可撤销。")
            }
        }
        .frame(minWidth: 320)
    }

    private func performDelete() {
        if let customFile = pet.customLottieFileName {
            PetFileManager.shared.deleteCustomFile(filename: customFile)
        }
        modelContext.delete(pet)
    }

    // MARK: - 自定义文件操作

    private func importCustomLottie() {
        guard let result = PetFileManager.shared.importLottieFile() else { return }
        if let oldFile = pet.customLottieFileName {
            PetFileManager.shared.deleteCustomFile(filename: oldFile)
        }
        pet.customLottieFileName = result.uuid
    }

    private func resetToDefault() {
        if let customFile = pet.customLottieFileName {
            PetFileManager.shared.deleteCustomFile(filename: customFile)
        }
        pet.customLottieFileName = nil
    }
}

// MARK: - 添加宠物视图

private struct AddPetView: View {
    var preImportedFileName: String?
    var preImportedName: String?
    @State private var importedFileName: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            // --- 标题区 ---
            HStack(spacing: 8) {
                Image(systemName: "pawprint.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("添加新宠物")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 24) {
                    // --- 宠物预览区 ---
                    previewSection


                    // --- 名字输入 ---
                    nameSection
                }
                .padding(.horizontal, 24)
            }

            Divider()

            // --- 操作按钮 ---
            HStack(spacing: 12) {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("取消")
                        .frame(minWidth: 60)
                }
                .keyboardShortcut(.escape)

                Button(action: addPet) {
                    Label("添加", systemImage: "plus")
                        .frame(minWidth: 60)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if let preImportedFileName {
                importedFileName = preImportedFileName
            }
            if let preImportedName, name.isEmpty {
                name = preImportedName
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quinary)
                    .frame(width: 160, height: 160)

                LottieView(filename: effectiveFileName)
                    .frame(width: 140, height: 140)
            }

            Button {
                if let result = PetFileManager.shared.importLottieFile() {
                    importedFileName = result.uuid
                    name = result.originalName
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: importedFileName != nil ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: 12))
                    Text(importedFileName != nil ? "已导入自定义动画" : "导入 Lottie 动画")
                        .font(.callout)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("从文件中选择一个 Lottie JSON 动画")

            if importedFileName != nil {
                Button(role: .destructive) {
                    importedFileName = nil
                } label: {
                    Text("移除自定义动画")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 0)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("宠物名字")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextField("给你的宠物取个名字", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.body)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    // MARK: - Helpers

    private var effectiveFileName: String {
        importedFileName ?? PetType.cat.lottieFileName
    }

    private func addPet() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let pet = PetItem(
            name: trimmed,
            petType: .cat,
            customLottieFileName: importedFileName,
            notes: "",
            isActive: false,
        )
        modelContext.insert(pet)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 宠物行视图

private struct PetRowView: View {
    let pet: PetItem
    var onToggle: ((PetItem) -> Void)?
    var onDelete: ((PetItem) -> Void)?
    @State private var showDeletePopover = false

    private var isCustom: Bool { pet.customLottieFileName != nil }

    var body: some View {
        HStack(spacing: 14) {
            // 小尺寸动画预览（圆角容器）
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quinary)
                    .frame(width: 52, height: 52)

                LottieView(filename: pet.effectiveLottieFileName)
                    .frame(width: 48, height: 48)
            }

            // 名字 + 元数据
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(pet.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if isCustom {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .help("自定义动画")
                    }
                }

                HStack(spacing: 6) {
                    Text(pet.createdAt, style: .date)
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // 状态标签 + 操作按钮
            HStack(spacing: 6) {
                statusBadge

                if pet.isActive {
                    Button {
                        onToggle?(pet)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("收起宠物")
                }

                Button {
                    onToggle?(pet)
                } label: {
                    Image(systemName: pet.isActive ? "poweron" : "poweroff")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(pet.isActive ? Color.green : Color.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help(pet.isActive ? "点击停用" : "点击启用")

                Button(role: .destructive) {
                    showDeletePopover = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("删除此宠物")
                .popover(isPresented: $showDeletePopover) {
                    VStack(spacing: 14) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.red)
                        Text("确认删除")
                            .font(.headline)
                        Text("确定要删除「\(pet.name)」吗？此操作不可撤销。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        HStack(spacing: 12) {
                            Button("取消") {
                                showDeletePopover = false
                            }
                            .keyboardShortcut(.escape)
                            Button("删除", role: .destructive) {
                                onDelete?(pet)
                                showDeletePopover = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding()
                    .frame(width: 230)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contextMenu {
            Button {
                onToggle?(pet)
            } label: {
                Label(pet.isActive ? "停用" : "启用", systemImage: pet.isActive ? "pause" : "play")
            }
            Divider()
            Button(role: .destructive) {
                showDeletePopover = true
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if pet.isActive {
            Text("显示中")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(.green.opacity(0.12))
                )
        } else {
            Text("已隐藏")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(.quinary)
                )
        }
    }
}
