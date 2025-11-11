import Foundation

/// Templates for prompting the Foundation Model to make crawling decisions
public enum CrawlerPrompts {

    /// Creates a multiple choice prompt for the AI (more reliable than free-form)
    /// - Parameters:
    ///   - choices: List of valid action choices
    ///   - visited: Set of element identifiers already interacted with
    ///   - goal: The exploration goal
    ///   - previousAction: The last action taken
    ///   - navigationMap: Optional navigation map showing exploration history
    ///   - screenType: Detected screen type
    /// - Returns: A formatted multiple choice prompt
    public static func exploreAppWithChoices(
        choices: [ActionChoice],
        visited: Set<String>,
        goal: String,
        previousAction: String? = nil,
        navigationMap: String? = nil,
        screenType: String? = nil
    ) -> String {
        // Format screen context
        let screenContext = screenType.map { " [\($0) screen]" } ?? ""

        // Format navigation map
        let mapContext = navigationMap.map { "\n\n\($0)\n" } ?? ""

        // Format previous action
        let previousContext = previousAction.map { "\n\nPrevious action: \($0)" } ?? ""

        // Format choices
        let choicesText = choices.map { $0.formatForPrompt() }.joined(separator: "\n")

        // Format visited elements
        let visitedList = visited.isEmpty ? "none" : Array(visited).prefix(10).sorted().joined(separator: ", ")

        return """
        iOS app crawler\(screenContext). Goal: \(goal)\(mapContext)

        AVAILABLE ACTIONS (select one):
        \(choicesText)

        Already visited: \(visitedList)\(previousContext)

        STRATEGY:
        - ⭐️ = High priority (submit, important navigation)
        - ⚠️  = Low priority (cancel, destructive)
        - For login screens: fill inputs before tapping submit
        - For forms: complete all fields before submitting
        - Explore unvisited high-priority actions first

        Select ONE action number and explain why (1-2 sentences).
        IMPORTANT: Your choice number MUST be from the list above.
        """
    }

    /// Creates a prompt for the AI to decide what action to take next
    /// - Parameters:
    ///   - hierarchy: JSON string representation of the current screen hierarchy
    ///   - visited: Set of element identifiers or labels that have already been interacted with
    ///   - goal: The exploration goal (default: systematic exploration)
    ///   - previousAction: The last action taken (helps avoid repetition)
    ///   - navigationMap: Optional navigation map showing exploration history
    ///   - screenType: Detected screen type (login, form, list, etc.)
    /// - Returns: A formatted prompt string for the AI
    public static func exploreApp(
        hierarchy: String,
        visited: Set<String>,
        goal: String = "Explore all screens and interactive elements systematically",
        previousAction: String? = nil,
        navigationMap: String? = nil,
        screenType: String? = nil
    ) -> String {
        let visitedList = visited.isEmpty ? "none" : Array(visited).prefix(20).sorted().joined(separator: ", ")
        let previousContext = previousAction.map { "\nPREVIOUS: \($0)" } ?? ""

        // Include navigation map if available (shows exploration context)
        let mapContext = navigationMap.map { "\n\n\($0)\n" } ?? ""

        // Include screen type hint if available
        let screenContext = screenType.map { " [\($0) screen]" } ?? ""

        return """
        iOS app crawler\(screenContext). Goal: \(goal)\(mapContext)

        CURRENT SCREEN:
        \(hierarchy)

        VISITED: \(visitedList)\(previousContext)

        STRATEGY:
        - Elements have "intent" (submit/cancel/destructive/navigation) and "priority" (higher=more important)
        - Prioritize high-priority elements with submit/navigation intent
        - For login screens: fill all inputs before tapping submit
        - For forms: complete all required fields first

        INSTRUCTIONS:
        1. Pick unvisited interactive element from CURRENT SCREEN
        2. Login: email="test@example.com", password="password123"
        3. Use EXACT id/label from JSON for targetElement

        OUTPUT FORMAT:
        - action="tap" → targetElement REQUIRED (e.g., "loginButton")
        - action="type" → targetElement + textToType REQUIRED
        - action="swipe" → targetElement=null (scroll)
        - action="done" → targetElement=null (finished)

        CRITICAL: tap/type need targetElement matching JSON above.
        """
    }

    /// Creates a prompt focused on finding specific functionality
    /// - Parameters:
    ///   - hierarchy: JSON string representation of the current screen
    ///   - target: Description of what to find (e.g., "find the settings")
    /// - Returns: A formatted prompt string for the AI
    public static func findFeature(
        hierarchy: String,
        target: String
    ) -> String {
        return """
        Find: \(target)

        ELEMENTS:
        \(hierarchy)

        Find element leading to "\(target)".

        OUTPUT:
        - action="tap" with targetElement (exact id/label from JSON)
        - action="done" if found or not available

        CRITICAL: If action="tap", targetElement is REQUIRED.
        """
    }
}
