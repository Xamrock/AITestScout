import Foundation

/// Result of verifying an action's expected outcome
@available(macOS 26.0, iOS 26.0, *)
public struct VerificationResult: Sendable, Codable, Equatable {
    /// Whether the verification passed
    public let passed: Bool

    /// Human-readable explanation of the verification result
    public let reason: String

    /// Whether the screen changed between before and after hierarchies
    public let screenChanged: Bool

    /// Whether the expected element was found (nil if not applicable)
    public let expectedElementFound: Bool?

    public init(passed: Bool, reason: String, screenChanged: Bool, expectedElementFound: Bool? = nil) {
        self.passed = passed
        self.reason = reason
        self.screenChanged = screenChanged
        self.expectedElementFound = expectedElementFound
    }
}
