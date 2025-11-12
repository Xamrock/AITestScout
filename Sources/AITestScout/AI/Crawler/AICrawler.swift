import Foundation
import FoundationModels

/// AI-powered autonomous UI crawler using Apple Foundation Models
@available(macOS 26.0, iOS 26.0, *)
@MainActor
public class AICrawler {
    private let session: LanguageModelSession
    private let maxTokens: Int

    /// The exploration path tracking all steps taken
    nonisolated(unsafe) public private(set) var explorationPath: ExplorationPath?

    /// The navigation graph tracking screen transitions
    nonisolated(unsafe) public private(set) var navigationGraph: NavigationGraph

    /// The fingerprint of the current screen
    private var currentScreenFingerprint: String?

    /// Track actions attempted on the current screen
    private var actionsOnCurrentScreen: [String] = []

    /// Maximum actions to try on the same screen before suggesting "done"
    private let maxActionsPerScreen: Int = 3

    /// Optional delegate for observing crawler events and extending behavior
    nonisolated(unsafe) public weak var delegate: AICrawlerDelegate?

    /// Fixture resolver for generating test values
    private var fixtureResolver: FixtureResolver?

    /// Initialize the AI crawler
    /// - Parameters:
    ///   - maxTokens: Maximum tokens to send to the model (default: 3000, max: 4096)
    ///   - explorationPath: Optional path for tracking/persisting exploration history
    ///   - navigationGraph: Optional existing graph to resume from
    /// - Throws: Errors if Foundation Models not available or initialization fails
    public init(
        maxTokens: Int = 3000,
        explorationPath: ExplorationPath? = nil,
        navigationGraph: NavigationGraph? = nil
    ) async throws {
        self.maxTokens = min(maxTokens, 3000) // Leave more room for response (max context is 4096)
        self.session = LanguageModelSession()
        self.explorationPath = explorationPath
        self.navigationGraph = navigationGraph ?? NavigationGraph()

        // Prewarm the session for better performance
        session.prewarm()
    }

    /// Start a new exploration session with path tracking
    /// - Parameters:
    ///   - goal: The exploration goal
    ///   - persistenceURL: Optional URL to save exploration progress
    /// - Returns: A new ExplorationPath instance
    nonisolated public func startExploration(goal: String, persistenceURL: URL? = nil) -> ExplorationPath {
        let path = ExplorationPath(goal: goal, persistenceURL: persistenceURL)
        self.explorationPath = path
        return path
    }

    /// Load and resume an existing exploration session
    /// - Parameter url: File URL of saved exploration path
    /// - Throws: Errors if file cannot be loaded
    public func resumeExploration(from url: URL) throws {
        self.explorationPath = try ExplorationPath.load(from: url)
    }

    /// Set the test data fixture for value generation
    /// - Parameter fixture: Fixture to use for generating test values (nil = use defaults)
    public func setFixture(_ fixture: ExplorationFixture?) {
        self.fixtureResolver = FixtureResolver(fixture: fixture)
    }

    /// AI decision result containing the decision and AI interaction data
    public struct DecisionResult {
        public let decision: ExplorationDecision
        public let aiPrompt: String
        public let aiResponse: String
    }

