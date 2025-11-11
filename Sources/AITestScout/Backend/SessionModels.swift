import Foundation

// MARK: - Session Status

/// Status of an exploration session
public enum SessionStatus: String, Codable, Sendable, Equatable {
    case running
    case completed
    case failed
    case crashed
}

// MARK: - Session Configuration

/// Configuration for an exploration session
public struct SessionConfiguration: Codable, Sendable, Equatable {
    /// Number of steps to explore
    public let steps: Int

    /// Goal of the exploration
    public let goal: String

    /// Temperature for AI decisions (0.0-1.0)
    public let temperature: Double

    /// Random seed for reproducibility (optional)
    public let seed: Int?

    /// Whether to enable action verification
    public let enableVerification: Bool

    /// Maximum number of retry attempts
    public let maxRetries: Int

    /// Optional fixture ID for pre-defined test data
    public let fixtureID: UUID?

    public init(
        steps: Int,
        goal: String,
        temperature: Double,
        seed: Int?,
        enableVerification: Bool,
        maxRetries: Int,
        fixtureID: UUID?
    ) {
        self.steps = steps
        self.goal = goal
        self.temperature = temperature
        self.seed = seed
        self.enableVerification = enableVerification
        self.maxRetries = maxRetries
        self.fixtureID = fixtureID
    }
}

// MARK: - Session Environment

/// Environment information for an exploration session
public struct SessionEnvironment: Codable, Sendable, Equatable {
    /// Device model (e.g., "iPhone 15 Pro")
    public let deviceModel: String

    /// OS version (e.g., "17.0")
    public let osVersion: String

    /// App version (e.g., "1.2.3")
    public let appVersion: String

    /// Test runner name (e.g., "XCTest")
    public let testRunner: String

    /// Git branch (optional)
    public let branch: String?

    /// Git commit SHA (optional)
    public let commitSHA: String?

    /// Pull request ID (optional)
    public let pullRequestID: String?

    public init(
        deviceModel: String,
        osVersion: String,
        appVersion: String,
        testRunner: String,
        branch: String?,
        commitSHA: String?,
        pullRequestID: String?
    ) {
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.testRunner = testRunner
        self.branch = branch
        self.commitSHA = commitSHA
        self.pullRequestID = pullRequestID
    }
}

// MARK: - Session Metrics

/// Metrics collected during an exploration session
public struct SessionMetrics: Codable, Sendable, Equatable {
    /// Number of unique screens discovered
    public let screensDiscovered: Int

    /// Number of transitions between screens
    public let transitions: Int

    /// Duration of the session in seconds
    public let durationSeconds: Int

    /// Number of successful actions
    public let successfulActions: Int

    /// Number of failed actions
    public let failedActions: Int

    /// Number of crashes detected
    public let crashesDetected: Int

    /// Number of verifications performed
    public let verificationsPerformed: Int

    /// Number of verifications that passed
    public let verificationsPassed: Int

    /// Number of retry attempts made
    public let retryAttempts: Int

    /// Success rate as a percentage
    public let successRatePercent: Double

    /// Overall health score (0-100)
    public let healthScore: Double

    public init(
        screensDiscovered: Int,
        transitions: Int,
        durationSeconds: Int,
        successfulActions: Int,
        failedActions: Int,
        crashesDetected: Int,
        verificationsPerformed: Int,
        verificationsPassed: Int,
        retryAttempts: Int,
        successRatePercent: Double,
        healthScore: Double
    ) {
        self.screensDiscovered = screensDiscovered
        self.transitions = transitions
        self.durationSeconds = durationSeconds
        self.successfulActions = successfulActions
        self.failedActions = failedActions
        self.crashesDetected = crashesDetected
        self.verificationsPerformed = verificationsPerformed
        self.verificationsPassed = verificationsPassed
        self.retryAttempts = retryAttempts
        self.successRatePercent = successRatePercent
        self.healthScore = healthScore
    }
}

// MARK: - Session Artifacts

/// URLs to artifacts generated during the session
public struct SessionArtifacts: Codable, Sendable, Equatable {
    /// URL to the generated test file
    public let testFileURL: String?

    /// URL to the generated report file
    public let reportFileURL: String?

    /// URL to the dashboard
    public let dashboardURL: String?

    /// URLs to screenshots
    public let screenshotURLs: [String]?

    public init(
        testFileURL: String?,
        reportFileURL: String?,
        dashboardURL: String?,
        screenshotURLs: [String]?
    ) {
        self.testFileURL = testFileURL
        self.reportFileURL = reportFileURL
        self.dashboardURL = dashboardURL
        self.screenshotURLs = screenshotURLs
    }
}

// MARK: - Create Session Request

/// Request to create a new exploration session
public struct CreateSessionRequest: Codable, Sendable, Equatable {
    /// ID of the project this session belongs to
    public let projectId: UUID

    /// Session configuration
    public let config: SessionConfiguration

    /// Environment information (optional)
    public let environment: SessionEnvironment?

    /// Tags for categorizing the session (optional)
    public let tags: [String]?

    /// Additional metadata (optional)
    public let metadata: [String: String]?

    public init(
        projectId: UUID,
        config: SessionConfiguration,
        environment: SessionEnvironment?,
        tags: [String]?,
        metadata: [String: String]?
    ) {
        self.projectId = projectId
        self.config = config
        self.environment = environment
        self.tags = tags
        self.metadata = metadata
    }
}

// MARK: - Update Session Request

/// Request to update an existing exploration session
@available(macOS 26.0, iOS 26.0, *)
public struct UpdateSessionRequest: Codable, Equatable {
    /// Updated status (optional)
    public let status: SessionStatus?

    /// Updated metrics (optional)
    public let metrics: SessionMetrics?

    /// Exploration data (optional, defined in ExplorationData.swift)
    public let explorationData: BackendExplorationData?

    /// Artifact URLs (optional)
    public let artifacts: SessionArtifacts?

    public init(
        status: SessionStatus?,
        metrics: SessionMetrics?,
        explorationData: BackendExplorationData?,
        artifacts: SessionArtifacts?
    ) {
        self.status = status
        self.metrics = metrics
        self.explorationData = explorationData
        self.artifacts = artifacts
    }
}

// MARK: - Type Alias for Compatibility

/// Type alias for compatibility - ExplorationData is now BackendExplorationData
@available(macOS 26.0, iOS 26.0, *)
public typealias ExplorationData = BackendExplorationData
