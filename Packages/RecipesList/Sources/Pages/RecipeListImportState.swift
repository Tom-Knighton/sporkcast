//
//  RecipeListImportState.swift
//  RecipesList
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import RecipeImporting
import UniformTypeIdentifiers

struct RecipeListImportState {
    var isAddRecipeSheetPresented = false
    var isURLAddSheetPresented = false
    var isImportStatusSheetPresented = false

    var isImportAppSelectionPresented = false
    var isFileImporterPresented = false
    var isMarkdownImportPresented = false
    var isWebSelectionImportPresented = false
    var isOCRImportPresented = false

    var isSelectionSheetPresented = false
    var isDuplicateResolutionPresented = false

    var webURLInput = ""
    var markdownInput = ""
    var webSelectionInput = ""

    var importStartedAt: Date = .now
    var importStatusTitle: String?
    var importStatusSubtitle: String?
    var importFailureMessage: String?
    var activeImportSource: RecipeImportSource?
    var selectedImportAppSource: ImportAppSource?

    var preparedCandidates: [RecipeImportCandidate] = []
    var selectedCandidateIDs: Set<UUID> = []
    var duplicateMatches: [UUID: DuplicateMatch] = [:]

    var fileImporterContentTypes: [UTType] {
        selectedImportAppSource?.allowedContentTypes ?? [.json, .zip]
    }

    var selectedFileVendorHint: RecipeImportVendor? {
        selectedImportAppSource?.vendorHint
    }

    mutating func beginImport(from source: RecipeImportSource) {
        activeImportSource = source
        importFailureMessage = nil
        importStartedAt = .now
        importStatusTitle = nil
        importStatusSubtitle = nil
        isImportStatusSheetPresented = true
        isSelectionSheetPresented = false
        isDuplicateResolutionPresented = false
    }

    mutating func presentFailure(_ message: String) {
        importFailureMessage = message
    }

    mutating func clearFailure() {
        importFailureMessage = nil
    }

    mutating func beginPersisting(recipesCount: Int) {
        importStartedAt = .now
        importFailureMessage = nil
        importStatusTitle = recipesCount == 1 ? "Saving your recipe" : "Saving \(recipesCount) recipes"
        importStatusSubtitle = "Images from social links will continue syncing in the background."
        isImportStatusSheetPresented = true
    }

    mutating func closeImportStatus() {
        isImportStatusSheetPresented = false
        importStatusTitle = nil
        importStatusSubtitle = nil
        importFailureMessage = nil
    }

    mutating func beginFileImport(for source: ImportAppSource) {
        selectedImportAppSource = source
        isFileImporterPresented = true
    }

    mutating func clearSelectedImportAppSource() {
        selectedImportAppSource = nil
    }

    mutating func prepareSelection(with candidates: [RecipeImportCandidate]) {
        preparedCandidates = candidates
        selectedCandidateIDs = Set(candidates.map(\.id))
        isSelectionSheetPresented = true
    }

    mutating func prepareDuplicateResolution(
        candidates: [RecipeImportCandidate],
        duplicates: [UUID: DuplicateMatch]
    ) {
        preparedCandidates = candidates
        duplicateMatches = duplicates
        isDuplicateResolutionPresented = true
    }

    mutating func clearImportArtifactsAfterSuccess() {
        isSelectionSheetPresented = false
        isDuplicateResolutionPresented = false
        webURLInput = ""
        markdownInput = ""
        webSelectionInput = ""
        activeImportSource = nil
        selectedImportAppSource = nil
        preparedCandidates = []
        selectedCandidateIDs = []
        duplicateMatches = [:]
    }
}
