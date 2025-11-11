import Foundation
import FoundationModels

/// An AI exploration decision with success probability tracking
///
/// This is the canonical decision type for AITestScout. It includes:
/// - Success probability: How likely is this action to succeed?
/// - Expected outcome: What should happen if this action succeeds?
/// - Alternative actions: What other actions could achieve similar goals?
/// - Text to type: For 'type' actions, the text to enter
///
/// The @Generable conformance allows Apple's Foundation Models to generate
/// these decisions directly from prompts, with proper guidance through @Guide.
///
/// **Usage:**
/// ```swift
/// let session = LanguageModelSession()
/// let decision = try await session.respond(
///     to: "Decide next action for login flow",
///     generating: ExplorationDecision.self
/// )
///
/// if decision.successProbability.confidenceLevel >= .high {
///     // Execute high-confidence action
///     executeAction(decision)
/// } else {
///     // Try alternative or ask for user guidance
///     considerAlternatives(decision.alternativeActions)
/// }
/// ```
@available(macOS 26.0, iOS 26.0, *)
@Generable
public struct ExplorationDecision: Codable, Sendable {
    /// The action to perform (e.g., "tap", "type", "swipe", "done")
    @Guide(description: "The action to take: 'tap' to interact, 'type' to enter text, 'swipe' to scroll, or 'done' if exploration complete")
    public let action: String

    /// The accessibility identifier or element ID to act upon
    @Guide(description: "The accessibility identifier or unique ID of the UI element to interact with. Required for 'tap' and 'type' actions, null for 'swipe' and 'done'.")
    public let targetElement: String?

    /// Human-readable explanation of why this action was chosen
    @Guide(description: "Step-by-step reasoning explaining why this action advances toward the exploration goal")
    public let reasoning: String

    /// Probability that this action will succeed
    @Guide(description: "Assessment of how likely this action is to succeed (0.0-1.0), with detailed reasoning")
    public let successProbability: SuccessProbability

    /// Text to type into an input field (only for 'type' action)
    @Guide(description: "Text to type into the field. Only provide when action is 'type', otherwise null")
    public let textToType: String?

    /// Expected outcome if the action succeeds
    @Guide(description: "Description of the expected state or screen after this action completes successfully")
    public let expectedOutcome: String?

    /// Alternative actions that could achieve similar goals
    @Guide(description: "List of alternative actions that could be tried if this action fails or has low confidence (e.g. ['swipe', 'tap_back', 'done'])")
    public let alternativeActions: [String]

    /// Initialize an exploration decision
    ///
    /// - Parameters:
    ///   - action: The action to perform
    ///   - targetElement: The element to act upon (optional for swipe/done)
    ///   - reasoning: Why this action was chosen
    ///   - successProbability: Probability of success with reasoning
    ///   - textToType: Text to type (for type action)
    ///   - expectedOutcome: Expected result (optional)
    ///   - alternativeActions: Alternative actions to try (default: empty)
    public init(
        action: String,
        targetElement: String? = nil,
        reasoning: String,
        successProbability: SuccessProbability,
        textToType: String? = nil,
        expectedOutcome: String? = nil,
        alternativeActions: [String] = []
    ) {
        self.action = action
        self.targetElement = targetElement
        self.reasoning = reasoning
        self.successProbability = successProbability
        self.textToType = textToType
        self.expectedOutcome = expectedOutcome
        self.alternativeActions = alternativeActions
    }

    /// Confidence score (0-100) derived from success probability
    public var confidence: Int {
        return Int(successProbability.value * 100)
    }
}
