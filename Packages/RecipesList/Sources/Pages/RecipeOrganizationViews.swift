//
//  RecipeOrganizationViews.swift
//  RecipesList
//
//  Created by Tom Knighton on 19/05/2026.
//

import Design
import Environment
import Models
import SwiftUI

public struct RecipeFoldersPage: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.homeServices) private var homes
    @Environment(\.flagKit) private var flagKit

    @State private var repository = RecipeOrganizationRepository()
    @State private var isProPaywallPresented = false

    private var rootNodes: [RecipeFolderNode] {
        RecipeFolderNode.nodes(from: repository.folderSummaries(homeId: homes.home?.id))
    }

    public init() {}

    public var body: some View {
        List {
            Section {
                NavigationLink(value: AppDestination.recipes()) {
                    Label("All Recipes", systemImage: "square.stack")
                }

                if hasRecipeOrganizationProAccess {
                    ForEach(rootNodes) { node in
                        RecipeFolderTreeNavigationRow(node: node)
                    }
                } else {
                    Button {
                        isProPaywallPresented = true
                    } label: {
                        Label("Unlock Folders & Tags", systemImage: "lock.fill")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cookbook")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .toolbar {
            if hasRecipeOrganizationProAccess {
                ToolbarItem {
                    NavigationLink {
                        RecipeOrganizationManagePage(
                            repository: repository,
                            homeId: homes.home?.id
                        )
                    } label: {
                        Label("Manage Folders & Tags", systemImage: "folder.badge.gearshape")
                    }
                }
            } else {
                ToolbarItem {
                    Button {
                        isProPaywallPresented = true
                    } label: {
                        Label("Unlock Folders & Tags", systemImage: "lock.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $isProPaywallPresented) {
            ProPaywallView()
        }
    }

    private var hasRecipeOrganizationProAccess: Bool {
        flagKit.isEnabled(.recipeOrganizationPro, default: false)
    }
}

struct RecipeOrganizationAssignmentSheet: View {
    let recipe: Recipe
    let repository: RecipeOrganizationRepository
    let homeId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFolderIDs: Set<UUID>
    @State private var selectedTagIDs: Set<UUID>
    @State private var newFolderName = ""
    @State private var newTagName = ""
    @State private var errorMessage: String?
    @State private var isErrorPresented = false

    private var availableFolders: [RecipeFolder] {
        repository.folders(in: homeId)
    }

    private var availableTags: [RecipeTag] {
        repository.tags(in: homeId)
    }

    private var suggestedTags: [RecipeTag] {
        repository.suggestedTags(for: recipe, in: homeId)
            .filter { !selectedTagIDs.contains($0.id) }
    }

    init(recipe: Recipe, repository: RecipeOrganizationRepository, homeId: UUID?) {
        self.recipe = recipe
        self.repository = repository
        self.homeId = homeId
        self._selectedFolderIDs = State(initialValue: Set(recipe.folders.map(\.id)))
        self._selectedTagIDs = State(initialValue: Set(recipe.tags.map(\.id)))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Folders") {
                    if availableFolders.isEmpty {
                        ContentUnavailableView("No Folders", systemImage: "folder", description: Text("Create folders for menus, clients, testing, or service styles."))
                    } else {
                        ForEach(availableFolders) { folder in
                            OrganizationToggleRow(
                                title: folder.name,
                                systemImage: folder.symbolName,
                                colorHex: folder.colorHex,
                                isSelected: selectedFolderIDs.contains(folder.id),
                                action: { toggleFolder(folder.id) }
                            )
                        }
                    }

                    InlineCreateRow(title: "New Folder", text: $newFolderName, action: createFolder)
                }

                Section("Tags") {
                    if !suggestedTags.isEmpty {
                        SuggestedTagCloud(tags: suggestedTags, action: selectTag)
                    }

                    if availableTags.isEmpty {
                        ContentUnavailableView("No Tags", systemImage: "tag", description: Text("Create tags for cuisine, dietary notes, prep style, or station planning."))
                    } else {
                        ForEach(availableTags) { tag in
                            OrganizationToggleRow(
                                title: tag.name,
                                systemImage: "tag",
                                colorHex: tag.colorHex,
                                isSelected: selectedTagIDs.contains(tag.id),
                                action: { toggleTag(tag.id) }
                            )
                        }
                    }

                    InlineCreateRow(title: "New Tag", text: $newTagName, action: createTag)
                }
            }
            .navigationTitle("Organize Recipe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .alert("Organization Failed", isPresented: $isErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    private func toggleFolder(_ id: UUID) {
        if selectedFolderIDs.contains(id) {
            selectedFolderIDs.remove(id)
        } else {
            selectedFolderIDs.insert(id)
        }
    }

    private func toggleTag(_ id: UUID) {
        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
    }

    private func selectTag(_ tag: RecipeTag) {
        selectedTagIDs.insert(tag.id)
    }

    private func createFolder() {
        let name = newFolderName
        Task {
            do {
                if let folder = try await repository.createFolder(name: name, homeId: homeId) {
                    selectedFolderIDs.insert(folder.id)
                    newFolderName = ""
                }
            } catch {
                present(error)
            }
        }
    }

    private func createTag() {
        let name = newTagName
        Task {
            do {
                if let tag = try await repository.createTag(name: name, homeId: homeId) {
                    selectedTagIDs.insert(tag.id)
                    newTagName = ""
                }
            } catch {
                present(error)
            }
        }
    }

    private func save() {
        Task {
            do {
                try await repository.setOrganization(for: recipe, folderIDs: selectedFolderIDs, tagIDs: selectedTagIDs)
                dismiss()
            } catch {
                present(error)
            }
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isErrorPresented = true
    }
}

public struct RecipeOrganizationManagePage: View {
    let repository: RecipeOrganizationRepository
    let homeId: UUID?

    @State private var newFolderName = ""
    @State private var newTagName = ""
    @State private var creatingChildOf: RecipeFolder?
    @State private var editingFolder: RecipeFolder?
    @State private var editingTag: RecipeTag?
    @State private var editName = ""
    @State private var errorMessage: String?
    @State private var isErrorPresented = false

    private var folders: [RecipeFolderSummary] {
        repository.folderSummaries(homeId: homeId)
    }

    private var rootNodes: [RecipeFolderNode] {
        RecipeFolderNode.nodes(from: folders)
    }

    private var tags: [RecipeTagSummary] {
        repository.tagSummaries(homeId: homeId)
    }

    public var body: some View {
        List {
            Section("Folders") {
                if folders.isEmpty {
                    ContentUnavailableView("No Folders", systemImage: "folder", description: Text("Folders can group client menus, prep batches, events, or family favourites."))
                } else {
                    ForEach(rootNodes) { node in
                        RecipeFolderManageTreeRow(
                            node: node,
                            onCreateChild: beginCreatingChild,
                            onRename: beginEditing,
                            onDelete: deleteFolder
                        )
                    }
                }

                InlineCreateRow(title: "New Folder", text: $newFolderName) {
                    createFolder()
                }
            }

            Section("Tags") {
                if tags.isEmpty {
                    ContentUnavailableView("No Tags", systemImage: "tag", description: Text("Tags work well for cuisine, diet, service style, stations, and prep notes."))
                } else {
                    ForEach(tags) { summary in
                        OrganizationSummaryRow(
                            title: summary.tag.name,
                            subtitle: countText(summary.recipeCount),
                            systemImage: "tag",
                            colorHex: summary.tag.colorHex
                        )
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                beginEditing(tag: summary.tag)
                            }
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                deleteTag(summary.tag)
                            }
                            Button("Rename", systemImage: "pencil") {
                                beginEditing(tag: summary.tag)
                            }
                            .tint(.blue)
                        }
                    }
                }

                InlineCreateRow(title: "New Tag", text: $newTagName, action: createTag)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Folders & Tags")
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .alert("Organization Failed", isPresented: $isErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
        .sheet(isPresented: editBinding) {
            NavigationStack {
                Form {
                    TextField("Name", text: $editName)
                        .textInputAutocapitalization(.words)
                }
                .navigationTitle("Rename")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: endEditing)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: saveEdit)
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .presentationDetents([.height(180)])
        }
        .sheet(item: $creatingChildOf) { parent in
            CreateChildFolderSheet(parent: parent, name: $newFolderName) {
                createFolder(parentFolderId: parent.id)
            }
        }
    }

    private var editBinding: Binding<Bool> {
        Binding(
            get: { editingFolder != nil || editingTag != nil },
            set: { isPresented in
                if !isPresented {
                    endEditing()
                }
            }
        )
    }

    private func createFolder(parentFolderId: UUID? = nil) {
        let name = newFolderName
        Task {
            do {
                if try await repository.createFolder(name: name, homeId: homeId, parentFolderId: parentFolderId) != nil {
                    newFolderName = ""
                    creatingChildOf = nil
                }
            } catch {
                present(error)
            }
        }
    }

    private func createTag() {
        let name = newTagName
        Task {
            do {
                if try await repository.createTag(name: name, homeId: homeId) != nil {
                    newTagName = ""
                }
            } catch {
                present(error)
            }
        }
    }

    private func deleteFolder(_ folder: RecipeFolder) {
        Task {
            do {
                try await repository.deleteFolder(folder)
            } catch {
                present(error)
            }
        }
    }

    private func deleteTag(_ tag: RecipeTag) {
        Task {
            do {
                try await repository.deleteTag(tag)
            } catch {
                present(error)
            }
        }
    }

    private func beginEditing(folder: RecipeFolder) {
        editingFolder = folder
        editingTag = nil
        editName = folder.name
    }

    private func beginCreatingChild(parent: RecipeFolder) {
        creatingChildOf = parent
        newFolderName = ""
    }

    private func beginEditing(tag: RecipeTag) {
        editingTag = tag
        editingFolder = nil
        editName = tag.name
    }

    private func saveEdit() {
        let name = editName
        let folder = editingFolder
        let tag = editingTag

        Task {
            do {
                if let folder {
                    try await repository.updateFolder(folder, name: name)
                } else if let tag {
                    try await repository.updateTag(tag, name: name)
                }
                endEditing()
            } catch {
                present(error)
            }
        }
    }

    private func endEditing() {
        editingFolder = nil
        editingTag = nil
        editName = ""
    }

    private func countText(_ count: Int) -> String {
        count == 1 ? "1 recipe" : "\(count) recipes"
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isErrorPresented = true
    }
}

private struct CreateChildFolderSheet: View {
    let parent: RecipeFolder
    @Binding var name: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Folder Name", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("New Subfolder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: onSave)
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .presentationDetents([.height(180)])
    }
}

private struct InlineCreateRow: View {
    let title: String
    @Binding var text: String
    let action: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack {
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(submit)

            Button(action: submit) {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.glass)
            .disabled(!canSubmit)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        action()
    }
}

private struct RecipeFolderNode: Identifiable, Hashable {
    let summary: RecipeFolderSummary
    let children: [RecipeFolderNode]

    var id: UUID { summary.folder.id }

    static func nodes(from summaries: [RecipeFolderSummary], parentFolderId: UUID? = nil) -> [RecipeFolderNode] {
        summaries
            .filter { $0.folder.parentFolderId == parentFolderId }
            .sorted { lhs, rhs in
                if lhs.folder.sortIndex == rhs.folder.sortIndex {
                    return lhs.folder.name.localizedCaseInsensitiveCompare(rhs.folder.name) == .orderedAscending
                }
                return lhs.folder.sortIndex < rhs.folder.sortIndex
            }
            .map { summary in
                RecipeFolderNode(
                    summary: summary,
                    children: nodes(from: summaries, parentFolderId: summary.folder.id)
                )
            }
    }
}

private struct RecipeFolderTreeNavigationRow: View {
    let node: RecipeFolderNode

    var body: some View {
        if node.children.isEmpty {
            NavigationLink(value: AppDestination.recipes(folderID: node.summary.folder.id)) {
                folderLabel
            }
        } else {
            DisclosureGroup {
                NavigationLink(value: AppDestination.recipes(folderID: node.summary.folder.id)) {
                    Label("All in \(node.summary.folder.name)", systemImage: "square.stack")
                }

                ForEach(node.children) { child in
                    RecipeFolderTreeNavigationRow(node: child)
                }
            } label: {
                folderLabel
            }
        }
    }

    private var folderLabel: some View {
        OrganizationSummaryRow(
            title: node.summary.folder.name,
            subtitle: summaryText,
            systemImage: node.summary.folder.symbolName,
            colorHex: node.summary.folder.colorHex
        )
    }

    private var summaryText: String {
        let recipeText = node.summary.recipeCount == 1 ? "1 recipe" : "\(node.summary.recipeCount) recipes"
        guard node.summary.descendantCount > 0 else { return recipeText }
        return "\(recipeText), \(node.summary.descendantCount) subfolders"
    }
}

private struct RecipeFolderManageTreeRow: View {
    let node: RecipeFolderNode
    let onCreateChild: (RecipeFolder) -> Void
    let onRename: (RecipeFolder) -> Void
    let onDelete: (RecipeFolder) -> Void

    var body: some View {
        if node.children.isEmpty {
            row
        } else {
            DisclosureGroup {
                ForEach(node.children) { child in
                    RecipeFolderManageTreeRow(
                        node: child,
                        onCreateChild: onCreateChild,
                        onRename: onRename,
                        onDelete: onDelete
                    )
                }
            } label: {
                rowContent
            }
        }
    }

    private var row: some View {
        rowContent
            .contextMenu { actions }
            .swipeActions { swipeActions }
    }

    private var rowContent: some View {
        OrganizationSummaryRow(
            title: node.summary.folder.name,
            subtitle: summaryText,
            systemImage: node.summary.folder.symbolName,
            colorHex: node.summary.folder.colorHex
        )
        .contextMenu { actions }
        .swipeActions { swipeActions }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Add Subfolder", systemImage: "folder.badge.plus") {
            onCreateChild(node.summary.folder)
        }

        Button("Rename", systemImage: "pencil") {
            onRename(node.summary.folder)
        }
    }

    @ViewBuilder
    private var swipeActions: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            onDelete(node.summary.folder)
        }

        Button("Subfolder", systemImage: "folder.badge.plus") {
            onCreateChild(node.summary.folder)
        }
        .tint(.green)

        Button("Rename", systemImage: "pencil") {
            onRename(node.summary.folder)
        }
        .tint(.blue)
    }

    private var summaryText: String {
        let recipeText = node.summary.recipeCount == 1 ? "1 recipe" : "\(node.summary.recipeCount) recipes"
        guard node.summary.descendantCount > 0 else { return recipeText }
        return "\(recipeText), \(node.summary.descendantCount) subfolders"
    }
}

private struct OrganizationToggleRow: View {
    let title: String
    let systemImage: String
    let colorHex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                OrganizationIcon(systemImage: systemImage, colorHex: colorHex)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct OrganizationSummaryRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let colorHex: String

    var body: some View {
        HStack(spacing: 12) {
            OrganizationIcon(systemImage: systemImage, colorHex: colorHex)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SuggestedTagCloud: View {
    let tags: [RecipeTag]
    let action: (RecipeTag) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            FlowLayout(alignment: .leading, spacing: 8) {
                ForEach(tags) { tag in
                    Button(action: { action(tag) }) {
                        Label(tag.name, systemImage: "sparkle")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct OrganizationIcon: View {
    let systemImage: String
    let colorHex: String

    private var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12), in: Circle())
    }
}
