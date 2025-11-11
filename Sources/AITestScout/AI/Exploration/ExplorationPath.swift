import Foundation

/// Tracks the complete exploration path through an app, with persistence support
@available(macOS 26.0, iOS 26.0, *)
public class ExplorationPath: Codable {
    /// All steps taken during exploration
    public private(set) var steps: [ExplorationStep]

    /// The goal of this exploration session
    public let goal: String

    /// When this exploration started
    public let startTime: Date

    /// Unique identifier for this exploration session
    public let sessionId: UUID

    /// File URL for persisting this path
    private let persistenceURL: URL?

    /// Optional metadata with element contexts and environment info
    /// This enriches the exploration with additional data for LLM test generation
    public private(set) var metadata: ExplorationMetadata?

    /// Initialize a new exploration path
    /// - Parameters:
    ///   - goal: The exploration goal
    ///   - sessionId: Unique session identifier (auto-generated if not provided)
    ///   - persistenceURL: Optional URL for saving/loading the path
    public init(
        goal: String,
        sessionId: UUID = UUID(),
        persistenceURL: URL? = nil
    ) {
        self.goal = goal
        self.sessionId = sessionId
        self.startTime = Date()
        self.steps = []
        self.persistenceURL = persistenceURL

        // Try to load existing path if persistence URL provided
        if let url = persistenceURL, FileManager.default.fileExists(atPath: url.path) {
            if let loaded = try? Self.load(from: url) {
                self.steps = loaded.steps
            }
        }
    }

    // MARK: - Path Management

    /// Add a new step to the exploration path
    /// - Parameter step: The exploration step to add
    /// - Returns: The updated path for chaining
    @discardableResult
    public func addStep(_ step: ExplorationStep) -> ExplorationPath {
        steps.append(step)

        // Auto-persist if URL is configured
        if let url = persistenceURL {
            try? save(to: url)
        }

        return self
    }

    /// Update the last step in the path
    /// - Parameter step: The updated step
    /// - Returns: The updated path for chaining
    @discardableResult
    public func updateLastStep(_ step: ExplorationStep) -> ExplorationPath {
        guard !steps.isEmpty else { return self }

        steps[steps.count - 1] = step

        // Auto-persist if URL is configured
        if let url = persistenceURL {
            try? save(to: url)
        }

        return self
    }

    /// Mark the last step as failed
    /// - Parameter reason: Optional reason for the failure
    @discardableResult
    public func markLastStepFailed(reason: String? = nil) -> ExplorationPath {
        guard let lastStep = steps.last else { return self }

        let updatedStep = ExplorationStep(
            id: lastStep.id,
            timestamp: lastStep.timestamp,
            action: lastStep.action,
            targetElement: lastStep.targetElement,
            textTyped: lastStep.textTyped,
            screenDescription: lastStep.screenDescription,
            interactiveElementCount: lastStep.interactiveElementCount,
            reasoning: reason ?? lastStep.reasoning,
            confidence: lastStep.confidence,
            wasSuccessful: false,
            aiPrompt: lastStep.aiPrompt,
            aiResponse: lastStep.aiResponse
        )

        return updateLastStep(updatedStep)
    }

    /// Get all visited element identifiers/labels
    public var visitedElements: Set<String> {
        Set(steps.compactMap { $0.targetElement })
    }

    /// Get the last action taken
    public var lastAction: String? {
        steps.last?.compactDescription()
    }

    /// Get the last N steps
    /// - Parameter count: Number of recent steps to retrieve
    /// - Returns: Array of recent steps (most recent last)
    public func recentSteps(_ count: Int) -> [ExplorationStep] {
        Array(steps.suffix(count))
    }

    /// Get count of successful vs failed steps
    public var successRate: (successful: Int, failed: Int) {
        let successful = steps.filter { $0.wasSuccessful }.count
        let failed = steps.count - successful
        return (successful, failed)
    }

    // MARK: - Metadata Management

    /// Attaches metadata to this exploration path
    /// - Parameter metadata: Metadata with element contexts and environment info
    /// - Note: This is optional and can be added after exploration completes
    @discardableResult
    public func attachMetadata(_ metadata: ExplorationMetadata) -> ExplorationPath {
        self.metadata = metadata

        // Auto-persist if URL is configured
        if let url = persistenceURL {
            try? save(to: url)
        }

        return self
    }

    // MARK: - Navigation Map

    /// Creates a compact text map showing the exploration journey
    /// - Parameter maxSteps: Maximum number of steps to show (default: 10)
    /// - Returns: A formatted string showing the exploration path
    public func navigationMap(maxSteps: Int = 10) -> String {
        guard !steps.isEmpty else {
            return "📍 START → [no steps taken yet]"
        }

        var map = "📍 EXPLORATION PATH:\n"

        // Show recent steps (up to maxSteps)
        let recentSteps = steps.suffix(maxSteps)
        let startIndex = steps.count - recentSteps.count

        for (index, step) in recentSteps.enumerated() {
            let stepNumber = startIndex + index + 1
            let indicator = (index == recentSteps.count - 1) ? "→ 📍" : "  →"
            let status = step.wasSuccessful ? "✓" : "✗"

            map += "\(stepNumber). \(indicator) \(step.compactDescription()) \(status)\n"
        }

        if steps.count > maxSteps {
            map += "   ... (\(steps.count - maxSteps) earlier steps)\n"
        }

        map += "\n🎯 Current: \(steps.last?.screenDescription ?? "Unknown")"
        map += "\n📊 Progress: \(steps.count) steps, \(visitedElements.count) unique elements"

        return map
    }

    /// Creates a detailed summary of the exploration
    public func summary() -> String {
        let (successful, failed) = successRate
        let duration = Date().timeIntervalSince(startTime)

        return """
        🎯 Goal: \(goal)
        📅 Session: \(sessionId.uuidString.prefix(8))...
        ⏱️ Duration: \(Int(duration))s
        📊 Total Steps: \(steps.count)
        ✅ Successful: \(successful)
        ❌ Failed: \(failed)
        🔍 Unique Elements: \(visitedElements.count)
        """
    }

    // MARK: - Persistence

    /// Save the exploration path to disk
    /// - Parameter url: File URL to save to
    /// - Throws: Encoding or file writing errors
    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: url)
    }

    /// Load an exploration path from disk
    /// - Parameter url: File URL to load from
    /// - Returns: The loaded exploration path
    /// - Throws: Decoding or file reading errors
    public static func load(from url: URL) throws -> ExplorationPath {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ExplorationPath.self, from: data)
    }

    /// Clear all steps (useful for starting fresh while keeping session info)
    public func clear() {
        steps.removeAll()
        if let url = persistenceURL {
            try? save(to: url)
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case steps, goal, startTime, sessionId, metadata
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.steps = try container.decode([ExplorationStep].self, forKey: .steps)
        self.goal = try container.decode(String.self, forKey: .goal)
        self.startTime = try container.decode(Date.self, forKey: .startTime)
        self.sessionId = try container.decode(UUID.self, forKey: .sessionId)
        self.metadata = try container.decodeIfPresent(ExplorationMetadata.self, forKey: .metadata)
        self.persistenceURL = nil // Not persisted, set externally if needed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(steps, forKey: .steps)
        try container.encode(goal, forKey: .goal)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}