    /// Ask the AI to decide the next action using multiple choice (more reliable)
    /// - Parameters:
    ///   - hierarchy: The captured screen hierarchy
    ///   - visited: Set of element identifiers/labels that have been interacted with
    ///   - goal: The exploration goal
    ///   - previousAction: The last action taken
    ///   - recordStep: Whether to automatically record this decision in the exploration path
    /// - Returns: DecisionResult containing the decision, AI prompt, and AI response
    /// - Throws: Various errors if the AI cannot make a decision
    public func decideNextActionWithChoices(
        hierarchy: CompressedHierarchy,
        visited: Set<String>? = nil,
        goal: String? = nil,
        previousAction: String? = nil,
        recordStep: Bool = true
    ) async throws -> DecisionResult {
        // Record screen visit in navigation graph
        let isNewScreen = recordScreenVisit(hierarchy)

        if isNewScreen {
            print("📍 New screen discovered! Fingerprint: \(hierarchy.fingerprint.prefix(8))...")
            actionsOnCurrentScreen = [] // Reset action counter for new screen
        } else {
            let visitCount = getVisitCount(for: hierarchy.fingerprint)
            print("🔄 Revisiting screen (visit #\(visitCount)): \(hierarchy.fingerprint.prefix(8))...")

            // Check if we're stuck (same screen, too many attempts)
            if actionsOnCurrentScreen.count >= maxActionsPerScreen {
                print("⚠️  Tried \(actionsOnCurrentScreen.count) actions on this screen with no progress")
                print("💡 Suggesting 'done' to avoid infinite loop")

                // Notify delegate of stuck detection
                delegate?.didDetectStuck(attemptCount: actionsOnCurrentScreen.count, screenFingerprint: hierarchy.fingerprint)

                let decision = ExplorationDecision(
                    action: "done",
                    targetElement: nil,
                    reasoning: "Tried \(actionsOnCurrentScreen.count) actions on this screen without progress. Moving on to avoid infinite loop.",
                    successProbability: SuccessProbability(value: 0.8, reasoning: "High confidence that we should move on to avoid loops")
                )

                let aiPrompt = "N/A - Stuck detection triggered"
                let aiResponse = #"{"reason": "Stuck on screen after \#(actionsOnCurrentScreen.count) attempts"}"#

                if recordStep, let path = explorationPath {
                    let step = ExplorationStep.from(
                        decision: decision,
                        hierarchy: hierarchy,
                        aiPrompt: aiPrompt,
                        aiResponse: aiResponse
                    )
                    path.addStep(step)
                }

                actionsOnCurrentScreen = [] // Reset for next screen
                return DecisionResult(decision: decision, aiPrompt: aiPrompt, aiResponse: aiResponse)
            }
        }

        // Check for empty hierarchy first (before building choices)
        guard !hierarchy.elements.isEmpty else {
            // Return a "done" decision for empty hierarchies
            let decision = ExplorationDecision(
                action: "done",
                targetElement: nil,
                reasoning: "No interactive elements found on screen. Marking exploration as complete.",
                successProbability: SuccessProbability(value: 1.0, reasoning: "Certain that exploration is complete with no elements")
            )

            let aiPrompt = "N/A - Empty hierarchy detected"
            let aiResponse = #"{"reason": "No interactive elements found on screen"}"#

            if recordStep, let path = explorationPath {
                let step = ExplorationStep.from(
                    decision: decision,
                    hierarchy: hierarchy,
                    aiPrompt: aiPrompt,
                    aiResponse: aiResponse
                )
                path.addStep(step)
            }

            return DecisionResult(decision: decision, aiPrompt: aiPrompt, aiResponse: aiResponse)
        }

        // Use exploration path if available
        let visitedSet = visited ?? explorationPath?.visitedElements ?? []
        let explorationGoal = goal ?? explorationPath?.goal ?? "Explore all screens systematically"
        let lastAction = previousAction ?? explorationPath?.lastAction

        // Build action choices from hierarchy
        let choices = try await buildActionChoices(from: hierarchy, visited: visitedSet, screenType: hierarchy.screenType)

        guard !choices.isEmpty else {
            // No valid choices - return done
            let decision = ExplorationDecision(
                action: "done",
                targetElement: nil,
                reasoning: "No valid actions available on this screen.",
                successProbability: SuccessProbability(value: 1.0, reasoning: "Certain there are no valid actions")
            )

            let aiPrompt = "N/A - No valid choices available"
            let aiResponse = #"{"reason": "No interactive elements qualified as valid choices"}"#

            if recordStep, let path = explorationPath {
                let step = ExplorationStep.from(
                    decision: decision,
                    hierarchy: hierarchy,
                    aiPrompt: aiPrompt,
                    aiResponse: aiResponse
                )
                path.addStep(step)
            }

            return DecisionResult(decision: decision, aiPrompt: aiPrompt, aiResponse: aiResponse)
        }

        // Notify delegate that decision is about to be made
        delegate?.willMakeDecision(hierarchy: hierarchy)

        // Build multiple choice prompt
        let navigationMap = explorationPath?.navigationMap(maxSteps: 5)
        let prompt = CrawlerPrompts.exploreAppWithChoices(
            choices: choices,
            visited: visitedSet,
            goal: explorationGoal,
            previousAction: lastAction,
            navigationMap: navigationMap,
            screenType: hierarchy.screenType?.rawValue
        )

        // Get AI choice with retry logic (returns tuple with prompt and response)
        let (choice, aiPrompt, aiResponse) = try await respondWithChoice(prompt: prompt, validChoiceCount: choices.count)

        // Convert choice to decision
        let decision = try convertChoiceToDecision(choice: choice, choices: choices)

        // Notify delegate of the decision
        delegate?.didMakeDecision(decision, hierarchy: hierarchy)

        // Track this action attempt
        if let targetElement = decision.targetElement {
            actionsOnCurrentScreen.append(targetElement)
        }

        // Record step in exploration path if enabled
        if recordStep, let path = explorationPath {
            let step = ExplorationStep.from(
                decision: decision,
                hierarchy: hierarchy,
                aiPrompt: aiPrompt,
                aiResponse: aiResponse
            )
            path.addStep(step)
        }

        return DecisionResult(decision: decision, aiPrompt: aiPrompt, aiResponse: aiResponse)
    }

    /// Ask the AI to decide the next action based on the current screen hierarchy
    /// - Parameters:
    ///   - hierarchy: The captured screen hierarchy
    ///   - visited: Set of element identifiers/labels that have been interacted with (deprecated: use explorationPath instead)
    ///   - goal: The exploration goal (default: systematic exploration)
    ///   - previousAction: The last action taken (deprecated: use explorationPath instead)
    ///   - recordStep: Whether to automatically record this decision in the exploration path
    /// - Returns: The AI's decision about what to do next
    /// - Throws: Various errors if the AI cannot make a decision
    public func decideNextAction(
        hierarchy: CompressedHierarchy,
        visited: Set<String>? = nil,
        goal: String? = nil,
        previousAction: String? = nil,
        recordStep: Bool = true
    ) async throws -> ExplorationDecision {
        // Use the more reliable multiple choice approach
        let result = try await decideNextActionWithChoices(
            hierarchy: hierarchy,
            visited: visited,
            goal: goal,
            previousAction: previousAction,
            recordStep: recordStep
        )
        return result.decision
    }

