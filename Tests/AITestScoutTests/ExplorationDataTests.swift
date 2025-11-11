import Foundation
import Testing
@testable import AITestScout

/// Tests for Backend Exploration Data Models - Phase 1 TDD
@Suite("ExplorationData Tests")
struct ExplorationDataTests {

    // MARK: - VerificationResultData Tests

    @Test("VerificationResultData initializes with all fields")
    func testVerificationResultDataInitialization() throws {
        let result = VerificationResultData(
            passed: true,
            reason: "Screen changed as expected"
        )

        #expect(result.passed == true)
        #expect(result.reason == "Screen changed as expected")
    }

    @Test("VerificationResultData is Codable")
    func testVerificationResultDataCodable() throws {
        let original = VerificationResultData(
            passed: false,
            reason: "Expected element not found"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VerificationResultData.self, from: data)

        #expect(decoded.passed == original.passed)
        #expect(decoded.reason == original.reason)
    }

    // MARK: - ExplorationStepData Tests

    @Test("ExplorationStepData initializes with all fields")
    func testExplorationStepDataInitialization() throws {
        let stepId = UUID()
        let timestamp = Date()

        let verificationResult = VerificationResultData(
            passed: true,
            reason: "Success"
        )

        let step = ExplorationStepData(
            stepNumber: 1,
            stepId: stepId.uuidString,
            timestamp: timestamp,
            action: "tap",
            targetElement: "submitButton",
            textTyped: nil,
            reasoning: "Tapping submit button to proceed",
            confidence: 85,
            wasSuccessful: true,
            didCauseCrash: false,
            wasRetry: false,
            screenDescription: "Login screen with email and password fields",
            interactiveElementCount: 5,
            elementContext: nil,
            verificationResult: verificationResult,
            screenshotPath: "/screenshots/step_001.png",
            screenshotStorageKey: "s3://bucket/screenshots/step_001.png"
        )

        #expect(step.stepNumber == 1)
        #expect(step.stepId == stepId.uuidString)
        #expect(step.action == "tap")
        #expect(step.targetElement == "submitButton")
        #expect(step.confidence == 85)
        #expect(step.wasSuccessful == true)
        #expect(step.verificationResult?.passed == true)
    }

    @Test("ExplorationStepData with optional fields nil")
    func testExplorationStepDataOptionalFields() throws {
        let step = ExplorationStepData(
            stepNumber: 2,
            stepId: UUID().uuidString,
            timestamp: Date(),
            action: "swipe",
            targetElement: nil,
            textTyped: nil,
            reasoning: "Exploring screen",
            confidence: 50,
            wasSuccessful: true,
            didCauseCrash: false,
            wasRetry: false,
            screenDescription: "Unknown screen",
            interactiveElementCount: 0,
            elementContext: nil,
            verificationResult: nil,
            screenshotPath: nil,
            screenshotStorageKey: nil
        )

        #expect(step.targetElement == nil)
        #expect(step.textTyped == nil)
        #expect(step.elementContext == nil)
        #expect(step.verificationResult == nil)
        #expect(step.screenshotPath == nil)
        #expect(step.screenshotStorageKey == nil)
    }

    @Test("ExplorationStepData is Codable")
    func testExplorationStepDataCodable() throws {
        let original = ExplorationStepData(
            stepNumber: 3,
            stepId: UUID().uuidString,
            timestamp: Date(),
            action: "type",
            targetElement: "emailField",
            textTyped: "test@example.com",
            reasoning: "Entering email",
            confidence: 90,
            wasSuccessful: true,
            didCauseCrash: false,
            wasRetry: false,
            screenDescription: "Login screen",
            interactiveElementCount: 5,
            elementContext: nil,
            verificationResult: nil,
            screenshotPath: "/screenshots/step_003.png",
            screenshotStorageKey: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExplorationStepData.self, from: data)

        #expect(decoded.stepNumber == original.stepNumber)
        #expect(decoded.action == original.action)
        #expect(decoded.textTyped == original.textTyped)
    }

    // MARK: - ScreenNodeData Tests

    @Test("ScreenNodeData initializes with all fields")
    func testScreenNodeDataInitialization() throws {
        let firstVisit = Date()

        let node = ScreenNodeData(
            fingerprint: "abc123",
            screenType: "login",
            visitCount: 3,
            firstVisitTime: firstVisit,
            averageInteractiveElements: 5
        )

        #expect(node.fingerprint == "abc123")
        #expect(node.screenType == "login")
        #expect(node.visitCount == 3)
        #expect(node.averageInteractiveElements == 5)
    }

    @Test("ScreenNodeData with optional fields nil")
    func testScreenNodeDataOptionalFields() throws {
        let node = ScreenNodeData(
            fingerprint: "def456",
            screenType: nil,
            visitCount: 1,
            firstVisitTime: Date(),
            averageInteractiveElements: 0
        )

        #expect(node.screenType == nil)
        #expect(node.visitCount == 1)
    }

