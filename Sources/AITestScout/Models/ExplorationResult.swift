import Foundation

/// Result of an exploration session
@available(macOS 26.0, iOS 26.0, *)
public struct ExplorationResult: Sendable {
    /// Number of unique screens discovered
    public let screensDiscovered: Int

    /// Number of transitions made between screens
    public let transitions: Int

    /// Total duration of the exploration
    public let duration: TimeInterval

    /// The navigation graph built during exploration
    public let navigationGraph: NavigationGraph

    /// Number of actions that executed successfully
    public let successfulActions: Int

    /// Number of actions that failed during execution
    public let failedActions: Int

    /// Path to generated test file (if any)
    public let generatedTestFile: URL?

    /// Path to generated report file (if any)
    public let generatedReportFile: URL?

    /// Number of action verifications performed
    public let verificationsPerformed: Int

    /// Number of verifications that passed
    public let verificationsPassed: Int

    /// Number of verifications that failed
    public let verificationsFailed: Int

    /// Number of retry attempts made with alternative actions
    public let retryAttempts: Int

    /// Timestamp when the exploration started
    public let startTime: Date

    /// Number of app crashes detected during exploration
    public let crashesDetected: Int

    /// Initialize exploration result
    public init(
        screensDiscovered: Int,
        transitions: Int,
        duration: TimeInterval,
        navigationGraph: NavigationGraph,
        successfulActions: Int = 0,
        failedActions: Int = 0,
        generatedTestFile: URL? = nil,
        generatedReportFile: URL? = nil,
        verificationsPerformed: Int = 0,
        verificationsPassed: Int = 0,
        verificationsFailed: Int = 0,
        retryAttempts: Int = 0,
        startTime: Date = Date(),
        crashesDetected: Int = 0
    ) {
        self.screensDiscovered = screensDiscovered
        self.transitions = transitions
        self.duration = duration
        self.navigationGraph = navigationGraph
        self.successfulActions = successfulActions
        self.failedActions = failedActions
        self.generatedTestFile = generatedTestFile
        self.generatedReportFile = generatedReportFile
        self.verificationsPerformed = verificationsPerformed
        self.verificationsPassed = verificationsPassed
        self.verificationsFailed = verificationsFailed
        self.retryAttempts = retryAttempts
        self.startTime = startTime
        self.crashesDetected = crashesDetected
    }

    // MARK: - Computed Properties

    /// Total number of actions attempted
    public var totalActions: Int {
        successfulActions + failedActions
    }

    /// Success rate as a percentage (0-100)
    public var successRatePercent: Int {
        guard totalActions > 0 else { return 0 }
        return (successfulActions * 100) / totalActions
    }

    /// Whether any critical failures occurred
    public var hasCriticalFailures: Bool {
        failedActions > 0
    }

    /// Verification success rate as a percentage (0-100)
    public var verificationSuccessRate: Int {
        guard verificationsPerformed > 0 else { return 0 }
        return (verificationsPassed * 100) / verificationsPerformed
    }

    /// Formatted summary string for console output
    public var summary: String {
        var lines = [
            "📊 Exploration Summary:",
            "   • Screens: \(screensDiscovered)",
            "   • Transitions: \(transitions)",
            "   • Duration: \(Int(duration))s",
            "   • Success Rate: \(successRatePercent)% (\(successfulActions)/\(totalActions))",
            "   • Failures: \(failedActions)"
        ]

        // Add crash information if any crashes detected
        if crashesDetected > 0 {
            lines.append("   • 💥 Crashes: \(crashesDetected)")
        }

        // Add verification stats if any verifications were performed
        if verificationsPerformed > 0 {
            lines.append("   • Verification: \(verificationSuccessRate)% pass rate (\(verificationsPassed)/\(verificationsPerformed))")
            if retryAttempts > 0 {
                lines.append("   • Retries: \(retryAttempts)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Assertion Helpers

    /// Assert that a minimum number of screens were discovered
    /// - Parameter minScreens: Minimum expected screen count
    /// - Throws: AssertionError if fewer screens discovered
    public func assertDiscovered(minScreens: Int) throws {
        guard screensDiscovered >= minScreens else {
            throw AssertionError.insufficientCoverage(
                expected: minScreens,
                actual: screensDiscovered
            )
        }
    }

    /// Assert that a minimum number of transitions occurred
    /// - Parameter min: Minimum expected transition count
    /// - Throws: AssertionError if fewer transitions made
    public func assertTransitions(min: Int) throws {
        guard transitions >= min else {
            throw AssertionError.insufficientTransitions(
                expected: min,
                actual: transitions
            )
        }
    }

    /// Assert that the success rate meets a minimum threshold
    /// - Parameter minPercent: Minimum expected success rate (0-100)
    /// - Throws: AssertionError if success rate is below threshold
    public func assertSuccessRate(minPercent: Int) throws {
        let totalActions = successfulActions + failedActions
        guard totalActions > 0 else {
            throw AssertionError.noActionsExecuted
        }

        let actualPercent = (successfulActions * 100) / totalActions
        guard actualPercent >= minPercent else {
            throw AssertionError.insufficientSuccessRate(
                expected: minPercent,
                actual: actualPercent,
                successful: successfulActions,
                failed: failedActions
            )
        }
    }

    /// Assert that no critical failures occurred
    /// Useful for CI/CD pipelines to fail builds on test generation issues
    /// - Throws: AssertionError if critical failures found
    public func assertNoCriticalIssues() throws {
        guard !hasCriticalFailures else {
            throw AssertionError.criticalFailuresFound(
                count: failedActions,
                testFile: generatedTestFile?.path
            )
        }
    }
}

/// Errors that can occur during assertion
public enum AssertionError: Error, LocalizedError {
    case insufficientCoverage(expected: Int, actual: Int)
    case insufficientTransitions(expected: Int, actual: Int)
    case insufficientSuccessRate(expected: Int, actual: Int, successful: Int, failed: Int)
    case noActionsExecuted
    case criticalFailuresFound(count: Int, testFile: String?)

    public var errorDescription: String? {
        switch self {
        case .insufficientCoverage(let expected, let actual):
            return "Insufficient screen coverage: expected at least \(expected) screens, got \(actual)"
        case .insufficientTransitions(let expected, let actual):
            return "Insufficient transitions: expected at least \(expected), got \(actual)"
        case .insufficientSuccessRate(let expected, let actual, let successful, let failed):
            return "Insufficient success rate: expected at least \(expected)%, got \(actual)% (\(successful) successful, \(failed) failed)"
        case .noActionsExecuted:
            return "No actions were executed during exploration"
        case .criticalFailuresFound(let count, let testFile):
            var message = "Critical failures found: \(count) action(s) failed during exploration"
            if let file = testFile {
                message += "\nGenerated test file: \(file)"
            }
            return message
        }
    }
}
