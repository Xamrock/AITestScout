import Foundation

// MARK: - Verification Result Data

/// Backend representation of verification result
@available(macOS 26.0, iOS 26.0, *)
public struct VerificationResultData: Codable, Equatable {
    /// Whether the verification passed
    public let passed: Bool

    /// Human-readable explanation of the verification result
    public let reason: String

    public init(passed: Bool, reason: String) {
        self.passed = passed
        self.reason = reason
    }
}

// MARK: - Exploration Step Data

/// Backend representation of a single exploration step
@available(macOS 26.0, iOS 26.0, *)
public struct ExplorationStepData: Codable, Equatable {
    /// Step number in the sequence
    public let stepNumber: Int

    /// Unique identifier for the step
    public let stepId: String

    /// Timestamp when the step was taken
    public let timestamp: Date

    /// The action taken (e.g., "tap", "type", "swipe")
    public let action: String

    /// The element that was interacted with (optional)
    public let targetElement: String?

    /// Text that was typed (optional)
    public let textTyped: String?

    /// AI's reasoning for this action
    public let reasoning: String

    /// Confidence level (0-100)
    public let confidence: Int

    /// Whether the step was successful
    public let wasSuccessful: Bool

    /// Whether this step caused the app to crash
    public let didCauseCrash: Bool

    /// Whether this was a retry attempt
    public let wasRetry: Bool

    /// Description of the screen at this step
    public let screenDescription: String

    /// Number of interactive elements on the screen
    public let interactiveElementCount: Int

    /// Element context for test generation (optional)
    public let elementContext: ElementContext?

    /// Verification result for this step (optional)
    public let verificationResult: VerificationResultData?

    /// Local path to screenshot (optional)
    public let screenshotPath: String?

    /// Cloud storage key for screenshot (optional)
    public let screenshotStorageKey: String?

    /// Complete AI prompt sent for this decision
    public let aiPrompt: String

    /// Complete AI response received
    public let aiResponse: String

    public init(
        stepNumber: Int,
        stepId: String,
        timestamp: Date,
        action: String,
        targetElement: String?,
        textTyped: String?,
        reasoning: String,
        confidence: Int,
        wasSuccessful: Bool,
        didCauseCrash: Bool,
        wasRetry: Bool,
        screenDescription: String,
        interactiveElementCount: Int,
        elementContext: ElementContext?,
        verificationResult: VerificationResultData?,
        screenshotPath: String?,
        screenshotStorageKey: String?,
        aiPrompt: String = "",
        aiResponse: String = ""
    ) {
        self.stepNumber = stepNumber
        self.stepId = stepId
        self.timestamp = timestamp
        self.action = action
        self.targetElement = targetElement
        self.textTyped = textTyped
        self.reasoning = reasoning
        self.confidence = confidence
        self.wasSuccessful = wasSuccessful
        self.didCauseCrash = didCauseCrash
        self.wasRetry = wasRetry
        self.screenDescription = screenDescription
        self.interactiveElementCount = interactiveElementCount
        self.elementContext = elementContext
        self.verificationResult = verificationResult
        self.screenshotPath = screenshotPath
        self.screenshotStorageKey = screenshotStorageKey
        self.aiPrompt = aiPrompt
        self.aiResponse = aiResponse
    }
}

// MARK: - Screen Node Data

/// Backend representation of a screen node in the navigation graph
@available(macOS 26.0, iOS 26.0, *)
public struct ScreenNodeData: Codable, Equatable {
    /// Unique fingerprint identifying the screen
    public let fingerprint: String

    /// Type of screen (e.g., "login", "home") - optional
    public let screenType: String?

    /// Number of times this screen was visited
    public let visitCount: Int

    /// First time this screen was visited
    public let firstVisitTime: Date

    /// Average number of interactive elements on this screen
    public let averageInteractiveElements: Int

