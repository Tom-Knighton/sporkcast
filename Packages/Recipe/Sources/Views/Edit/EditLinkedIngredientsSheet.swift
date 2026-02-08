//
//  EditLinkedIngredientsSheet.swift
//  Recipe
//
//  Created by Tom Knighton on 08/02/2026.
//

import SwiftUI
import Models
import Persistence
import UIKit

struct EditLinkedIngredientsSheet: View {
    
    @State public var allIngredients: [RecipeIngredient]
    @State public var matchedIngredients: [RecipeIngredient]
    public let instructionText: String
    public let onUpdate: ([RecipeIngredient]) -> Void
    @Environment(\.dismiss) private var dismiss
        
    var body: some View {
        DraggableIngredientList(
            allIngredients: $allIngredients,
            matchedIngredients: $matchedIngredients,
            instructionText: instructionText,
            onDismiss: {
                onUpdate(matchedIngredients)
                dismiss()
            }
        )
        .ignoresSafeArea()
    }
}

struct DraggableIngredientList: UIViewControllerRepresentable {
    @Binding var allIngredients: [RecipeIngredient]
    @Binding var matchedIngredients: [RecipeIngredient]
    let instructionText: String
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let root = DraggableIngredientViewController(
            allIngredients: allIngredients,
            matchedIngredients: matchedIngredients,
            instructionText: instructionText,
            onUpdate: { all, matched in
                allIngredients = all
                matchedIngredients = matched
            }
        )
        
        root.title = "Linked Ingredients"
        root.navigationItem.largeTitleDisplayMode = .automatic
        root.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(Coordinator.handleDone)
        )
        
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        guard let root = uiViewController.viewControllers.first as? DraggableIngredientViewController else { return }
        root.setIngredients(all: allIngredients, matched: matchedIngredients)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator {
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        @objc func handleDone() {
            onDismiss()
        }
    }
}

class DraggableIngredientViewController: UIViewController, UICollectionViewDelegate {
    private var collectionView: UICollectionView?
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    
    private var allIngredients: [RecipeIngredient]
    private var matchedIngredients: [RecipeIngredient]
    private let instructionText: String
    private let onUpdate: ([RecipeIngredient], [RecipeIngredient]) -> Void
    
    enum Section: Int, CaseIterable {
        case instruction
        case linked
        case notLinked
        
        var title: String? {
            switch self {
            case .instruction: return nil
            case .linked: return "Linked"
            case .notLinked: return "Not Linked"
            }
        }
    }
    
    enum Item: Hashable {
        case instruction(String)
        case ingredient(RecipeIngredient)
    }
    
    init(allIngredients: [RecipeIngredient], matchedIngredients: [RecipeIngredient], instructionText: String, onUpdate: @escaping ([RecipeIngredient], [RecipeIngredient]) -> Void) {
        self.allIngredients = allIngredients
        self.matchedIngredients = matchedIngredients
        self.instructionText = instructionText
        self.onUpdate = onUpdate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let collectionView = setupCollectionView()
        self.collectionView = collectionView
        setupDataSource(for: collectionView)
        applySnapshot()
    }
    
    private func setupCollectionView() -> UICollectionView {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.isEditing = true
        view.addSubview(collectionView)
        
        return collectionView
    }
    
    private func setupDataSource(for collectionView: UICollectionView) {
        let ingredientCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, RecipeIngredient> { cell, indexPath, ingredient in
            var content = cell.defaultContentConfiguration()
            var text = ingredient.ingredientText
            if let emoji = ingredient.emoji {
                text = "\(emoji) \(text)"
            }
            content.text = text
            cell.accessories = [.reorder(displayed: .always)]
            cell.contentConfiguration = content
        }
        
        let textCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, indexPath, text in
            var content = UIListContentConfiguration.cell()
            content.text = text
            content.textProperties.numberOfLines = 0
            cell.contentConfiguration = content
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .instruction(let text):
                return collectionView.dequeueConfiguredReusableCell(using: textCellRegistration, for: indexPath, item: text)
            case .ingredient(let ingredient):
                return collectionView.dequeueConfiguredReusableCell(using: ingredientCellRegistration, for: indexPath, item: ingredient)
            }
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { headerView, elementKind, indexPath in
            guard let section = Section(rawValue: indexPath.section),
                  let title = section.title else { return }
            var content = headerView.defaultContentConfiguration()
            content.text = title
            headerView.contentConfiguration = content
        }
        
        dataSource?.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
        
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.instruction, .linked, .notLinked])
        
        snapshot.appendItems([.instruction(instructionText)], toSection: .instruction)
        snapshot.appendItems(matchedIngredients.map { .ingredient($0) }, toSection: .linked)
        
        let notLinked = allIngredients.filter { !matchedIngredients.contains($0) }
        snapshot.appendItems(notLinked.map { .ingredient($0) }, toSection: .notLinked)
        
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
    
    func setIngredients(all: [RecipeIngredient], matched: [RecipeIngredient]) {
        allIngredients = all
        matchedIngredients = matched
        applySnapshot()
    }
}

extension DraggableIngredientViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let item = dataSource?.itemIdentifier(for: indexPath),
              case .ingredient(let ingredient) = item else { return [] }
        let itemProvider = NSItemProvider(object: ingredient.id.uuidString as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = ingredient
        return [dragItem]
    }
}

extension DraggableIngredientViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: any UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let draggedIngredient = coordinator.items.first?.dragItem.localObject as? RecipeIngredient,
              let destinationSection = Section(rawValue: destinationIndexPath.section) else { return }
        
        // Don't allow drops in instruction section
        guard destinationSection != .instruction else { return }
        
        // Remove from current location
        if let matchedIndex = matchedIngredients.firstIndex(of: draggedIngredient) {
            matchedIngredients.remove(at: matchedIndex)
        }
        
        // Insert at new location
        switch destinationSection {
        case .instruction:
            break
        case .linked:
            let insertIndex = min(destinationIndexPath.item, matchedIngredients.count)
            matchedIngredients.insert(draggedIngredient, at: insertIndex)
        case .notLinked:
            // Just remove from matched, keep in allIngredients
            break
        }
        
        onUpdate(allIngredients, matchedIngredients)
        applySnapshot()
    }
}