    @Test("ScreenNodeData is Codable")
    func testScreenNodeDataCodable() throws {
        let original = ScreenNodeData(
            fingerprint: "xyz789",
            screenType: "home",
            visitCount: 5,
            firstVisitTime: Date(),
            averageInteractiveElements: 10
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScreenNodeData.self, from: data)

        #expect(decoded.fingerprint == original.fingerprint)
        #expect(decoded.visitCount == original.visitCount)
    }

    // MARK: - ScreenEdgeData Tests

    @Test("ScreenEdgeData initializes with all fields")
    func testScreenEdgeDataInitialization() throws {
        let edge = ScreenEdgeData(
            fromScreen: "screen1",
            toScreen: "screen2",
            action: "tap button",
            traversalCount: 3
        )

        #expect(edge.fromScreen == "screen1")
        #expect(edge.toScreen == "screen2")
        #expect(edge.action == "tap button")
        #expect(edge.traversalCount == 3)
    }

    @Test("ScreenEdgeData is Codable")
    func testScreenEdgeDataCodable() throws {
        let original = ScreenEdgeData(
            fromScreen: "login",
            toScreen: "home",
            action: "tap loginButton",
            traversalCount: 1
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScreenEdgeData.self, from: data)

        #expect(decoded.fromScreen == original.fromScreen)
        #expect(decoded.toScreen == original.toScreen)
        #expect(decoded.traversalCount == original.traversalCount)
    }

    // MARK: - NavigationGraphData Tests

    @Test("NavigationGraphData initializes with all fields")
    func testNavigationGraphDataInitialization() throws {
        let node1 = ScreenNodeData(
            fingerprint: "screen1",
            screenType: "login",
            visitCount: 1,
            firstVisitTime: Date(),
            averageInteractiveElements: 5
        )

        let node2 = ScreenNodeData(
            fingerprint: "screen2",
            screenType: "home",
            visitCount: 1,
            firstVisitTime: Date(),
            averageInteractiveElements: 10
        )

        let edge = ScreenEdgeData(
            fromScreen: "screen1",
            toScreen: "screen2",
            action: "tap login",
            traversalCount: 1
        )

        let graph = NavigationGraphData(
            totalScreens: 2,
            totalTransitions: 1,
            startNode: "screen1",
            coveragePercentage: 100.0,
            screens: [node1, node2],
            edges: [edge]
        )

        #expect(graph.totalScreens == 2)
        #expect(graph.totalTransitions == 1)
        #expect(graph.startNode == "screen1")
        #expect(graph.coveragePercentage == 100.0)
        #expect(graph.screens.count == 2)
        #expect(graph.edges.count == 1)
    }

    @Test("NavigationGraphData with optional startNode nil")
    func testNavigationGraphDataOptionalStartNode() throws {
        let graph = NavigationGraphData(
            totalScreens: 0,
            totalTransitions: 0,
            startNode: nil,
            coveragePercentage: 0.0,
            screens: [],
            edges: []
        )

        #expect(graph.startNode == nil)
        #expect(graph.screens.isEmpty)
        #expect(graph.edges.isEmpty)
    }

    @Test("NavigationGraphData is Codable")
    func testNavigationGraphDataCodable() throws {
        let node = ScreenNodeData(
            fingerprint: "test",
            screenType: "test",
            visitCount: 1,
            firstVisitTime: Date(),
            averageInteractiveElements: 5
        )

        let original = NavigationGraphData(
            totalScreens: 1,
            totalTransitions: 0,
            startNode: "test",
            coveragePercentage: 50.0,
            screens: [node],
            edges: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NavigationGraphData.self, from: data)

        #expect(decoded.totalScreens == original.totalScreens)
        #expect(decoded.coveragePercentage == original.coveragePercentage)
        #expect(decoded.screens.count == original.screens.count)
    }

    // MARK: - InsightsData Tests

    @Test("InsightsData initializes with all fields")
    func testInsightsDataInitialization() throws {
        let insights = InsightsData(
            totalSteps: 30,
            successfulSteps: 28,
            failedSteps: 2,
            crashSteps: 0,
            avgConfidence: 85.5,
            topFailureReasons: ["Element not found", "Timeout"],
            screenTypeDistribution: ["login": 3, "home": 5, "settings": 2]
        )

        #expect(insights.totalSteps == 30)
        #expect(insights.successfulSteps == 28)
        #expect(insights.failedSteps == 2)
        #expect(insights.crashSteps == 0)
        #expect(insights.avgConfidence == 85.5)
        #expect(insights.topFailureReasons.count == 2)
        #expect(insights.screenTypeDistribution.count == 3)
    }

