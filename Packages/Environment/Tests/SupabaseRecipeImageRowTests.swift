import Foundation
import Persistence
import Testing
@testable import Environment

@Test func supabaseRecipeImageRowKeepsImageBytesOutOfRemoteRow() {
    let recipeId = UUID()
    let thumbnailData = Data([0x01, 0x02, 0x03])
    let localImage = DBRecipeImage(
        recipeId: recipeId,
        imageSourceUrl: "https://example.com/social-cover.jpg",
        imageData: thumbnailData
    )

    let remoteRow = SupabaseRecipeImageRow(localImage)
    let roundTripped = remoteRow.localRow()

    #expect(roundTripped.recipeId == recipeId)
    #expect(roundTripped.imageSourceUrl == "https://example.com/social-cover.jpg")
    #expect(roundTripped.imageData == nil)
}

@Test func urlOnlySupabaseRecipeImageRowPreservesExistingThumbnailData() {
    let recipeId = UUID()
    let existingData = Data([0x0A, 0x0B, 0x0C])
    let existing = DBRecipeImage(
        recipeId: recipeId,
        imageSourceUrl: "https://old.example.com/social-cover.jpg",
        imageData: existingData
    )
    let remote = DBRecipeImage(
        recipeId: recipeId,
        imageSourceUrl: "https://new.example.com/social-cover.jpg",
        imageData: nil
    )

    let merged = SupabaseRecipeImageRow(remote).localRow(preservingImageDataFrom: existing)

    #expect(merged.recipeId == recipeId)
    #expect(merged.imageSourceUrl == "https://new.example.com/social-cover.jpg")
    #expect(merged.imageData == existingData)
}
