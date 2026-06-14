//
//  CustomerFacingErrorMessage.swift
//  Environment
//

import Foundation

public enum CustomerFacingErrorMessage {
    public static func message(
        for error: Error,
        fallback: String = "Something went wrong. Please try again."
    ) -> String {
        if error is CancellationError {
            return fallback
        }

        if error is URLError {
            return "We couldn't connect. Check your internet connection and try again."
        }

        return fallback
    }

    public static func syncFallback(
        _ fallback: String = "We couldn't sync your changes right now. Please try again."
    ) -> String {
        fallback
    }
}