    @Test("InsightsData is Codable")
    func testInsightsDataCodable() throws {
        let original = InsightsData(
            totalSteps: 20,
            successfulSteps: 18,
            failedSteps: 2,
            crashSteps: 0,
            avgConfidence: 90.0,
            topFailureReasons: ["Network error"],
            screenTypeDistribution: ["home": 10, "profile": 5]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(InsightsData.self, from: data)

        #expect(decoded.totalSteps == original.totalSteps)
        #expect(decoded.avgConfidence == original.avgConfidence)
        #expect(decoded.topFailureReasons.count == original.topFailureReasons.count)
    }

    // MARK: - Complete ExplorationData Tests

    @Test("ExplorationData initializes with all fields")
    func testExplorationDataInitialization() throws {
        let step = ExplorationStepData(
            stepNumber: 1,
            stepId: UUID().uuidString,
            timestamp: Date(),
            action: "tap",
            targetElement: "button",
            textTyped: nil,
            reasoning: "Test",
            confidence: 80,
            wasSuccessful: true,
            didCauseCrash: false,
            wasRetry: false,
            screenDescription: "Test screen",
            interactiveElementCount: 5,
            elementContext: nil,
            verificationResult: nil,
            screenshotPath: nil,
            screenshotStorageKey: nil
        )

        let node = ScreenNodeData(
            fingerprint: "screen1",
            screenType: "home",
            visitCount: 1,
            firstVisitTime: Date(),
            averageInteractiveElements: 5
        )

        let graph = NavigationGraphData(
            totalScreens: 1,
            totalTransitions: 0,
            startNode: "screen1",
            coveragePercentage: 100.0,
            screens: [node],
            edges: []
        )

        let insights = InsightsData(
            totalSteps: 1,
            successfulSteps: 1,
            failedSteps: 0,
            crashSteps: 0,
            avgConfidence: 80.0,
            topFailureReasons: [],
            screenTypeDistribution: ["home": 1]
        )

        let explorationData = BackendExplorationData(
            version: "1.0",
            steps: [step],
            navigationGraph: graph,
            elementContexts: [:],
            insights: insights
        )

        #expect(explorationData.version == "1.0")
        #expect(explorationData.steps.count == 1)
        #expect(explorationData.navigationGraph.totalScreens == 1)
        #expect(explorationData.elementContexts.isEmpty)
        #expect(explorationData.insights.totalSteps == 1)
    }

    @Test("ExplorationData is Codable")
    func testExplorationDataCodable() throws {
        let step = ExplorationStepData(
            stepNumber: 1,
            stepId: UUID().uuidString,
            timestamp: Date(),
            action: "tap",
            targetElement: "button",
            textTyped: nil,
            reasoning: "Test reasoning",
            confidence: 75,
            wasSuccessful: true,
            didCauseCrash: false,
            wasRetry: false,
            screenDescription: "Test screen",
            interactiveElementCount: 3,
            elementContext: nil,
            verificationResult: nil,
            screenshotPath: nil,
            screenshotStorageKey: nil
        )

        let node = ScreenNodeData(
            fingerprint: "abc",
            screenType: "test",
            visitCount: 1,
            firstVisitTime: Date(),
            averageInteractiveElements: 3
        )

        let graph = NavigationGraphData(
            totalScreens: 1,
            totalTransitions: 0,
            startNode: "abc",
            coveragePercentage: 100.0,
            screens: [node],
            edges: []
        )

        let insights = InsightsData(
            totalSteps: 1,
            successfulSteps: 1,
            failedSteps: 0,
            crashSteps: 0,
            avgConfidence: 75.0,
            topFailureReasons: [],
            screenTypeDistribution: ["test": 1]
        )

        let original = BackendExplorationData(
            version: "1.0",
            steps: [step],
            navigationGraph: graph,
            elementContexts: [:],
            insights: insights
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackendExplorationData.self, from: data)

        #expect(decoded.version == original.version)
        #expect(decoded.steps.count == original.steps.count)
        #expect(decoded.insights.totalSteps == original.insights.totalSteps)
    }

    @Test("ExplorationData version field exists")
    func testExplorationDataVersion() throws {
        let data = BackendExplorationData(
            version: "1.0",
            steps: [],
            navigationGraph: NavigationGraphData(
                totalScreens: 0,
                totalTransitions: 0,
                startNode: nil,
                coveragePercentage: 0.0,
                screens: [],
                edges: []
            ),
            elementContexts: [:],
            insights: InsightsData(
                totalSteps: 0,
                successfulSteps: 0,
                failedSteps: 0,
                crashSteps: 0,
                avgConfidence: 0.0,
                topFailureReasons: [],
                screenTypeDistribution: [:]
            )
        )

        #expect(data.version == "1.0")
    }
}
