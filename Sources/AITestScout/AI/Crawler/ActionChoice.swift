import Foundation
import FoundationModels

/// Represents a possible action the AI can choose from
public struct ActionChoice {
    /// The 1-based index of this choice
    public let number: Int

    /// The action type (tap, type, swipe, done)
    public let action: String

    /// The target element (for tap/type actions)
    public let targetElement: String?

    /// The text to type (for type actions)
    public let textToType: String?

    /// Human-readable description of this action
    public let description: String

    /// Priority of this action (for sorting/display)
    public let priority: Int

    /// Intent of this action (submit, cancel, navigation, etc.)
    public let intent: String?

    public init(
        number: Int,
        action: String,
        targetElement: String?,
        textToType: String?,
        description: String,
        priority: Int,
        intent: String?
    ) {
        self.number = number
        self.targetElement = targetElement
        self.action = action
        self.textToType = textToType
        self.description = description
        self.priority = priority
        self.intent = intent
    }

    /// Formats this choice for display in a multiple choice prompt
    public func formatForPrompt() -> String {
        var formatted = "\(number). "

        // Add priority indicator for high/low priority items
        if priority >= 100 {
            formatted += "⭐️ "
        } else if priority <= 25 {
            formatted += "⚠️  "
        }

        formatted += description

        // Add metadata hints
        var hints: [String] = []
        if let intent = intent {
            hints.append(intent)
        }
        hints.append("priority: \(priority)")

        if !hints.isEmpty {
            formatted += " [\(hints.joined(separator: ", "))]"
        }

        return formatted
    }
}
