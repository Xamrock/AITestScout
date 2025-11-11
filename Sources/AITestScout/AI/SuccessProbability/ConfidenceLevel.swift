import Foundation
import FoundationModels

/// Represents the confidence level of a success probability
@available(macOS 26.0, iOS 26.0, *)
public enum ConfidenceLevel: String, Codable, Sendable, Comparable, CustomStringConvertible {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"

    public var description: String {
        switch self {
        case .veryLow: return "Very Low Confidence (0-20%)"
        case .low: return "Low Confidence (20-40%)"
        case .medium: return "Medium Confidence (40-60%)"
        case .high: return "High Confidence (60-80%)"
        case .veryHigh: return "Very High Confidence (80-100%)"
        }
    }

    /// Compare confidence levels for ordering
    public static func < (lhs: ConfidenceLevel, rhs: ConfidenceLevel) -> Bool {
        let order: [ConfidenceLevel] = [.veryLow, .low, .medium, .high, .veryHigh]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}