    /// Ask the AI to decide the next action with enhanced success probability tracking
    ///
    /// This method returns an EnhancedExplorationDecision that includes:
    /// - Success probability with confidence levels
    /// - Expected outcome for verification
    /// - Alternative actions for fallback strategies
    ///
    /// **Usage:**
    /// ```swift
    /// let decision = try await crawler.decideNextActionEnhanced(
    ///     hierarchy: hierarchy,
    ///     goal: "Complete registration"
    /// )
    ///
    /// if decision.successProbability.confidenceLevel >= .high {
    ///     // Execute with high confidence
    ///     executeAction(decision)
    /// } else {
    ///     // Consider alternatives
    ///     tryAlternatives(decision.alternativeActions)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - hierarchy: The captured screen hierarchy
    ///   - visited: Set of element identifiers/labels that have been interacted with
    ///   - goal: The exploration goal
    ///   - previousAction: The last action taken
    ///   - recordStep: Whether to automatically record this decision in the exploration path
    /// - Returns: Enhanced decision with success probability and alternatives
    /// - Throws: Various errors if the AI cannot make a decision
    public func decideNextActionEnhanced(
        hierarchy: CompressedHierarchy,
        visited: Set<String>? = nil,
        goal: String? = nil,
        previousAction: String? = nil,
        recordStep: Bool = true
    ) async throws -> ExplorationDecision {
        // For now, use the existing decision logic and upgrade to enhanced
        // In a future phase, we can add specialized prompts for enhanced decisions
        let result = try await decideNextActionWithChoices(
            hierarchy: hierarchy,
            visited: visited,
            goal: goal,
            previousAction: previousAction,
            recordStep: recordStep
        )
        let basicDecision = result.decision

        // Convert basic decision to enhanced with inferred probability
        let probability = inferSuccessProbability(from: basicDecision, hierarchy: hierarchy)

        return ExplorationDecision(
            action: basicDecision.action,
            targetElement: basicDecision.targetElement,
            reasoning: basicDecision.reasoning,
            successProbability: probability,
            textToType: basicDecision.textToType,
            expectedOutcome: inferExpectedOutcome(from: basicDecision, hierarchy: hierarchy),
            alternativeActions: inferAlternativeActions(from: basicDecision, hierarchy: hierarchy)
        )
    }

    // MARK: - Enhanced Decision Helpers

    /// Infer success probability from a basic decision
    private func inferSuccessProbability(
        from decision: ExplorationDecision,
        hierarchy: CompressedHierarchy
    ) -> SuccessProbability {
        // Convert confidence (0-100) to probability (0.0-1.0)
        let baseValue = Double(decision.confidence) / 100.0

        // Build reasoning based on decision context
        var reasoning = "Based on "

        if decision.confidence >= 80 {
            reasoning += "high confidence (\(decision.confidence)%)"
        } else if decision.confidence >= 60 {
            reasoning += "moderate confidence (\(decision.confidence)%)"
        } else {
            reasoning += "low confidence (\(decision.confidence)%)"
        }

        // Add context about action type
        if decision.action == "done" {
            reasoning += " and exploration completion"
        } else if let target = decision.targetElement {
            // Find element in hierarchy for additional context
            if let element = hierarchy.elements.first(where: { $0.id == target || $0.label == target }) {
                if element.interactive {
                    reasoning += " with interactive element '\(target)'"
                }
                if let intent = element.intent {
                    reasoning += " (intent: \(intent.rawValue))"
                }
            } else {
                reasoning += " with target '\(target)'"
            }
        }

        return SuccessProbability(value: baseValue, reasoning: reasoning)
    }

    /// Infer expected outcome from a basic decision
    private func inferExpectedOutcome(
        from decision: ExplorationDecision,
        hierarchy: CompressedHierarchy
    ) -> String? {
        guard decision.action != "done" else {
            return nil
        }

        // Try to infer outcome based on action and target
        if decision.action == "swipe" {
            return "More content should become visible"
        }

        if decision.action == "type", let text = decision.textToType {
            return "Field should contain '\(text)'"
        }

        if decision.action == "tap", let target = decision.targetElement {
            // Look for intent from hierarchy
            if let element = hierarchy.elements.first(where: { $0.id == target || $0.label == target }) {
                switch element.intent {
                case .submit:
                    return "Form submission or navigation to result screen"
                case .cancel:
                    return "Return to previous screen or clear form"
                case .navigation:
                    return "Navigate to different screen"
                case .destructive:
                    return "Item or data will be deleted or removed"
                case .neutral, .none:
                    break
                }
            }

            return "Screen state change or navigation after tapping '\(target)'"
        }

        return nil
    }

    /// Infer alternative actions from a basic decision
    private func inferAlternativeActions(
        from decision: ExplorationDecision,
        hierarchy: CompressedHierarchy
    ) -> [String] {
        var alternatives: [String] = []

        // Don't suggest alternatives for "done"
        guard decision.action != "done" else {
            return []
        }

        // If confidence is low, suggest more alternatives
        if decision.confidence < 60 {
            // Suggest swipe as alternative for low-confidence tap
            if decision.action == "tap" && !hierarchy.elements.isEmpty {
                alternatives.append("swipe")
            }

            // Suggest done as alternative if confidence is very low
            if decision.confidence < 40 {
                alternatives.append("done")
            }
        }

        // Suggest screen type-specific alternatives
        if let screenType = hierarchy.screenType {
            switch screenType {
            case .form, .login:
                if decision.action != "type" {
                    // Suggest filling fields as alternative
                    let emptyInputs = hierarchy.elements.filter {
                        $0.type == .input && ($0.value == nil || $0.value!.isEmpty)
                    }
                    if let firstInput = emptyInputs.first,
                       let inputId = firstInput.id ?? firstInput.label {
                        alternatives.append("type_\(inputId)")
                    }
                }
            case .list:
                if decision.action != "swipe" {
                    alternatives.append("swipe")
                }
            default:
                break
            }
        }

        // Always suggest at most 3 alternatives to keep it focused
        return Array(alternatives.prefix(3))
    }

    // MARK: - Multiple Choice Implementation

