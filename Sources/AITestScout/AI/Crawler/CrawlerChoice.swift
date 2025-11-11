import Foundation
import FoundationModels

/// Represents the AI's choice from a multiple choice list
@available(macOS 26.0, iOS 26.0, *)
@Generable
public struct CrawlerChoice: Codable {
    /// The number of the chosen action (1-based index from the choice list)
    @Guide(description: "The number of the action you want to perform (e.g., 1, 2, 3, etc.). MUST be a valid choice number from the list.")
    public let choice: Int

    /// Your reasoning for choosing this action
    @Guide(description: "Brief explanation of why you chose this action (1-2 sentences)")
    public let reasoning: String

    /// Confidence level 0-100 representing certainty in this choice
    @Guide(description: "Your confidence in this choice from 0 (uncertain) to 100 (very confident)")
    public let confidence: Int

    public init(choice: Int, reasoning: String, confidence: Int) {
        self.choice = choice
        self.reasoning = reasoning
        self.confidence = confidence
    }
}