    public init(
        fingerprint: String,
        screenType: String?,
        visitCount: Int,
        firstVisitTime: Date,
        averageInteractiveElements: Int
    ) {
        self.fingerprint = fingerprint
        self.screenType = screenType
        self.visitCount = visitCount
        self.firstVisitTime = firstVisitTime
        self.averageInteractiveElements = averageInteractiveElements
    }
}

// MARK: - Screen Edge Data

/// Backend representation of a transition between screens
@available(macOS 26.0, iOS 26.0, *)
public struct ScreenEdgeData: Codable, Equatable {
    /// Source screen fingerprint
    public let fromScreen: String

    /// Destination screen fingerprint
    public let toScreen: String

    /// Action that caused the transition
    public let action: String

    /// Number of times this transition was traversed
    public let traversalCount: Int

    public init(
        fromScreen: String,
        toScreen: String,
        action: String,
        traversalCount: Int
    ) {
        self.fromScreen = fromScreen
        self.toScreen = toScreen
        self.action = action
        self.traversalCount = traversalCount
    }
}

// MARK: - Navigation Graph Data

/// Backend representation of the navigation graph
@available(macOS 26.0, iOS 26.0, *)
public struct NavigationGraphData: Codable, Equatable {
    /// Total number of unique screens
    public let totalScreens: Int

    /// Total number of transitions
    public let totalTransitions: Int

    /// Fingerprint of the starting screen (optional)
    public let startNode: String?

    /// Coverage percentage (0-100)
    public let coveragePercentage: Double

    /// All screen nodes
    public let screens: [ScreenNodeData]

    /// All transitions between screens
    public let edges: [ScreenEdgeData]

    public init(
        totalScreens: Int,
        totalTransitions: Int,
        startNode: String?,
        coveragePercentage: Double,
        screens: [ScreenNodeData],
        edges: [ScreenEdgeData]
    ) {
        self.totalScreens = totalScreens
        self.totalTransitions = totalTransitions
        self.startNode = startNode
        self.coveragePercentage = coveragePercentage
        self.screens = screens
        self.edges = edges
    }
}

// MARK: - Insights Data

/// Session-level insights and statistics
@available(macOS 26.0, iOS 26.0, *)
public struct InsightsData: Codable, Equatable {
    /// Total number of steps taken
    public let totalSteps: Int

    /// Number of successful steps
    public let successfulSteps: Int

    /// Number of failed steps
    public let failedSteps: Int

    /// Number of steps that caused crashes
    public let crashSteps: Int

    /// Average confidence across all steps
    public let avgConfidence: Double

    /// Top failure reasons
    public let topFailureReasons: [String]

    /// Distribution of screen types encountered
    public let screenTypeDistribution: [String: Int]

    public init(
        totalSteps: Int,
        successfulSteps: Int,
        failedSteps: Int,
        crashSteps: Int,
        avgConfidence: Double,
        topFailureReasons: [String],
        screenTypeDistribution: [String: Int]
    ) {
        self.totalSteps = totalSteps
        self.successfulSteps = successfulSteps
        self.failedSteps = failedSteps
        self.crashSteps = crashSteps
        self.avgConfidence = avgConfidence
        self.topFailureReasons = topFailureReasons
        self.screenTypeDistribution = screenTypeDistribution
    }
}

// MARK: - Exploration Data (Backend)

/// Complete exploration session data for backend storage
/// This is the main data structure sent to the backend
@available(macOS 26.0, iOS 26.0, *)
public struct BackendExplorationData: Codable, Equatable {
    /// Format version for backward compatibility
    public let version: String

    /// All exploration steps with full context
    public let steps: [ExplorationStepData]

    /// Navigation graph data
    public let navigationGraph: NavigationGraphData

    /// Element contexts for test generation
    public let elementContexts: [String: ElementContext]

    /// Session-level insights
    public let insights: InsightsData

    public init(
        version: String,
        steps: [ExplorationStepData],
        navigationGraph: NavigationGraphData,
        elementContexts: [String: ElementContext],
        insights: InsightsData
    ) {
        self.version = version
        self.steps = steps
        self.navigationGraph = navigationGraph
        self.elementContexts = elementContexts
        self.insights = insights
    }
}