    /// Builds a list of valid action choices from the hierarchy
    private func buildActionChoices(
        from hierarchy: CompressedHierarchy,
        visited: Set<String>,
        screenType: ScreenType?
    ) async throws -> [ActionChoice] {
        var choices: [ActionChoice] = []
        var choiceNumber = 1

        // Sort elements by priority (highest first)
        let sortedElements = hierarchy.elements.sorted { el1, el2 in
            let priority1 = el1.priority ?? 0
            let priority2 = el2.priority ?? 0
            return priority1 > priority2
        }

        // Detect form screens and check completion status
        let isFormScreen = hierarchy.screenType == .form || hierarchy.screenType == .login
        let inputElements = hierarchy.elements.filter { $0.type == .input }
        let emptyInputs = inputElements.filter { $0.value == nil || $0.value!.isEmpty }
        let formComplete = isFormScreen && !inputElements.isEmpty && emptyInputs.isEmpty

        // Build choices for top elements (limit to 15 to keep prompt small)
        for element in sortedElements.prefix(15) {
            let elementId = element.id ?? element.label ?? "element\(choiceNumber)"
            let isVisited = visited.contains(elementId)

            // Also check if we've tried this element on the current screen
            let triedOnThisScreen = actionsOnCurrentScreen.contains(elementId)

            // Skip visited elements unless they're inputs (can be filled)
            if isVisited && element.type != .input {
                continue
            }

            // Skip elements we've already tried on this screen (likely failing)
            if triedOnThisScreen {
                print("⏭️  Skipping '\(elementId)' - already tried on this screen")
                continue
            }

            // Calculate dynamic priority based on state
            var adjustedPriority = element.priority ?? 50

            // Create appropriate choices based on element type
            if element.type == .input {
                // For inputs, offer to type
                let hasValue = element.value != nil && !element.value!.isEmpty
                let visitedMarker = isVisited ? " [visited]" : ""
                let valueInfo = hasValue ? " (current: \(element.value!))" : ""

                // Dynamic priority adjustment for inputs
                if hasValue {
                    // Filled inputs get STEEP penalty (75% reduction)
                    adjustedPriority = adjustedPriority / 4
                } else {
                    // Empty inputs get BOOST (25% increase)
                    adjustedPriority = Int(Double(adjustedPriority) * 1.25)
                }

                // Generate appropriate test text using fixture system
                let (testText, source) = try await generateTestTextFor(element: element, screenType: screenType)
                let description = "Type \"\(testText)\" into \(elementId)\(valueInfo)\(visitedMarker)"

                // Log value source for debugging
                if case .fixtureExact = source {
                    print("  💎 Using fixture value for '\(elementId)': \(testText)")
                }

                choices.append(ActionChoice(
                    number: choiceNumber,
                    action: "type",
                    targetElement: elementId,
                    textToType: testText,
                    description: description,
                    priority: adjustedPriority,
                    intent: element.intent?.rawValue
                ))
                choiceNumber += 1

            } else if element.interactive {
                // For other interactive elements, offer to tap
                let label = element.label ?? elementId
                let visitedMarker = isVisited ? " [visited]" : ""

                // Dynamic priority adjustments
                if element.intent == .submit && isFormScreen {
                    // Submit buttons on forms need completion logic
                    if formComplete {
                        // Form complete - BOOST submit button
                        adjustedPriority = Int(Double(adjustedPriority) * 1.3)
                    } else {
                        // Form incomplete - SUPPRESS submit button
                        adjustedPriority = adjustedPriority / 4
                    }
                }

                // Penalty for visited elements (50% reduction)
                if isVisited {
                    adjustedPriority = adjustedPriority / 2
                }

                let description = "Tap \(label)\(visitedMarker)"

                choices.append(ActionChoice(
                    number: choiceNumber,
                    action: "tap",
                    targetElement: elementId,
                    textToType: nil,
                    description: description,
                    priority: adjustedPriority,
                    intent: element.intent?.rawValue
                ))
                choiceNumber += 1
            }

            // Limit to 12 element-based choices
            if choices.count >= 12 {
                break
            }
        }

        // Conditionally add swipe option (only for scrollable screens)
        if shouldOfferSwipeOption(hierarchy: hierarchy) {
            // Dynamic swipe priority based on how many unvisited options remain
            let unvisitedCount = choices.filter { choice in
                if let target = choice.targetElement {
                    return !visited.contains(target)
                }
                return false
            }.count

            let swipePriority: Int
            if unvisitedCount < 2 {
                // Few options left - try scrolling for more content
                swipePriority = 130
            } else if hierarchy.screenType == .list {
                // List screen - moderate priority
                swipePriority = 80
            } else {
                // Regular screen - low priority
                swipePriority = 40
            }

            choices.append(ActionChoice(
                number: choiceNumber,
                action: "swipe",
                targetElement: nil,
                textToType: nil,
                description: "Swipe to see more content",
                priority: swipePriority,
                intent: nil
            ))
            choiceNumber += 1
        }

        // Always add done option
        choices.append(ActionChoice(
            number: choiceNumber,
            action: "done",
            targetElement: nil,
            textToType: nil,
            description: "Done exploring this screen",
            priority: 5,
            intent: nil
        ))

        // Log the choices being built for debugging
        print("\n🎲 Built \(choices.count) action choices:")
        for choice in choices {
            let priorityIndicator = choice.priority > 100 ? "⭐️" : choice.priority < 30 ? "⚠️ " : "  "
            print("  \(choice.number). \(priorityIndicator) [\(choice.priority)] \(choice.description)")
        }
        print()

        return choices
    }

    /// Determines whether swipe option should be offered based on screen characteristics
    private func shouldOfferSwipeOption(hierarchy: CompressedHierarchy) -> Bool {
        // Offer swipe for list screens (detected by semantic analysis)
        if hierarchy.screenType == .list {
            return true
        }

        // Offer swipe if there are scrollable elements
        let hasScrollableElements = hierarchy.elements.contains { element in
            element.type == .scrollable
        }
        if hasScrollableElements {
            return true
        }

        // Offer swipe if there are many elements (likely extends beyond viewport)
        // Use a threshold of 10+ elements as heuristic for scrollable content
        if hierarchy.elements.count > 10 {
            return true
        }

        return false
    }

