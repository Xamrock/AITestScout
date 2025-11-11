import Foundation

/// Verifies that an exploration action achieved its expected outcome
@available(macOS 26.0, iOS 26.0, *)
public final class ActionVerifier: Sendable {

    public init() {}

    /// Verify that an action achieved its expected outcome
    /// - Parameters:
    ///   - decision: The exploration decision that was executed
    ///   - beforeHierarchy: Screen hierarchy before the action
    ///   - afterHierarchy: Screen hierarchy after the action
    /// - Returns: VerificationResult indicating success or failure with detailed reasoning
    public func verify(
        decision: ExplorationDecision,
        beforeHierarchy: CompressedHierarchy,
        afterHierarchy: CompressedHierarchy
    ) -> VerificationResult {
        // Special case: "done" action always passes verification
        if decision.action == "done" {
            return VerificationResult(
                passed: true,
                reason: "Verification skipped for done action",
                screenChanged: false
            )
        }

        // Check if screen changed (using fingerprint comparison)
        let screenChanged = beforeHierarchy.fingerprint != afterHierarchy.fingerprint

        // For swipe actions, screen change is the primary verification
        if decision.action == "swipe" {
            if screenChanged {
                return VerificationResult(
                    passed: true,
                    reason: "Swipe succeeded: screen changed (new content visible)",
                    screenChanged: true
                )
            } else {
                return VerificationResult(
                    passed: false,
                    reason: "Swipe failed: screen did not change (likely at bottom/top)",
                    screenChanged: false
                )
            }
        }

        // For type actions, check if text was actually entered
        if decision.action == "type" {
            if let targetElement = decision.targetElement,
               let expectedText = decision.textToType {

                // Find the target element in after hierarchy
                let elementAfter = afterHierarchy.elements.first {
                    $0.id == targetElement || $0.label == targetElement
                }

                if let elementValue = elementAfter?.value,
                   elementValue.contains(expectedText) {
                    return VerificationResult(
                        passed: true,
                        reason: "Type action succeeded: text was entered into '\(targetElement)'",
                        screenChanged: screenChanged
                    )
                } else {
                    return VerificationResult(
                        passed: false,
                        reason: "Type action failed: text not found in target element '\(targetElement)'",
                        screenChanged: screenChanged
                    )
                }
            }
        }

        // For tap actions with expected outcome, verify the outcome
        if let expectedOutcome = decision.expectedOutcome, !expectedOutcome.isEmpty {
            let expectedElementFound = checkExpectedOutcome(
                expectedOutcome: expectedOutcome,
                afterHierarchy: afterHierarchy
            )

            if expectedElementFound {
                return VerificationResult(
                    passed: true,
                    reason: "Tap succeeded: expected element/screen found (outcome matched)",
                    screenChanged: screenChanged,
                    expectedElementFound: true
                )
            } else if screenChanged {
                return VerificationResult(
                    passed: false,
                    reason: "Tap changed screen but expected element not found (unexpected outcome)",
                    screenChanged: true,
                    expectedElementFound: false
                )
            } else {
                return VerificationResult(
                    passed: false,
                    reason: "Tap failed: screen did not change and expected element not found",
                    screenChanged: false,
                    expectedElementFound: false
                )
            }
        }

        // Fallback: If no expected outcome specified, just check if screen changed
        if screenChanged {
            return VerificationResult(
                passed: true,
                reason: "Action succeeded: screen changed (basic verification)",
                screenChanged: true
            )
        } else {
            return VerificationResult(
                passed: false,
                reason: "Action failed: screen did not change (no visible effect)",
                screenChanged: false
            )
        }
    }

    /// Check if the expected outcome is present in the after hierarchy
    /// Parses the expected outcome string to look for element IDs or labels
    private func checkExpectedOutcome(
        expectedOutcome: String,
        afterHierarchy: CompressedHierarchy
    ) -> Bool {
        // Extract potential element identifiers from the expected outcome
        // Look for words that could be element IDs (camelCase, with common suffixes)
        let words = extractPotentialElementIds(from: expectedOutcome)

        // Check if any of these words match element IDs or labels (case-insensitive)
        for word in words {
            // Skip very generic words that could match anything
            let lowercased = word.lowercased()
            if lowercased == "message" || lowercased == "text" || lowercased == "button" || lowercased == "field" {
                continue
            }

            let found = afterHierarchy.elements.contains { element in
                // Exact match preferred
                if let id = element.id, id.lowercased() == word.lowercased() {
                    return true
                }
                if let label = element.label, label.lowercased() == word.lowercased() {
                    return true
                }
                // For longer words (8+ chars), allow contains match
                if word.count >= 8 {
                    if let id = element.id, id.lowercased().contains(word.lowercased()) {
                        return true
                    }
                    if let label = element.label, label.lowercased().contains(word.lowercased()) {
                        return true
                    }
                }
                return false
            }

            if found {
                return true
            }
        }

        return false
    }

    /// Extract potential element identifiers from expected outcome text
    /// Looks for camelCase words, words with common UI suffixes, etc.
    private func extractPotentialElementIds(from text: String) -> [String] {
        var identifiers: [String] = []

        // Common UI element suffixes/prefixes and screen-related keywords
        let uiKeywords = ["button", "field", "label", "text", "view", "screen", "message", "title", "header", "footer", "nav", "tab", "alert", "dialog", "dashboard", "welcome", "login", "settings", "profile"]

        // Split by common delimiters
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)

        for word in words {
            let cleaned = word.trimmingCharacters(in: CharacterSet.punctuationCharacters)

            // Skip very short words
            if cleaned.count < 4 {
                continue
            }

            // Check if word contains UI keywords or looks like an identifier
            let lowercased = cleaned.lowercased()
            if uiKeywords.contains(where: { lowercased.contains($0) }) {
                identifiers.append(cleaned)
            }

            // Check for camelCase patterns (e.g., "welcomeMessage", "dashboardTitle")
            if cleaned.contains(where: { $0.isUppercase }) && cleaned.first?.isLowercase == true {
                identifiers.append(cleaned)
            }
        }

        return identifiers
    }
}
