import XCTest
@testable import AITestScout

/// Tests for ExplorationStep AI prompt/response capture functionality
@available(macOS 26.0, iOS 26.0, *)
final class ExplorationStepAIDataTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitializationWithAIData() {
        // Arrange
        let prompt = "Test prompt sent to AI"
        let response = #"{"choice": 1, "reasoning": "Test reasoning", "confidence": 85}"#

        // Act
        let step = ExplorationStep(
            action: "tap",
            targetElement: "testButton",
            textTyped: nil,
            screenDescription: "Test screen",
            interactiveElementCount: 5,
            reasoning: "Test reasoning",
            confidence: 85,
            aiPrompt: prompt,
            aiResponse: response
        )

        // Assert
        XCTAssertEqual(step.aiPrompt, prompt)
        XCTAssertEqual(step.aiResponse, response)
        XCTAssertEqual(step.action, "tap")
        XCTAssertEqual(step.targetElement, "testButton")
    }

    func testLongAIPrompt() {
        // Arrange - Create a realistic long prompt (5KB+)
        var hierarchyJSON = ""
        for i in 1...100 {
            hierarchyJSON += #"{"type":"button","id":"btn\#(i)"},"#
        }
        let prompt = """
        iOS app crawler. Goal: Explore systematically

        AVAILABLE ACTIONS:
        1. Tap button1
        2. Tap button2
        \(hierarchyJSON)
        """
        let response = #"{"choice": 1, "reasoning": "Tapping first button", "confidence": 90}"#

        // Act
        let step = ExplorationStep(
            action: "tap",
            targetElement: "button1",
            textTyped: nil,
            screenDescription: "Button screen",
            interactiveElementCount: 100,
            reasoning: "Tapping first button",
            confidence: 90,
            aiPrompt: prompt,
            aiResponse: response
        )

        // Assert
        XCTAssertGreaterThan(step.aiPrompt.count, 3000) // > 3KB is sufficient for testing
        XCTAssertEqual(step.aiPrompt, prompt) // No truncation
        XCTAssertEqual(step.aiResponse, response)
    }

    // MARK: - Factory Method Tests

    func testFactoryMethodWithAIData() {
        // Arrange
        let decision = ExplorationDecision(
            action: "type",
            targetElement: "emailField",
            reasoning: "Entering email for login",
            successProbability: SuccessProbability(value: 0.95, reasoning: "High confidence"),
            textToType: "test@example.com"
        )

        let hierarchy = CompressedHierarchy(
            elements: [
                MinimalElement(type: .input, id: "emailField", label: "Email", interactive: true, children: [])
            ],
            screenshot: Data(),
            screenType: .login
        )

        let prompt = "Test prompt for login"
        let response = #"{"choice": 2, "reasoning": "Entering email for login", "confidence": 95}"#

        // Act
        let step = ExplorationStep.from(
            decision: decision,
            hierarchy: hierarchy,
            wasSuccessful: true,
            aiPrompt: prompt,
            aiResponse: response
        )

        // Assert
        XCTAssertEqual(step.aiPrompt, prompt)
        XCTAssertEqual(step.aiResponse, response)
        XCTAssertEqual(step.action, "type")
        XCTAssertEqual(step.targetElement, "emailField")
        XCTAssertEqual(step.textTyped, "test@example.com")
    }

    // MARK: - Codable Tests

    func testCodableWithAIData() throws {
        // Arrange
        let original = ExplorationStep(
            action: "tap",
            targetElement: "submitButton",
            textTyped: nil,
            screenDescription: "Login screen",
            interactiveElementCount: 3,
            reasoning: "Submitting login form",
            confidence: 88,
            aiPrompt: "Complete prompt with \n newlines and \"quotes\"",
            aiResponse: #"{"choice": 3, "reasoning": "Submit", "confidence": 88}"#
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ExplorationStep.self, from: data)

        // Assert
        XCTAssertEqual(decoded.aiPrompt, original.aiPrompt)
        XCTAssertEqual(decoded.aiResponse, original.aiResponse)
        XCTAssertEqual(decoded.action, original.action)
        XCTAssertEqual(decoded.targetElement, original.targetElement)
        XCTAssertEqual(decoded.reasoning, original.reasoning)
    }

    func testJSONStructure() throws {
        // Arrange
        let step = ExplorationStep(
            action: "swipe",
            targetElement: nil,
            textTyped: nil,
            screenDescription: "Scrollable list",
            interactiveElementCount: 20,
            reasoning: "Scrolling for more content",
            confidence: 75,
            aiPrompt: "Prompt for scroll action",
            aiResponse: #"{"choice": 15, "reasoning": "Scrolling", "confidence": 75}"#
        )

        // Act
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(step)
        let jsonString = String(data: data, encoding: .utf8)!

        // Assert
        XCTAssertTrue(jsonString.contains("aiPrompt"))
        XCTAssertTrue(jsonString.contains("aiResponse"))
        XCTAssertTrue(jsonString.contains("Prompt for scroll action"))
        XCTAssertTrue(jsonString.contains("Scrolling"))
    }

    // MARK: - Equatable Tests

    func testEquality() {
        // Arrange
        let step1 = ExplorationStep(
            id: UUID(),
            timestamp: Date(),
            action: "tap",
            targetElement: "button",
            textTyped: nil,
            screenDescription: "Screen",
            interactiveElementCount: 5,
            reasoning: "Reason",
            confidence: 80,
            aiPrompt: "Prompt A",
            aiResponse: "Response A"
        )

        let step2 = ExplorationStep(
            id: step1.id, // Same ID
            timestamp: step1.timestamp,
            action: "tap",
            targetElement: "button",
            textTyped: nil,
            screenDescription: "Screen",
            interactiveElementCount: 5,
            reasoning: "Reason",
            confidence: 80,
            aiPrompt: "Prompt A",
            aiResponse: "Response A"
        )

        let step3 = ExplorationStep(
            id: step1.id,
            timestamp: step1.timestamp,
            action: "tap",
            targetElement: "button",
            textTyped: nil,
            screenDescription: "Screen",
            interactiveElementCount: 5,
            reasoning: "Reason",
            confidence: 80,
            aiPrompt: "Different Prompt",
            aiResponse: "Different Response"
        )

        // Assert
        XCTAssertEqual(step1, step2) // Same AI data
        XCTAssertNotEqual(step1, step3) // Different AI data
    }
}
