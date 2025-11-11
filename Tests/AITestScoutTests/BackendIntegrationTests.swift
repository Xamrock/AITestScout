import Foundation
import Testing
@testable import AITestScout

/// Tests for Backend Integration - Phase 2 TDD
@Suite("BackendIntegration Tests", .serialized)
struct BackendIntegrationTests {

    // MARK: - Mock URLSession Support

    /// Mock URLProtocol for testing HTTP requests
    class MockURLProtocol: URLProtocol {
        nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
        nonisolated(unsafe) static var capturedRequests: [URLRequest] = []

        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override func startLoading() {
            // Capture the request with a copy that preserves the body
            var capturedRequest = request
            if let bodyStream = request.httpBodyStream {
                // If there's a stream, read it
                bodyStream.open()
                let bufferSize = 4096
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                var data = Data()
                while bodyStream.hasBytesAvailable {
                    let read = bodyStream.read(&buffer, maxLength: bufferSize)
                    data.append(buffer, count: read)
                }
                bodyStream.close()
                capturedRequest.httpBody = data
            }
            MockURLProtocol.capturedRequests.append(capturedRequest)

            guard let handler = MockURLProtocol.requestHandler else {
                fatalError("Handler is unavailable")
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}

        static func reset() {
            capturedRequests.removeAll()
            requestHandler = nil
        }
    }

    // MARK: - Initialization Tests

    @Test("BackendIntegration initializes with required parameters")
    func testInitialization() throws {
        let baseURL = "https://api.example.com"
        let orgId = UUID()
        let projectId = UUID()

        let integration = BackendIntegration(
            baseURL: baseURL,
            organizationId: orgId,
            projectId: projectId
        )

        #expect(integration.baseURL == baseURL)
        #expect(integration.organizationId == orgId)
        #expect(integration.projectId == projectId)
    }

    // MARK: - Create Session Tests

    @Test("createSession sends POST request to correct endpoint")
    func testCreateSessionEndpoint() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )!

            let sessionResponse = SessionResponse(id: UUID())
            let data = try JSONEncoder().encode(sessionResponse)

            return (response, data)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let integration = BackendIntegration(
            baseURL: "https://api.example.com",
            organizationId: UUID(),
            projectId: UUID(),
            urlSession: session
        )

        let explorationConfig = ExplorationConfig(
            steps: 30,
            goal: "Test login",
            temperature: 0.7
        )

        _ = try await integration.createSession(config: explorationConfig)

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let capturedRequest = MockURLProtocol.capturedRequests.first
        #expect(capturedRequest?.url?.absoluteString == "https://api.example.com/api/v1/sessions")
        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("createSession returns session ID on success")
    func testCreateSessionReturnsSessionID() async throws {
        MockURLProtocol.reset()
        let expectedSessionId = UUID()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )!

            let sessionResponse = SessionResponse(id: expectedSessionId)
            let data = try JSONEncoder().encode(sessionResponse)

            return (response, data)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let integration = BackendIntegration(
            baseURL: "https://api.example.com",
            organizationId: UUID(),
            projectId: UUID(),
            urlSession: session
        )

        let explorationConfig = ExplorationConfig(
            steps: 30,
            goal: "Test app",
            temperature: 0.7
        )

        let sessionId = try await integration.createSession(config: explorationConfig)

