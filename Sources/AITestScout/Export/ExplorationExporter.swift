import Foundation

/// Exports exploration data in comprehensive formats suitable for LLM test generation
///
/// This exporter packages all exploration data (steps, navigation graph, element contexts,
/// environment info) into structured formats that LLMs can consume to generate accurate
/// XCUITest code.
///
/// Example:
/// ```swift
/// let exporter = ExplorationExporter()
/// let jsonData = try exporter.exportComprehensive(
///     explorationPath: path,
///     navigationGraph: graph,
///     metadata: metadata
/// )
/// ```
@available(macOS 26.0, iOS 26.0, *)
public class ExplorationExporter {

    public init() {}

    /// Exports exploration data in comprehensive JSON format
    /// - Parameters:
    ///   - explorationPath: The exploration session path
    ///   - navigationGraph: The navigation graph built during exploration
    ///   - metadata: Optional metadata with element contexts and environment info
    /// - Returns: JSON data containing all exploration information
    /// - Throws: Encoding errors if serialization fails
    public func exportComprehensive(
        explorationPath: ExplorationPath,
        navigationGraph: NavigationGraph,
        metadata: ExplorationMetadata? = nil
    ) throws -> Data {
        let export = ComprehensiveExport(
            exportFormat: "aitestscout-exploration-v1",
            exportedAt: Date(),
            session: SessionInfo.from(explorationPath),
            environment: metadata?.environment,
            appContext: metadata?.appContext,
            explorationSteps: explorationPath.steps.map { step in
                StepExport.from(step, elementContexts: metadata?.elementContexts ?? [:])
            },
            navigationGraph: NavigationGraphExport.from(navigationGraph),
            insights: generateInsights(path: explorationPath, graph: navigationGraph)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    /// Exports as human-readable Markdown report
    /// - Parameters:
    ///   - explorationPath: The exploration session path
    ///   - navigationGraph: The navigation graph
    ///   - metadata: Optional metadata
    /// - Returns: Markdown formatted string
    public func exportMarkdown(
        explorationPath: ExplorationPath,
        navigationGraph: NavigationGraph,
        metadata: ExplorationMetadata? = nil
    ) -> String {
        var markdown = "# Exploration Report\n\n"

        // Session info
        markdown += "## Session Overview\n\n"
        markdown += "- **Goal**: \(explorationPath.goal)\n"
        markdown += "- **Start Time**: \(formatDate(explorationPath.startTime))\n"
        markdown += "- **Total Steps**: \(explorationPath.steps.count)\n"
        markdown += "- **Success Rate**: \(calculateSuccessRate(explorationPath))%\n\n"

        // Environment
        if let env = metadata?.environment {
            markdown += "## Environment\n\n"
            markdown += "- **Platform**: \(env.platform)\n"
            markdown += "- **OS Version**: \(env.osVersion)\n"
            markdown += "- **Device**: \(env.deviceModel)\n"
            markdown += "- **Resolution**: \(Int(env.screenResolution.width))×\(Int(env.screenResolution.height))\n\n"
        }

        // Navigation graph
        let stats = navigationGraph.coverageStats()
        markdown += "## Coverage\n\n"
        markdown += "- **Screens Discovered**: \(stats.totalScreens)\n"
        markdown += "- **Transitions**: \(stats.totalEdges)\n"
        markdown += "- **Average Depth**: \(String(format: "%.1f", stats.averageDepth))\n\n"

        // Steps
        markdown += "## Exploration Steps\n\n"
        for (index, step) in explorationPath.steps.enumerated() {
            let status = step.wasSuccessful ? "✅" : "❌"
            markdown += "\(index + 1). \(status) **\(step.action)** "
            if let target = step.targetElement {
                markdown += "`\(target)`"
            }
            if let text = step.textTyped {
                markdown += " → `\(text)`"
            }
            markdown += "\n   - Reasoning: \(step.reasoning)\n"
            markdown += "   - Confidence: \(step.confidence)%\n\n"
        }

        return markdown
    }

    // MARK: - Private Helpers

    private func generateInsights(path: ExplorationPath, graph: NavigationGraph) -> InsightsExport {
        let (successful, failed) = path.successRate

        return InsightsExport(
            performance: PerformanceInsights(
                totalSteps: path.steps.count,
                successfulSteps: successful,
                failedSteps: failed
            ),
            coverage: CoverageInsights(
                totalScreens: graph.nodes.count,
                totalTransitions: graph.edges.count
            )
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    private func calculateSuccessRate(_ path: ExplorationPath) -> Int {
        guard !path.steps.isEmpty else { return 0 }
        let (successful, _) = path.successRate
        return Int((Double(successful) / Double(path.steps.count)) * 100)
    }

    // MARK: - Backend Export

    /// Exports exploration data in backend-compatible format
    /// - Parameters:
    ///   - explorationPath: The exploration session path
    ///   - navigationGraph: The navigation graph built during exploration
    ///   - metadata: Optional metadata with element contexts and environment info
    /// - Returns: JSON data compatible with Xamrock Backend API
    /// - Throws: Encoding errors if serialization fails
    public func exportBackendData(
        explorationPath: ExplorationPath,
        navigationGraph: NavigationGraph,
        metadata: ExplorationMetadata? = nil
    ) throws -> Data {
        // Convert steps with sequential numbering
        let steps = explorationPath.steps.enumerated().map { (index, step) in
            ExplorationStepData(
                stepNumber: index + 1,
                stepId: step.id.uuidString,
                timestamp: step.timestamp,
                action: step.action,
                targetElement: step.targetElement,
                textTyped: step.textTyped,
                reasoning: step.reasoning,
                confidence: step.confidence,
                wasSuccessful: step.wasSuccessful,
                didCauseCrash: step.didCauseCrash,
                wasRetry: step.wasRetry,
                screenDescription: step.screenDescription,
                interactiveElementCount: step.interactiveElementCount,
                elementContext: nil, // TODO: Match from metadata.elementContexts
                verificationResult: step.verificationResult.map { result in
                    VerificationResultData(
                        passed: result.passed,
                        reason: result.reason
                    )
                },
                screenshotPath: step.screenshotPath,
                screenshotStorageKey: nil, // Set by backend after upload
                aiPrompt: step.aiPrompt,
                aiResponse: step.aiResponse
            )
        }

        // Convert navigation graph
        let stats = navigationGraph.coverageStats()
        let navGraph = NavigationGraphData(
            totalScreens: stats.totalScreens,
            totalTransitions: stats.totalEdges,
            startNode: navigationGraph.startNode,
            coveragePercentage: stats.coveragePercentage,
            screens: [], // TODO: Convert ScreenNode to ScreenNodeData
            edges: []    // TODO: Convert ScreenEdge to ScreenEdgeData
        )

        // Generate insights
        let (successful, failed) = explorationPath.successRate
        let crashSteps = steps.filter { $0.didCauseCrash }.count
        let avgConfidence: Double = steps.isEmpty ? 0.0 :
            Double(steps.map { $0.confidence }.reduce(0, +)) / Double(steps.count)

        let insights = InsightsData(
            totalSteps: steps.count,
            successfulSteps: successful,
            failedSteps: failed,
            crashSteps: crashSteps,
            avgConfidence: avgConfidence,
            topFailureReasons: [], // TODO: Extract from failed steps
            screenTypeDistribution: [:] // TODO: Extract from navigation graph
        )

        // Create backend exploration data
        let backendData = BackendExplorationData(
            version: "1.0",
            steps: steps,
            navigationGraph: navGraph,
            elementContexts: metadata?.elementContexts ?? [:],
            insights: insights
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backendData)
    }

    /// Saves exploration data to a file in backend-compatible format
    /// - Parameters:
    ///   - explorationPath: The exploration session path
    ///   - navigationGraph: The navigation graph
    ///   - fileURL: File URL to save to (typically exploration.json)
    ///   - metadata: Optional metadata
    /// - Throws: Encoding or file writing errors
    public func saveBackendData(
        explorationPath: ExplorationPath,
        navigationGraph: NavigationGraph,
        to fileURL: URL,
        metadata: ExplorationMetadata? = nil
    ) throws {
        // Generate backend data
        let data = try exportBackendData(
            explorationPath: explorationPath,
            navigationGraph: navigationGraph,
            metadata: metadata
        )

        // Create parent directories if needed
        let parentDir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Write to file
        try data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Export Data Models

/// Top-level export structure
@available(macOS 26.0, iOS 26.0, *)
struct ComprehensiveExport: Codable {
    let exportFormat: String
    let exportedAt: Date
    let session: SessionInfo
    let environment: EnvironmentInfo?
    let appContext: AppContext?
    let explorationSteps: [StepExport]
    let navigationGraph: NavigationGraphExport
    let insights: InsightsExport
}

/// Session information
@available(macOS 26.0, iOS 26.0, *)
struct SessionInfo: Codable {
    let sessionId: String
    let goal: String
    let startTime: Date
    let totalSteps: Int
    let successfulSteps: Int
    let failedSteps: Int

    static func from(_ path: ExplorationPath) -> SessionInfo {
        let (successful, failed) = path.successRate
        return SessionInfo(
            sessionId: path.sessionId.uuidString,
            goal: path.goal,
            startTime: path.startTime,
            totalSteps: path.steps.count,
            successfulSteps: successful,
            failedSteps: failed
        )
    }
}

/// Step export with enhanced context
@available(macOS 26.0, iOS 26.0, *)
struct StepExport: Codable {
    let stepNumber: Int
    let stepId: String
    let timestamp: Date
    let action: String
    let targetElement: String?
    let textTyped: String?
    let reasoning: String
    let confidence: Int
    let wasSuccessful: Bool
    let elementContext: ElementContext?
    let screenshotPath: String?

    static func from(_ step: ExplorationStep, elementContexts: [String: ElementContext]) -> StepExport {
        let context: ElementContext?
        if let target = step.targetElement {
            // Try to find context by matching target element
            context = elementContexts.values.first { ctx in
                ctx.queries.primary.contains(target)
            }
        } else {
            context = nil
        }

        return StepExport(
            stepNumber: 0, // Will be set by array index
            stepId: step.id.uuidString,
            timestamp: step.timestamp,
            action: step.action,
            targetElement: step.targetElement,
            textTyped: step.textTyped,
            reasoning: step.reasoning,
            confidence: step.confidence,
            wasSuccessful: step.wasSuccessful,
            elementContext: context,
            screenshotPath: step.screenshotPath
        )
    }
}

/// Navigation graph export
@available(macOS 26.0, iOS 26.0, *)
struct NavigationGraphExport: Codable {
    let totalScreens: Int
    let totalTransitions: Int
    let startNode: String?
    let coveragePercentage: Double

    static func from(_ graph: NavigationGraph) -> NavigationGraphExport {
        let stats = graph.coverageStats()
        return NavigationGraphExport(
            totalScreens: stats.totalScreens,
            totalTransitions: stats.totalEdges,
            startNode: graph.startNode,
            coveragePercentage: stats.coveragePercentage
        )
    }
}

/// Insights export
@available(macOS 26.0, iOS 26.0, *)
struct InsightsExport: Codable {
    let performance: PerformanceInsights
    let coverage: CoverageInsights
}

@available(macOS 26.0, iOS 26.0, *)
struct PerformanceInsights: Codable {
    let totalSteps: Int
    let successfulSteps: Int
    let failedSteps: Int
}

@available(macOS 26.0, iOS 26.0, *)
struct CoverageInsights: Codable {
    let totalScreens: Int
    let totalTransitions: Int
}
