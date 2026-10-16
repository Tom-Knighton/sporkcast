import Foundation
import FoundationModels

@MainActor
struct RecipeIntelligence {
    let cloudEnabled: Bool

    init(cloudEnabled: Bool = false) {
        self.cloudEnabled = cloudEnabled
    }

    @available(iOS 27, *)
    private var cloudModel: PrivateCloudComputeLanguageModel? {
#if !targetEnvironment(simulator)
        guard cloudEnabled else { return nil }
        return PrivateCloudComputeLanguageModel()
#else
        // Availability can report success without the entitlement, then terminate the process on use.
        return nil
#endif
    }

    var isAvailable: Bool {
        if #available(iOS 27, *), let cloud = cloudModel {
            if cloud.isAvailable && !cloud.quotaUsage.isLimitReached { return true }
        }
        return SystemLanguageModel.default.isAvailable
    }

    var availabilityDescription: String {
        if #available(iOS 27, *), let cloud = cloudModel {
            if cloud.isAvailable {
                if cloud.quotaUsage.isLimitReached {
                    return SystemLanguageModel.default.isAvailable
                        ? "On device · Cloud daily limit reached"
                        : "Cloud daily limit reached. Try again after your quota resets."
                }
                return "Private Cloud Compute · On-device fallback"
            }
        }
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Apple Intelligence · On device"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to ask about this recipe."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is getting ready. Try again once the model has downloaded."
        default:
            return "Recipe chat needs a device that supports Apple Intelligence."
        }
    }

    func respond<Response: Generable>(
        generating type: Response.Type,
        instructions: String,
        prompt: (Bool) -> String,
        onRoute: (String) -> Void = { _ in }
    ) async throws -> Response {
        if #available(iOS 27, *), let cloud = cloudModel {
            if cloud.isAvailable && !cloud.quotaUsage.isLimitReached {
                if case .belowLimit(let usage) = cloud.quotaUsage.status, usage.isApproachingLimit {
                    onRoute("Private Cloud Compute · Near daily limit")
                } else {
                    onRoute("Private Cloud Compute")
                }
                do {
                    let session = LanguageModelSession(model: cloud, instructions: instructions)
                    let response = try await session.respond(
                        to: prompt(true), generating: type, options: .init(temperature: 0.2)
                    )
                    try Task.checkCancellation()
                    return response.content
                } catch {
                    if error is CancellationError { throw error }
                    try Task.checkCancellation()
                    if let error = error as? LanguageModelError {
                        switch error {
                        case .guardrailViolation, .refusal: throw error
                        default: break
                        }
                    }
                    guard SystemLanguageModel.default.isAvailable else { throw error }
                    if case PrivateCloudComputeLanguageModel.Error.quotaLimitReached = error {
                        onRoute("On device · Cloud daily limit reached")
                    } else {
                        onRoute("On device · Cloud unavailable")
                    }
                }
            } else {
                onRoute(cloud.quotaUsage.isLimitReached ? "On device · Cloud daily limit reached" : "Apple Intelligence · On device")
            }
        } else {
            onRoute("Apple Intelligence · On device")
        }
        try Task.checkCancellation()
        guard SystemLanguageModel.default.isAvailable else {
            throw AppleIntelligenceError.unavailable(availabilityDescription)
        }
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: prompt(false), generating: type, options: .init(temperature: 0.2)
        )
        try Task.checkCancellation()
        return response.content
    }
}