        #expect(sessionId == expectedSessionId)
    }

    @Test("createSession throws error on non-201 response")
    func testCreateSessionErrorHandling() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let integration = BackendIntegration(
            baseURL: "https://api.example.com",
            organizationId: UUID(),
            projectId: UUID(),
            urlSession: session
        )

        let explorationConfig = ExplorationConfig(
            steps: 30,
            goal: "Test app",
            temperature: 0.7
        )

        await #expect(throws: BackendError.self) {
            _ = try await integration.createSession(config: explorationConfig)
        }
    }

    // MARK: - Complete Session Tests

    @Test("completeSession sends PUT request with correct data")
    func testCompleteSessionRequest() async throws {
        MockURLProtocol.reset()
        let sessionId = UUID()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let integration = BackendIntegration(
            baseURL: "https://api.example.com",
            organizationId: UUID(),
            projectId: UUID(),
            urlSession: session
        )

        let result = ExplorationResult(
            screensDiscovered: 5,
            transitions: 10,
            duration: 120.0,
            navigationGraph: NavigationGraph(),
            successfulActions: 9,
            failedActions: 1
        )

        let explorationPath = ExplorationPath(goal: "Test app")
        let navigationGraph = NavigationGraph()
        let metadata = ExplorationMetadata(
            environment: EnvironmentInfo(
                platform: "iOS",
                osVersion: "17.0",
                deviceModel: "iPhone 15",
                screenResolution: CGSize(width: 393, height: 852),
                orientation: "portrait",
                locale: "en_US"
            ),
            elementContexts: [:],
            appContext: AppContext(
                bundleId: "com.test.app",
                appVersion: "1.0.0",
                buildNumber: "1"
            )
        )

        try await integration.completeSession(
            sessionId: sessionId,
            result: result,
            explorationPath: explorationPath,
            navigationGraph: navigationGraph,
            metadata: metadata
        )

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let capturedRequest = MockURLProtocol.capturedRequests.first
        #expect(capturedRequest?.url?.absoluteString == "https://api.example.com/api/v1/sessions/\(sessionId)")
        #expect(capturedRequest?.httpMethod == "PUT")
    }

    @Test("completeSession calculates metrics correctly")
    func testCompleteSessionMetrics() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let integration = BackendIntegration(
            baseURL: "https://api.example.com",
            organizationId: UUID(),
            projectId: UUID(),
            urlSession: session
        )

        let result = ExplorationResult(
            screensDiscovered: 8,
            transitions: 15,
            duration: 180.0,
            navigationGraph: NavigationGraph(),
            successfulActions: 14,
            failedActions: 1
        )

        let explorationPath = ExplorationPath(goal: "Test checkout")
        let navigationGraph = NavigationGraph()
        let metadata = ExplorationMetadata(
            environment: EnvironmentInfo(
                platform: "iOS",
                osVersion: "17.0",
                deviceModel: "iPhone 15",
                screenResolution: CGSize(width: 393, height: 852),
                orientation: "portrait",
                locale: "en_US"
            ),
            elementContexts: [:],
            appContext: AppContext(
                bundleId: "com.test.app",
                appVersion: "1.0.0",
                buildNumber: "1"
            )
        )

        try await integration.completeSession(
            sessionId: UUID(),
            result: result,
            explorationPath: explorationPath,
            navigationGraph: navigationGraph,
            metadata: metadata
        )

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let capturedRequest = MockURLProtocol.capturedRequests.first
        let capturedBody = try capturedRequest?.httpBody.flatMap { data in
            try JSONDecoder().decode(UpdateSessionRequest.self, from: data)
        }

        #expect(capturedBody?.metrics?.screensDiscovered == 8)
        #expect(capturedBody?.metrics?.transitions == 15)
        #expect(capturedBody?.metrics?.successfulActions == 14)
        #expect(capturedBody?.metrics?.failedActions == 1)
    }

    @Test("completeSession sets status to completed for successful exploration")
    func testCompleteSessionStatusCompleted() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let integration = BackendIntegration(
            baseURL: "https://api.example.com",
            organizationId: UUID(),
            projectId: UUID(),
            urlSession: session
        )

        let result = ExplorationResult(
            screensDiscovered: 5,
            transitions: 10,
            duration: 120.0,
            navigationGraph: NavigationGraph(),
            successfulActions: 10,
            failedActions: 0,
            crashesDetected: 0
        )

        let explorationPath = ExplorationPath(goal: "Test app")
        let navigationGraph = NavigationGraph()
        let metadata = ExplorationMetadata(
            environment: EnvironmentInfo(
                platform: "iOS",
                osVersion: "17.0",
                deviceModel: "iPhone 15",
                screenResolution: CGSize(width: 393, height: 852),
                orientation: "portrait",
                locale: "en_US"
            ),
            elementContexts: [:],
            appContext: AppContext(
                bundleId: "com.test.app",
                appVersion: "1.0.0",
                buildNumber: "1"
            )
        )

        try await integration.completeSession(
            sessionId: UUID(),
            result: result,
            explorationPath: explorationPath,
            navigationGraph: navigationGraph,
            metadata: metadata
        )

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let capturedRequest = MockURLProtocol.capturedRequests.first
        let capturedBody = try capturedRequest?.httpBody.flatMap { data in
            try JSONDecoder().decode(UpdateSessionRequest.self, from: data)
        }
        #expect(capturedBody?.status == .completed)
    }

    @Test("completeSession sets status to crashed when crashes detected")
    func testCompleteSessionStatusCrashed() async throws {
        MockURLProtocol.reset()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let integration = BackendIntegration(
            baseURL: "https://api.example.com",
            organizationId: UUID(),
            projectId: UUID(),
            urlSession: session
        )

        let result = ExplorationResult(
            screensDiscovered: 3,
            transitions: 5,
            duration: 60.0,
            navigationGraph: NavigationGraph(),
            successfulActions: 5,
            failedActions: 0,
            crashesDetected: 2
        )

        let explorationPath = ExplorationPath(goal: "Test app")
        let navigationGraph = NavigationGraph()
        let metadata = ExplorationMetadata(
            environment: EnvironmentInfo(
                platform: "iOS",
                osVersion: "17.0",
                deviceModel: "iPhone 15",
                screenResolution: CGSize(width: 393, height: 852),
                orientation: "portrait",
                locale: "en_US"
            ),
            elementContexts: [:],
            appContext: AppContext(
                bundleId: "com.test.app",
                appVersion: "1.0.0",
                buildNumber: "1"
            )
        )

        try await integration.completeSession(
            sessionId: UUID(),
            result: result,
            explorationPath: explorationPath,
            navigationGraph: navigationGraph,
            metadata: metadata
        )

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let capturedRequest = MockURLProtocol.capturedRequests.first
        let capturedBody = try capturedRequest?.httpBody.flatMap { data in
            try JSONDecoder().decode(UpdateSessionRequest.self, from: data)
        }
        #expect(capturedBody?.status == .crashed)
    }

    // MARK: - Fail Session Tests

    @Test("failSession sends PUT request with failed status")
    func testFailSession() async throws {
        MockURLProtocol.reset()
        let sessionId = UUID()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let integration = BackendIntegration(
            baseURL: "https://api.example.com",
            organizationId: UUID(),
            projectId: UUID(),
            urlSession: session
        )

        enum TestError: Error {
            case somethingWentWrong
        }

        try await integration.failSession(
            sessionId: sessionId,
            error: TestError.somethingWentWrong
        )

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let capturedRequest = MockURLProtocol.capturedRequests.first
        let capturedBody = try capturedRequest?.httpBody.flatMap { data in
            try JSONDecoder().decode(UpdateSessionRequest.self, from: data)
        }
        #expect(capturedBody?.status == .failed)
    }

    // MARK: - Error Types Tests

    @Test("BackendError has all required cases")
    func testBackendErrorCases() throws {
        let creationError = BackendError.sessionCreationFailed
        let updateError = BackendError.sessionUpdateFailed
        let uploadError = BackendError.uploadFailed

        #expect(creationError == BackendError.sessionCreationFailed)
        #expect(updateError == BackendError.sessionUpdateFailed)
        #expect(uploadError == BackendError.uploadFailed)
    }
}

// MARK: - Supporting Types for Tests

@available(macOS 26.0, iOS 26.0, *)
struct SessionResponse: Codable {
    let id: UUID
}
