import Foundation

/// Errors that can occur during AI crawling
public enum CrawlerError: Error, LocalizedError {
    case modelUnavailable
    case invalidHierarchy
    case guardRailsBlocked
    case invalidDecision

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Foundation Models not available. Requires iOS 26+ and Apple Silicon."
        case .invalidHierarchy:
            return "Could not convert hierarchy to valid JSON."
        case .guardRailsBlocked:
            return "AI guardrails blocked the request."
        case .invalidDecision:
            return "AI returned an invalid decision."
        }
    }
}