    /// Converts an AI choice to an ExplorationDecision
    private func convertChoiceToDecision(choice: CrawlerChoice, choices: [ActionChoice]) throws -> ExplorationDecision {
        // Validate choice number
        guard choice.choice > 0 && choice.choice <= choices.count else {
            print("⚠️  Invalid choice number: \(choice.choice) (valid range: 1-\(choices.count))")
            throw CrawlerError.invalidDecision
        }

        let selectedAction = choices[choice.choice - 1]

        // Convert confidence (0-100) to probability (0.0-1.0)
        let probability = Double(choice.confidence) / 100.0

        return ExplorationDecision(
            action: selectedAction.action,
            targetElement: selectedAction.targetElement,
            reasoning: choice.reasoning,
            successProbability: SuccessProbability(
                value: probability,
                reasoning: "AI confidence: \(choice.confidence)%"
            ),
            textToType: selectedAction.textToType
        )
    }

    /// Respond to prompt with multiple choice selection
    /// Returns tuple of (choice, prompt, responseJSON)
    private func respondWithChoice(prompt: String, validChoiceCount: Int, maxRetries: Int = 2) async throws -> (choice: CrawlerChoice, prompt: String, responseJSON: String) {
        var lastError: Error?

        // Log the prompt being sent
        print("\n" + String(repeating: "=", count: 40))
        print("📝 PROMPT SENT TO AI (attempt 1/\(maxRetries)):")
        print(String(repeating: "=", count: 40))
        print(prompt)
        print(String(repeating: "=", count: 40))
        print("📊 Prompt stats: \(prompt.count) chars (~\(prompt.count/4) tokens)")
        print(String(repeating: "=", count: 40) + "\n")

        for attempt in 0..<maxRetries {
            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: CrawlerChoice.self
                )
                let choice = response.content

                // Validate choice is in valid range
                if choice.choice < 1 || choice.choice > validChoiceCount {
                    print("⚠️  AI returned invalid choice \(choice.choice) (valid: 1-\(validChoiceCount)), retrying...")
                    lastError = CrawlerError.invalidDecision
                    continue
                }

                // Serialize response to JSON
                let encoder = JSONEncoder()
                let responseData = try encoder.encode(choice)
                let responseJSON = String(data: responseData, encoding: .utf8) ?? "{}"

                // Log the AI response
                print("\n" + String(repeating: "=", count: 40))
                print("🤖 AI RESPONSE RECEIVED:")
                print(String(repeating: "=", count: 40))
                print("Choice: \(choice.choice)")
                print("Reasoning: \(choice.reasoning)")
                print("Confidence: \(choice.confidence)%")
                print(String(repeating: "=", count: 40) + "\n")

                return (choice, prompt, responseJSON)
            } catch let error as LanguageModelSession.GenerationError {
                if case .exceededContextWindowSize = error {
                    print("⚠️  Context window exceeded - this shouldn't happen with multiple choice")
                    // Fallback to "done" choice
                    let fallbackChoice = CrawlerChoice(
                        choice: validChoiceCount, // Last choice is always "done"
                        reasoning: "Context window exceeded, marking as done",
                        confidence: 0
                    )
                    let encoder = JSONEncoder()
                    let fallbackData = try encoder.encode(fallbackChoice)
                    let fallbackJSON = String(data: fallbackData, encoding: .utf8) ?? "{}"
                    return (fallbackChoice, prompt, fallbackJSON)
                }
                lastError = error

                // Exponential backoff
                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 500_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                }
            } catch {
                lastError = error

                // Exponential backoff
                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 500_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? CrawlerError.invalidDecision
    }

    /// Mark the last exploration step as failed
    /// - Parameter reason: Optional reason for the failure
    public func markLastStepFailed(reason: String? = nil) {
        explorationPath?.markLastStepFailed(reason: reason)
    }

    /// Find a specific feature in the app
    /// - Parameters:
    ///   - hierarchy: The current screen hierarchy
    ///   - target: Description of what to find
    /// - Returns: The AI's decision about what to do
    public func findFeature(
        hierarchy: CompressedHierarchy,
        target: String
    ) async throws -> ExplorationDecision {

        guard !hierarchy.elements.isEmpty else {
            return ExplorationDecision(
                action: "done",
                targetElement: nil,
                reasoning: "No elements found on screen. Cannot find target feature.",
                successProbability: SuccessProbability(value: 0.0, reasoning: "No elements to search")
            )
        }

        // Convert hierarchy to JSON (optimized: no screenshot, interactive only)
        let jsonData = try hierarchy.toJSON(includeScreenshot: false, interactiveOnly: true)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw CrawlerError.invalidHierarchy
        }

        let truncatedJSON = truncateIfNeeded(jsonString, maxTokens: maxTokens)
        let prompt = CrawlerPrompts.findFeature(
            hierarchy: truncatedJSON,
            target: target
        )

        let decision = try await respondWithRetry(prompt: prompt)
        try validate(decision)

        return decision
    }

    // MARK: - Private Helpers

    /// Respond to prompt with retry logic for robustness
    private func respondWithRetry(prompt: String, maxRetries: Int = 2) async throws -> ExplorationDecision {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: ExplorationDecision.self
                )
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                // Handle context window size exceeded
                if case .exceededContextWindowSize = error {
                    print("⚠️  Context window exceeded - hierarchy too large even after truncation")
                    // Return a swipe action to continue exploring
                    return ExplorationDecision(
                        action: "swipe",
                        targetElement: nil,
                        reasoning: "Unable to process full hierarchy due to size. Attempting to scroll to see more content.",
                        successProbability: SuccessProbability(value: 0.5, reasoning: "Medium confidence fallback due to size constraints")
                    )
                }
                lastError = error

                // On first failure, try with sanitized prompt
                if attempt == 0 {
                    let sanitizedPrompt = sanitizePrompt(prompt)
                    do {
                        let response = try await session.respond(
                            to: sanitizedPrompt,
                            generating: ExplorationDecision.self
                        )
                        return response.content
                    } catch {
                        lastError = error
                    }
                }

                // Exponential backoff before retry
                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 500_000_000) // 0.5s, 1s
                    try? await Task.sleep(nanoseconds: delay)
                }
            } catch {
                lastError = error

                // Exponential backoff before retry
                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 500_000_000) // 0.5s, 1s
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? CrawlerError.invalidDecision
    }

    /// Validate that the AI's decision is well-formed and actionable
    private func validate(_ decision: ExplorationDecision) throws {
        // Validate action is one of the allowed types
        let validActions = ["tap", "type", "swipe", "done"]
        guard validActions.contains(decision.action) else {
            print("⚠️  Invalid action: '\(decision.action)' - must be one of: \(validActions.joined(separator: ", "))")
            throw CrawlerError.invalidDecision
        }

        // Validate confidence is in valid range
        guard decision.confidence >= 0 && decision.confidence <= 100 else {
            print("⚠️  Invalid confidence: \(decision.confidence) - must be 0-100")
            throw CrawlerError.invalidDecision
        }

        // For tap and type actions, we need a target element
        if decision.action == "tap" || decision.action == "type" {
            guard let target = decision.targetElement, !target.isEmpty else {
                print("⚠️  Missing targetElement for '\(decision.action)' action")
                print("💡 Hint: AI should pick from available elements. Consider marking exploration as 'done' if no valid target.")
                throw CrawlerError.invalidDecision
            }
        }

        // For type action, we need text
        if decision.action == "type" {
            guard let text = decision.textToType, !text.isEmpty else {
                print("⚠️  Missing textToType for 'type' action")
                throw CrawlerError.invalidDecision
            }
        }

        // Reasoning should not be empty
        guard !decision.reasoning.isEmpty else {
            print("⚠️  Empty reasoning")
            throw CrawlerError.invalidDecision
        }
    }

    /// Truncate JSON to fit token limit while preserving important elements
    /// Uses semantic priority to keep the most important elements
    private func truncateIfNeeded(_ json: String, maxTokens: Int) -> String {
        // Rough estimate: 1 token ≈ 4 characters
        let maxChars = maxTokens * 4

        if json.count <= maxChars {
            return json
        }

        // Context window overflow detected - log details
        let originalTokens = json.count / 4
        print("\n⚠️  CONTEXT WINDOW OVERFLOW DETECTED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 Original Size: \(json.count) chars (~\(originalTokens) tokens)")
        print("🎯 Token Limit: \(maxTokens) tokens (\(maxChars) chars)")
        print("❗️ Overflow: ~\(originalTokens - maxTokens) tokens over limit")

        // Smart truncation: prioritize by semantic priority, then interactive elements
        // Parse JSON to identify elements
        guard let jsonData = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let elements = parsed["elements"] as? [[String: Any]] else {
            print("⚠️  Failed to parse JSON, using simple truncation")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            // Fallback: simple prefix truncation
            let truncated = String(json.prefix(maxChars - 50))
            return truncated + "\n... (content truncated to fit token limit)"
        }

        print("📦 Original Elements: \(elements.count)")

        // Sort elements by priority (highest first), then filter to top N
        let sortedElements = elements.sorted { el1, el2 in
            let priority1 = el1["priority"] as? Int ?? 0
            let priority2 = el2["priority"] as? Int ?? 0
            return priority1 > priority2
        }

        // Show top 5 elements being kept
        print("\n🔝 Top 5 Priority Elements:")
        for (index, element) in sortedElements.prefix(5).enumerated() {
            let priority = element["priority"] as? Int ?? 0
            let type = element["type"] as? String ?? "unknown"
            let id = element["id"] as? String
            let label = element["label"] as? String
            let intent = element["intent"] as? String

            let identifier = id ?? label ?? "no-id"
            let intentStr = intent.map { " [\($0)]" } ?? ""
            print("  \(index + 1). \(type) '\(identifier)' - priority: \(priority)\(intentStr)")
        }

        // Calculate optimal element count upfront to avoid multiple rebuilds
        // Estimate: ~150 chars per element on average, plus ~50 for JSON overhead
        let estimatedElementSize = 150
        let jsonOverhead = 50
        let targetElements = max(5, min(15, (maxChars - jsonOverhead) / estimatedElementSize))

        print("\n💡 Estimated optimal element count: \(targetElements) (based on token budget)")

        // Build JSON once with calculated element count
        var elementStrings = buildMinimalElementStrings(from: sortedElements.prefix(targetElements))
        var compactJSON = buildCompactJSON(elementStrings: elementStrings, screenType: parsed["screenType"] as? String)

        // If estimate was too optimistic, fall back one level (rare case)
        if compactJSON.count > maxChars && targetElements > 5 {
            let fallbackElements = max(5, targetElements - 5)
            print("⚠️  Estimate was high, trying \(fallbackElements) elements")
            elementStrings = buildMinimalElementStrings(from: sortedElements.prefix(fallbackElements))
            compactJSON = buildCompactJSON(elementStrings: elementStrings, screenType: parsed["screenType"] as? String)
        }

        let finalTokens = compactJSON.count / 4
        let severity = targetElements <= 5 ? "🚨" : targetElements <= 10 ? "⚠️ " : "✅"
        print("\n\(severity) Truncated to \(min(targetElements, sortedElements.count)) elements")
        print("📉 New Size: \(compactJSON.count) chars (~\(finalTokens) tokens)")
        print("💾 Saved: ~\(originalTokens - finalTokens) tokens (\(Int((1.0 - Double(finalTokens)/Double(originalTokens)) * 100))% reduction)")

        if compactJSON.count > maxChars {
            print("\n📋 Final JSON being sent to AI:")
            print("─────────────────────────────────────────────────────────────────────")
            print(compactJSON)
            print("─────────────────────────────────────────────────────────────────────")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        return compactJSON
    }

    /// Builds minimal JSON strings for elements (without children to save tokens)
    private func buildMinimalElementStrings<T: Sequence>(from elements: T) -> [String] where T.Element == [String: Any] {
        var elementStrings: [String] = []

        for element in elements {
            // Create minimal version without children to save space
            var minimal: [String: Any] = [:]
            minimal["type"] = element["type"]
            minimal["interactive"] = element["interactive"]

            if let id = element["id"] {
                minimal["id"] = id
            }
            if let label = element["label"] {
                minimal["label"] = label
            }
            if let value = element["value"] {
                minimal["value"] = value
            }
            if let intent = element["intent"] {
                minimal["intent"] = intent
            }
            if let priority = element["priority"] {
                minimal["priority"] = priority
            }
            // Omit children array to save tokens

            if let elementData = try? JSONSerialization.data(withJSONObject: minimal),
               let elementString = String(data: elementData, encoding: .utf8) {
                elementStrings.append(elementString)
            }
        }

        return elementStrings
    }

    /// Builds compact JSON from element strings
    private func buildCompactJSON(elementStrings: [String], screenType: String?) -> String {
        var json = "{\"elements\":["
        json += elementStrings.joined(separator: ",")
        json += "]"

        if let screenType = screenType {
            json += ",\"screenType\":\"\(screenType)\""
        }

        json += "}"
        return json
    }

    /// Sanitize prompt to avoid guardrail issues
    private func sanitizePrompt(_ prompt: String) -> String {
        // Remove potentially sensitive patterns that might trigger guardrails
        var sanitized = prompt

        // Replace common patterns that might trigger guardrails
        let replacements = [
            "password": "auth field",
            "Password": "Auth field",
            "login": "sign in",
            "Login": "Sign in",
            "credentials": "access info",
            "Credentials": "Access info"
        ]

        for (pattern, replacement) in replacements {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: replacement)
        }

        return sanitized
    }

    // MARK: - Screen Change Detection

    /// Check if the screen changed after an action
    /// - Parameter newHierarchy: The hierarchy after performing an action
    /// - Returns: True if screen changed, false if still on same screen
    public func didScreenChange(newHierarchy: CompressedHierarchy) -> Bool {
        guard let current = currentScreenFingerprint else {
            // First screen, treat as changed
            return true
        }
        return newHierarchy.fingerprint != current
    }

    /// Reset the action counter (call this when you manually navigate or want a fresh start)
    public func resetActionCounter() {
        actionsOnCurrentScreen = []
    }

    // MARK: - Navigation Graph Integration

    /// Record a screen visit in the navigation graph
    /// - Parameter hierarchy: The captured hierarchy
    /// - Returns: True if this is a new screen, false if revisiting
    @discardableResult
    private func recordScreenVisit(_ hierarchy: CompressedHierarchy) -> Bool {
        let screenNode = ScreenNode(
            fingerprint: hierarchy.fingerprint,
            screenType: hierarchy.screenType,
            elements: hierarchy.elements,
            screenshot: hierarchy.screenshot,
            depth: navigationGraph.nodes.count,
            parentFingerprint: currentScreenFingerprint
        )

        let isNew = navigationGraph.addNode(screenNode)

        // Notify delegate of screen discovery
        if isNew {
            delegate?.didDiscoverNewScreen(hierarchy.fingerprint, hierarchy: hierarchy)
        } else {
            let visitCount = getVisitCount(for: hierarchy.fingerprint)
            delegate?.didRevisitScreen(hierarchy.fingerprint, visitCount: visitCount)
        }

        // Update current screen
        let previousScreen = currentScreenFingerprint
        currentScreenFingerprint = hierarchy.fingerprint

        // If we came from another screen, record the transition
        if let previousScreen = previousScreen, previousScreen != hierarchy.fingerprint {
            // We'll record the transition when we know what action caused it
            // This is a placeholder - actual transition is recorded in recordTransition()
        }

        return isNew
    }

    /// Record a transition between screens
    /// - Parameters:
    ///   - fromFingerprint: Source screen fingerprint
    ///   - toFingerprint: Destination screen fingerprint
    ///   - decision: The decision that caused the transition
    ///   - duration: How long the transition took
    public func recordTransition(
        from fromFingerprint: String,
        to toFingerprint: String,
        decision: ExplorationDecision,
        duration: TimeInterval
    ) {
        let action = Action(
            type: ActionType(rawValue: decision.action) ?? .tap,
            targetElement: decision.targetElement,
            textTyped: decision.textToType,
            reasoning: decision.reasoning,
            confidence: decision.confidence
        )

        navigationGraph.addTransition(
            from: fromFingerprint,
            to: toFingerprint,
            action: action,
            duration: duration
        )

        // Notify delegate of transition
        delegate?.didRecordTransition(
            from: fromFingerprint,
            to: toFingerprint,
            action: action,
            duration: duration
        )
    }

    /// Check if the current navigation would create a cycle
    /// - Parameters:
    ///   - fromFingerprint: Source screen
    ///   - toFingerprint: Destination screen
    /// - Returns: True if this transition would create a cycle
    public func wouldCreateCycle(from fromFingerprint: String, to toFingerprint: String) -> Bool {
        return navigationGraph.wouldCreateCycle(from: fromFingerprint, to: toFingerprint)
    }

    /// Get visit count for a screen
    /// - Parameter fingerprint: Screen fingerprint
    /// - Returns: Number of times the screen has been visited
    public func getVisitCount(for fingerprint: String) -> Int {
        return navigationGraph.getVisitCount(for: fingerprint)
    }

    /// Export the navigation graph as JSON
    /// - Returns: JSON data of the graph
    /// - Throws: Encoding errors
    public func exportNavigationGraph() throws -> Data {
        return try navigationGraph.exportAsJSON()
    }

    /// Export the navigation graph as a Mermaid diagram
    /// - Returns: Mermaid diagram string
    public func exportNavigationGraphAsMermaid() -> String {
        return navigationGraph.exportAsMermaid()
    }

    /// Get coverage statistics for the exploration
    /// - Returns: Coverage stats including screens explored, edges, etc.
    public func getCoverageStats() -> CoverageStats {
        return navigationGraph.coverageStats()
    }

    // MARK: - Action Verification (Phase 3)

    /// Verify that an action achieved its expected outcome
    /// - Parameters:
    ///   - decision: The exploration decision that was executed
    ///   - beforeHierarchy: Screen hierarchy before the action
    ///   - afterHierarchy: Screen hierarchy after the action
    /// - Returns: VerificationResult indicating success or failure
    nonisolated public func verifyAction(
        decision: ExplorationDecision,
        beforeHierarchy: CompressedHierarchy,
        afterHierarchy: CompressedHierarchy
    ) -> VerificationResult {
        let verifier = ActionVerifier()
        return verifier.verify(
            decision: decision,
            beforeHierarchy: beforeHierarchy,
            afterHierarchy: afterHierarchy
        )
    }

    /// Convert an alternative action string to a full ExplorationDecision
    /// - Parameters:
    ///   - alternativeAction: Alternative action string (e.g., "swipe", "tap_backButton", "type_emailField")
    ///   - context: Current screen hierarchy for context
    /// - Returns: A new ExplorationDecision for the alternative action
    /// - Throws: CrawlerError if the alternative cannot be converted
    public func convertAlternativeToDecision(
        _ alternativeAction: String,
        context: CompressedHierarchy
    ) async throws -> ExplorationDecision {
        // Parse the alternative action format
        let components = alternativeAction.split(separator: "_", maxSplits: 1)
        let action = String(components[0])
        let targetElement = components.count > 1 ? String(components[1]) : nil

        // Handle different action types
        switch action.lowercased() {
        case "swipe":
            return ExplorationDecision(
                action: "swipe",
                targetElement: nil,
                reasoning: "Alternative action: swipe to reveal more content",
                successProbability: SuccessProbability(
                    value: 0.6,
                    reasoning: "Swipe as fallback - moderate confidence"
                ),
                expectedOutcome: "More content should become visible"
            )

        case "tap":
            guard let target = targetElement else {
                throw CrawlerError.invalidDecision
            }
            return ExplorationDecision(
                action: "tap",
                targetElement: target,
                reasoning: "Alternative action: tap '\(target)' as fallback",
                successProbability: SuccessProbability(
                    value: 0.7,
                    reasoning: "Tap alternative with specific target"
                ),
                expectedOutcome: "Screen state should change after tapping '\(target)'"
            )

        case "type":
            guard let target = targetElement else {
                throw CrawlerError.invalidDecision
            }
            // Find element in hierarchy to pass to resolver
            let element = context.elements.first(where: { $0.id == target || $0.label == target })
                ?? MinimalElement(type: .input, id: target, label: nil, interactive: true, children: [])

            // Generate appropriate test text using fixture system
            let (testText, _) = try await generateTestTextFor(element: element, screenType: context.screenType)
            return ExplorationDecision(
                action: "type",
                targetElement: target,
                reasoning: "Alternative action: type into '\(target)' as fallback",
                successProbability: SuccessProbability(
                    value: 0.7,
                    reasoning: "Type alternative with specific target"
                ),
                textToType: testText,
                expectedOutcome: "Field '\(target)' should contain '\(testText)'"
            )

        case "done":
            return ExplorationDecision(
                action: "done",
                targetElement: nil,
                reasoning: "Alternative action: end exploration",
                successProbability: SuccessProbability(
                    value: 1.0,
                    reasoning: "Done as final fallback"
                )
            )

        default:
            // Unknown action - fallback to "done"
            print("⚠️  Unknown alternative action '\(alternativeAction)', falling back to 'done'")
            return ExplorationDecision(
                action: "done",
                targetElement: nil,
                reasoning: "Unknown alternative action, ending exploration",
                successProbability: SuccessProbability(
                    value: 0.5,
                    reasoning: "Fallback due to unknown alternative"
                )
            )
        }
    }

    /// Generate appropriate test text for a given element using fixture system
    /// - Parameters:
    ///   - element: The UI element to generate a value for
    ///   - screenType: Optional screen type for context-aware matching
    /// - Returns: Tuple of (value, source) indicating the generated value and its origin
    private func generateTestTextFor(
        element: MinimalElement,
        screenType: ScreenType? = nil
    ) async throws -> (value: String, source: ValueSource) {
        // Initialize resolver if needed
        if fixtureResolver == nil {
            fixtureResolver = FixtureResolver(fixture: nil)
        }

        guard let resolver = fixtureResolver else {
            // Fallback to legacy behavior (should never happen)
            let fallbackValue = generateLegacyTestText(fieldId: element.id ?? element.label ?? "")
            return (fallbackValue, .fallback)
        }

        return try await resolver.resolve(element: element, screenType: screenType)
    }

    /// Legacy fallback for test text generation (preserves existing behavior)
    private func generateLegacyTestText(fieldId: String) -> String {
        let lowercased = fieldId.lowercased()

        if lowercased.contains("email") {
            return "test@example.com"
        } else if lowercased.contains("password") {
            return "TestPassword123"
        } else if lowercased.contains("phone") {
            return "555-0100"
        } else if lowercased.contains("name") {
            return "Test User"
        } else if lowercased.contains("search") {
            return "test query"
        } else {
            return "test input"
        }
    }
}
