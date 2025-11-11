import Foundation
import FoundationModels

/// Represents the probability that an action will succeed
///
/// This type encapsulates a probability value (0.0-1.0) along with reasoning
/// that explains why the AI model assigned this probability. This helps with:
/// - Debugging exploration decisions
/// - Understanding AI confidence levels
/// - Prioritizing high-confidence actions
/// - Providing fallback strategies when confidence is low
///
/// **Usage:**
/// ```swift
/// let prob = SuccessProbability(
///     value: 0.85,
///     reasoning: "Button is visible, enabled, and matches user intent"
/// )
///
/// if prob.confidenceLevel == .high {
///     // Proceed with high confidence
/// }
/// ```
@available(macOS 26.0, iOS 26.0, *)
@Generable
public struct SuccessProbability: Codable, Sendable, Equatable {
    /// The probability value (0.0 = impossible, 1.0 = certain)
    /// Values are automatically clamped to the valid range
    @Guide(description: "Probability of success from 0.0 (impossible) to 1.0 (certain)")
    public let value: Double

    /// Human-readable reasoning explaining the probability assessment
    @Guide(description: "Detailed explanation of why this probability was assigned")
    public let reasoning: String

    /// The confidence level derived from the probability value
    public var confidenceLevel: ConfidenceLevel {
        switch value {
        case 0.0..<0.2:
            return .veryLow
        case 0.2..<0.4:
            return .low
        case 0.4..<0.6:
            return .medium
        case 0.6..<0.8:
            return .high
        case 0.8...1.0:
            return .veryHigh
        default:
            return .medium // Fallback (shouldn't happen due to clamping)
        }
    }

    /// Initialize with a probability value and reasoning
    ///
    /// - Parameters:
    ///   - value: Probability from 0.0-1.0 (will be clamped if out of range)
    ///   - reasoning: Explanation of why this probability was assigned
    public init(value: Double, reasoning: String) {
        // Clamp to valid probability range [0.0, 1.0]
        self.value = min(max(value, 0.0), 1.0)
        self.reasoning = reasoning
    }

    // MARK: - Factory Methods

    /// Create a success probability representing certainty (1.0)
    ///
    /// - Parameter reasoning: Explanation of why success is certain
    /// - Returns: SuccessProbability with value 1.0
    public static func certain(reasoning: String) -> SuccessProbability {
        return SuccessProbability(value: 1.0, reasoning: reasoning)
    }

    /// Create a success probability representing unlikelihood (0.2)
    ///
    /// - Parameter reasoning: Explanation of why success is unlikely
    /// - Returns: SuccessProbability with value 0.2
    public static func unlikely(reasoning: String) -> SuccessProbability {
        return SuccessProbability(value: 0.2, reasoning: reasoning)
    }

    /// Create a success probability representing moderate confidence (0.5)
    ///
    /// - Parameter reasoning: Explanation of moderate confidence
    /// - Returns: SuccessProbability with value 0.5
    public static func moderate(reasoning: String) -> SuccessProbability {
        return SuccessProbability(value: 0.5, reasoning: reasoning)
    }
}
