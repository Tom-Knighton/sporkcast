import Testing
import API
@testable import RecipeImporting

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test func customerFacingMessageHidesForbiddenStatus() {
    let message = RecipeImportError.customerFacingMessage(
        for: APIClient.ClientError.httpError(statusCode: 403, message: nil)
    )

    #expect(message == "We couldn't access that recipe page. Some sites block imports, so try copying the recipe text instead.")
    #expect(message.contains("403") == false)
}

@Test func customerFacingMessageHidesBackendExceptionMessage() {
    let message = RecipeImportError.customerFacingMessage(
        for: APIClient.ClientError.httpError(statusCode: 500, message: "System.NullReferenceException")
    )

    #expect(message == "Recipe import is having trouble right now. Please try again in a bit.")
    #expect(message.contains("Exception") == false)
}
