import Foundation
import OSLog

public enum RecipeImportPerformance {
    private static let logger = Logger(subsystem: "online.tomk.sporkcast", category: "RecipeImportPerformance")

    public static func record(_ stage: String, since start: TimeInterval) {
        let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
        logger.info("Import stage \(stage, privacy: .public): \(milliseconds, format: .fixed(precision: 1))ms")
    }
}
