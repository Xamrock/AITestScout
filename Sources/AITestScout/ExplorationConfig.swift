import Foundation

/// Configuration for app exploration
@available(macOS 26.0, iOS 26.0, *)
public struct ExplorationConfig: Sendable {
    /// Maximum number of exploration steps to take
    public var steps: Int

    /// The exploration goal for AI guidance
    public var goal: String

    /// Optional output directory for generated tests and reports
    /// If nil, uses smart defaults (Desktop or project directory)
    public var outputDirectory: URL?

    /// Whether to save results to the project root directory instead of temp directory
    /// When true, creates a "scout-results" directory in the project root
    /// Note: This only works in CI/command-line environments, not in iOS simulator (sandbox restrictions)
    /// Default: false (uses temp directory, safe for iOS simulator)
    public var saveToProjectRoot: Bool

    /// Whether to generate test files automatically
    public var generateTests: Bool

    /// Whether to generate an interactive HTML dashboard
    /// Default: true (dashboard auto-opens in browser)
    public var generateDashboard: Bool

    /// Whether to automatically open the dashboard in the default browser
    /// Default: true (requires generateDashboard to be enabled)
    public var autoOpenDashboard: Bool

    /// Whether to fail the test if critical issues are found
    public var failOnCriticalIssues: Bool

    /// Whether to show verbose console output
    public var verboseOutput: Bool

    /// Temperature for language model sampling (0.0 = deterministic, 1.0 = creative)
    /// Lower values make the model more focused and deterministic
    /// Higher values increase randomness and creativity
    /// Default: 0.7 (balanced)
    /// Recommended for CI: 0.3 (more deterministic)
    public var temperature: Double

    /// Optional random seed for deterministic exploration
    /// When set, enables reproducible explorations with the same seed
    /// Useful for regression testing and debugging
    /// Default: nil (non-deterministic)
    /// Recommended for CI: 42 or any fixed value
    public var seed: Int?

    /// Top-p (nucleus) sampling parameter
    /// Controls diversity by only sampling from top probability mass
    /// Default: 0.9 (recommended)
    public var topP: Double

    /// Whether to enable post-action verification (Phase 3)
    /// When enabled, verifies that actions achieved their expected outcomes
    /// and retries with alternative actions when verification fails
    /// Default: true
    public var enableVerification: Bool

    /// Maximum number of alternative actions to try when verification fails
    /// Default: 2 (try primary + up to 2 alternatives)
    public var maxRetries: Int

    /// Test data fixture for providing values during exploration
    /// When nil, uses default value generation behavior
    /// Default: nil
    public var fixture: ExplorationFixture?

    /// Initialize with default configuration
    public init(
        steps: Int = 20,
        goal: String = "Explore the app systematically",
        outputDirectory: URL? = nil,
        generateTests: Bool = true,
        generateDashboard: Bool = true,
        autoOpenDashboard: Bool = true,
        failOnCriticalIssues: Bool = false,
        verboseOutput: Bool = true,
        temperature: Double = 0.7,
        seed: Int? = nil,
        topP: Double = 0.9,
        enableVerification: Bool = true,
        maxRetries: Int = 2,
        saveToProjectRoot: Bool = false,
        fixture: ExplorationFixture? = nil
    ) {
        self.steps = steps
        self.goal = goal
        self.outputDirectory = outputDirectory
        self.generateTests = generateTests
        self.generateDashboard = generateDashboard
        self.autoOpenDashboard = autoOpenDashboard
        self.failOnCriticalIssues = failOnCriticalIssues
        self.verboseOutput = verboseOutput
        // Clamp temperature to valid range [0.0, 1.0]
        self.temperature = min(max(temperature, 0.0), 1.0)
        self.seed = seed
        // Clamp topP to valid range [0.0, 1.0]
        self.topP = min(max(topP, 0.0), 1.0)
        self.enableVerification = enableVerification
        self.maxRetries = max(maxRetries, 0) // Ensure non-negative
        self.saveToProjectRoot = saveToProjectRoot
        self.fixture = fixture
    }

    /// Create a CI-friendly configuration with deterministic settings
    ///
    /// This preset uses:
    /// - Low temperature (0.3) for more deterministic decisions
    /// - Fixed seed (42) for reproducible explorations
    /// - Standard topP (0.9)
    ///
    /// Usage:
    /// ```swift
    /// let config = ExplorationConfig.ciPreset(steps: 20, goal: "Regression test")
    /// let result = try Scout.explore(app, config: config)
    /// ```
    public static func ciPreset(steps: Int, goal: String) -> ExplorationConfig {
        return ExplorationConfig(
            steps: steps,
            goal: goal,
            temperature: 0.3,
            seed: 42,
            topP: 0.9
        )
    }
}
