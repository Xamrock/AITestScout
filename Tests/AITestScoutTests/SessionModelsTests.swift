import Foundation
import Testing
@testable import AITestScout

/// Tests for Backend Session Models - Phase 1 TDD
@Suite("SessionModels Tests")
struct SessionModelsTests {

    // MARK: - SessionStatus Tests

    @Test("SessionStatus has all required cases")
    func testSessionStatusCases() throws {
        let running = SessionStatus.running
        let completed = SessionStatus.completed
        let failed = SessionStatus.failed
        let crashed = SessionStatus.crashed

        #expect(running.rawValue == "running")
        #expect(completed.rawValue == "completed")
        #expect(failed.rawValue == "failed")
        #expect(crashed.rawValue == "crashed")
    }

    @Test("SessionStatus is Codable")
    func testSessionStatusCodable() throws {
        let status = SessionStatus.completed

        let encoder = JSONEncoder()
        let data = try encoder.encode(status)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionStatus.self, from: data)

        #expect(decoded == status)
    }

    // MARK: - SessionConfiguration Tests

    @Test("SessionConfiguration initializes with all fields")
    func testSessionConfigurationInitialization() throws {
        let config = SessionConfiguration(
            steps: 30,
            goal: "Test checkout flow",
            temperature: 0.7,
            seed: 42,
            enableVerification: true,
            maxRetries: 3,
            fixtureID: UUID()
        )

        #expect(config.steps == 30)
        #expect(config.goal == "Test checkout flow")
        #expect(config.temperature == 0.7)
        #expect(config.seed == 42)
        #expect(config.enableVerification == true)
        #expect(config.maxRetries == 3)
        #expect(config.fixtureID != nil)
    }

    @Test("SessionConfiguration with optional fields nil")
    func testSessionConfigurationOptionalFields() throws {
        let config = SessionConfiguration(
            steps: 20,
            goal: "Explore app",
            temperature: 0.5,
            seed: nil,
            enableVerification: false,
            maxRetries: 0,
            fixtureID: nil
        )

        #expect(config.seed == nil)
        #expect(config.fixtureID == nil)
        #expect(config.enableVerification == false)
    }

    @Test("SessionConfiguration is Codable")
    func testSessionConfigurationCodable() throws {
        let original = SessionConfiguration(
            steps: 25,
            goal: "Login flow test",
            temperature: 0.8,
            seed: 123,
            enableVerification: true,
            maxRetries: 2,
            fixtureID: UUID()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionConfiguration.self, from: data)

        #expect(decoded.steps == original.steps)
        #expect(decoded.goal == original.goal)
        #expect(decoded.temperature == original.temperature)
        #expect(decoded.seed == original.seed)
    }

    // MARK: - SessionEnvironment Tests

    @Test("SessionEnvironment initializes with all fields")
    func testSessionEnvironmentInitialization() throws {
        let env = SessionEnvironment(
            deviceModel: "iPhone 15 Pro",
            osVersion: "17.0",
            appVersion: "1.2.3",
            testRunner: "XCTest",
            branch: "main",
            commitSHA: "abc123def456",
            pullRequestID: "42"
        )

        #expect(env.deviceModel == "iPhone 15 Pro")
        #expect(env.osVersion == "17.0")
        #expect(env.appVersion == "1.2.3")
        #expect(env.testRunner == "XCTest")
        #expect(env.branch == "main")
        #expect(env.commitSHA == "abc123def456")
        #expect(env.pullRequestID == "42")
    }

    @Test("SessionEnvironment with optional fields nil")
    func testSessionEnvironmentOptionalFields() throws {
        let env = SessionEnvironment(
            deviceModel: "iPhone 14",
            osVersion: "16.0",
            appVersion: "1.0.0",
            testRunner: "XCTest",
            branch: nil,
            commitSHA: nil,
            pullRequestID: nil
        )

        #expect(env.branch == nil)
        #expect(env.commitSHA == nil)
        #expect(env.pullRequestID == nil)
    }

    @Test("SessionEnvironment is Codable")
    func testSessionEnvironmentCodable() throws {
        let original = SessionEnvironment(
            deviceModel: "iPad Pro",
            osVersion: "17.1",
            appVersion: "2.0.0",
            testRunner: "XCTest",
            branch: "feature/new-ui",
            commitSHA: "789xyz",
            pullRequestID: "100"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionEnvironment.self, from: data)

        #expect(decoded.deviceModel == original.deviceModel)
        #expect(decoded.branch == original.branch)
    }

    // MARK: - SessionMetrics Tests

    @Test("SessionMetrics initializes with all fields")
    func testSessionMetricsInitialization() throws {
        let metrics = SessionMetrics(
            screensDiscovered: 10,
            transitions: 25,
            durationSeconds: 120,
            successfulActions: 23,
            failedActions: 2,
            crashesDetected: 0,
            verificationsPerformed: 20,
            verificationsPassed: 18,
            retryAttempts: 3,
            successRatePercent: 92.0,
            healthScore: 85.5
        )

        #expect(metrics.screensDiscovered == 10)
        #expect(metrics.transitions == 25)
        #expect(metrics.durationSeconds == 120)
        #expect(metrics.successfulActions == 23)
        #expect(metrics.failedActions == 2)
        #expect(metrics.crashesDetected == 0)
        #expect(metrics.verificationsPerformed == 20)
        #expect(metrics.verificationsPassed == 18)
        #expect(metrics.retryAttempts == 3)
        #expect(metrics.successRatePercent == 92.0)
        #expect(metrics.healthScore == 85.5)
    }

    @Test("SessionMetrics is Codable")
    func testSessionMetricsCodable() throws {
        let original = SessionMetrics(
            screensDiscovered: 15,
            transitions: 30,
            durationSeconds: 180,
            successfulActions: 28,
            failedActions: 2,
            crashesDetected: 1,
            verificationsPerformed: 25,
            verificationsPassed: 23,
            retryAttempts: 4,
            successRatePercent: 93.3,
            healthScore: 78.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionMetrics.self, from: data)

        #expect(decoded.screensDiscovered == original.screensDiscovered)
        #expect(decoded.healthScore == original.healthScore)
    }

    // MARK: - SessionArtifacts Tests

    @Test("SessionArtifacts initializes with all fields")
    func testSessionArtifactsInitialization() throws {
        let artifacts = SessionArtifacts(
            testFileURL: "https://storage.example.com/tests/test_123.swift",
            reportFileURL: "https://storage.example.com/reports/report_123.html",
            dashboardURL: "https://dashboard.example.com/sessions/123",
            screenshotURLs: [
                "https://storage.example.com/screenshots/1.png",
                "https://storage.example.com/screenshots/2.png"
            ]
        )

        #expect(artifacts.testFileURL == "https://storage.example.com/tests/test_123.swift")
        #expect(artifacts.reportFileURL == "https://storage.example.com/reports/report_123.html")
        #expect(artifacts.dashboardURL == "https://dashboard.example.com/sessions/123")
        #expect(artifacts.screenshotURLs?.count == 2)
    }

    @Test("SessionArtifacts with optional fields nil")
    func testSessionArtifactsOptionalFields() throws {
        let artifacts = SessionArtifacts(
            testFileURL: nil,
            reportFileURL: nil,
            dashboardURL: nil,
            screenshotURLs: nil
        )

        #expect(artifacts.testFileURL == nil)
        #expect(artifacts.reportFileURL == nil)
        #expect(artifacts.dashboardURL == nil)
        #expect(artifacts.screenshotURLs == nil)
    }

    @Test("SessionArtifacts is Codable")
    func testSessionArtifactsCodable() throws {
        let original = SessionArtifacts(
            testFileURL: "https://example.com/test.swift",
            reportFileURL: "https://example.com/report.html",
            dashboardURL: "https://example.com/dashboard",
            screenshotURLs: ["https://example.com/1.png"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionArtifacts.self, from: data)

        #expect(decoded.testFileURL == original.testFileURL)
        #expect(decoded.screenshotURLs?.count == original.screenshotURLs?.count)
    }

    // MARK: - CreateSessionRequest Tests

    @Test("CreateSessionRequest initializes with all fields")
    func testCreateSessionRequestInitialization() throws {
        let projectId = UUID()
        let fixtureId = UUID()

        let config = SessionConfiguration(
            steps: 30,
            goal: "Test app",
            temperature: 0.7,
            seed: 42,
            enableVerification: true,
            maxRetries: 3,
            fixtureID: fixtureId
        )

        let environment = SessionEnvironment(
            deviceModel: "iPhone 15",
            osVersion: "17.0",
            appVersion: "1.0.0",
            testRunner: "XCTest",
            branch: "main",
            commitSHA: "abc123",
            pullRequestID: "1"
        )

        let request = CreateSessionRequest(
            projectId: projectId,
            config: config,
            environment: environment,
            tags: ["ui-test", "smoke"],
            metadata: ["team": "ios", "priority": "high"]
        )

        #expect(request.projectId == projectId)
        #expect(request.config.steps == 30)
        #expect(request.environment?.deviceModel == "iPhone 15")
        #expect(request.tags?.count == 2)
        #expect(request.metadata?["team"] == "ios")
    }

    @Test("CreateSessionRequest with optional fields nil")
    func testCreateSessionRequestOptionalFields() throws {
        let projectId = UUID()
        let config = SessionConfiguration(
            steps: 20,
            goal: "Explore",
            temperature: 0.5,
            seed: nil,
            enableVerification: false,
            maxRetries: 0,
            fixtureID: nil
        )

        let request = CreateSessionRequest(
            projectId: projectId,
            config: config,
            environment: nil,
            tags: nil,
            metadata: nil
        )

        #expect(request.environment == nil)
        #expect(request.tags == nil)
        #expect(request.metadata == nil)
    }

    @Test("CreateSessionRequest is Codable")
    func testCreateSessionRequestCodable() throws {
        let projectId = UUID()
        let config = SessionConfiguration(
            steps: 25,
            goal: "Test checkout",
            temperature: 0.8,
            seed: 100,
            enableVerification: true,
            maxRetries: 2,
            fixtureID: nil
        )

        let environment = SessionEnvironment(
            deviceModel: "iPhone 14",
            osVersion: "16.0",
            appVersion: "2.0.0",
            testRunner: "XCTest",
            branch: nil,
            commitSHA: nil,
            pullRequestID: nil
        )

        let original = CreateSessionRequest(
            projectId: projectId,
            config: config,
            environment: environment,
            tags: ["test"],
            metadata: ["key": "value"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CreateSessionRequest.self, from: data)

        #expect(decoded.projectId == original.projectId)
        #expect(decoded.config.goal == original.config.goal)
    }

    // MARK: - UpdateSessionRequest Tests

    @Test("UpdateSessionRequest initializes with all fields")
    func testUpdateSessionRequestInitialization() throws {
        let metrics = SessionMetrics(
            screensDiscovered: 10,
            transitions: 20,
            durationSeconds: 100,
            successfulActions: 18,
            failedActions: 2,
            crashesDetected: 0,
            verificationsPerformed: 15,
            verificationsPassed: 14,
            retryAttempts: 2,
            successRatePercent: 90.0,
            healthScore: 85.0
        )

        let artifacts = SessionArtifacts(
            testFileURL: "https://example.com/test.swift",
            reportFileURL: nil,
            dashboardURL: nil,
            screenshotURLs: nil
        )

        let request = UpdateSessionRequest(
            status: .completed,
            metrics: metrics,
            explorationData: nil,
            artifacts: artifacts
        )

        #expect(request.status == .completed)
        #expect(request.metrics?.screensDiscovered == 10)
        #expect(request.artifacts?.testFileURL == "https://example.com/test.swift")
        #expect(request.explorationData == nil)
    }

    @Test("UpdateSessionRequest with all fields nil")
    func testUpdateSessionRequestAllNil() throws {
        let request = UpdateSessionRequest(
            status: nil,
            metrics: nil,
            explorationData: nil,
            artifacts: nil
        )

        #expect(request.status == nil)
        #expect(request.metrics == nil)
        #expect(request.explorationData == nil)
        #expect(request.artifacts == nil)
    }

    @Test("UpdateSessionRequest is Codable")
    func testUpdateSessionRequestCodable() throws {
        let metrics = SessionMetrics(
            screensDiscovered: 5,
            transitions: 10,
            durationSeconds: 50,
            successfulActions: 9,
            failedActions: 1,
            crashesDetected: 0,
            verificationsPerformed: 8,
            verificationsPassed: 8,
            retryAttempts: 0,
            successRatePercent: 90.0,
            healthScore: 90.0
        )

        let original = UpdateSessionRequest(
            status: .completed,
            metrics: metrics,
            explorationData: nil,
            artifacts: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UpdateSessionRequest.self, from: data)

        #expect(decoded.status == original.status)
        #expect(decoded.metrics?.screensDiscovered == original.metrics?.screensDiscovered)
    }

    // MARK: - JSON Serialization Tests

    @Test("CreateSessionRequest serializes to valid JSON")
    func testCreateSessionRequestJSONSerialization() throws {
        let projectId = UUID()
        let config = SessionConfiguration(
            steps: 30,
            goal: "Test login",
            temperature: 0.7,
            seed: 42,
            enableVerification: true,
            maxRetries: 3,
            fixtureID: nil
        )

        let request = CreateSessionRequest(
            projectId: projectId,
            config: config,
            environment: nil,
            tags: ["login"],
            metadata: nil
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(request)

        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString != nil)
        #expect(jsonString?.contains("projectId") == true)
        #expect(jsonString?.contains("config") == true)
        #expect(jsonString?.contains("steps") == true)
    }

    @Test("UpdateSessionRequest serializes to valid JSON")
    func testUpdateSessionRequestJSONSerialization() throws {
        let request = UpdateSessionRequest(
            status: .completed,
            metrics: nil,
            explorationData: nil,
            artifacts: nil
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(request)

        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString != nil)
        #expect(jsonString?.contains("status") == true)
    }
}
