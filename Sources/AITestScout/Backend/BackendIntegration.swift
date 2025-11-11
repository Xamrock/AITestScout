import Foundation

// MARK: - Backend Integration

/// Main integration point with Xamrock Backend
@available(macOS 26.0, iOS 26.0, *)
public class BackendIntegration {
    public let baseURL: String
    public let organizationId: UUID
    public let projectId: UUID
    private let urlSession: URLSession

    public init(
        baseURL: String,
        organizationId: UUID,
        projectId: UUID,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.organizationId = organizationId
        self.projectId = projectId
        self.urlSession = urlSession
    }

    // MARK: - Session Lifecycle

    /// Creates a session in the backend before exploration starts
    public func createSession(config: ExplorationConfig) async throws -> UUID {
        let url = URL(string: "\(baseURL)/api/v1/sessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let sessionConfig = SessionConfiguration(
            steps: config.steps,
            goal: config.goal,
            temperature: config.temperature,
            seed: config.seed,
            enableVerification: config.enableVerification,
            maxRetries: config.maxRetries,
            fixtureID: nil // TODO: Add fixture support
        )

        let createRequest = CreateSessionRequest(
            projectId: projectId,
            config: sessionConfig,
            environment: nil,
            tags: nil,
            metadata: nil
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(createRequest)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw BackendError.sessionCreationFailed
        }

        let decoder = JSONDecoder()
        let sessionResponse = try decoder.decode(SessionResponse.self, from: data)
        return sessionResponse.id
    }

    /// Updates session with final results and exploration data
    public func completeSession(
        sessionId: UUID,
        result: ExplorationResult,
        explorationPath: ExplorationPath,
        navigationGraph: NavigationGraph,
        metadata: ExplorationMetadata
    ) async throws {
        let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build metrics
        let metrics = SessionMetrics(
            screensDiscovered: result.screensDiscovered,
            transitions: result.transitions,
            durationSeconds: Int(result.duration),
            successfulActions: result.successfulActions,
            failedActions: result.failedActions,
            crashesDetected: result.crashesDetected,
            verificationsPerformed: result.verificationsPerformed,
            verificationsPassed: result.verificationsPassed,
            retryAttempts: result.retryAttempts,
            successRatePercent: Double(result.successRatePercent),
            healthScore: calculateHealthScore(result: result)
        )

        // Determine final status
        let status: SessionStatus
        if result.crashesDetected > 0 {
            status = .crashed
        } else if result.failedActions > 0 {
            status = .failed
        } else {
            status = .completed
        }

        let updateRequest = UpdateSessionRequest(
            status: status,
            metrics: metrics,
            explorationData: nil, // Simplified for now
            artifacts: nil
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(updateRequest)

        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.sessionUpdateFailed
        }
    }

    /// Marks session as failed with error message
    public func failSession(sessionId: UUID, error: Error) async throws {
        let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let updateRequest = UpdateSessionRequest(
            status: .failed,
            metrics: nil,
            explorationData: nil,
            artifacts: nil
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(updateRequest)

        _ = try await urlSession.data(for: request)
    }

    // MARK: - Private Helpers

    private func calculateHealthScore(result: ExplorationResult) -> Double {
        var score = Double(result.successRatePercent)

        // Bonus for high coverage
        if result.screensDiscovered >= 5 {
            score = min(100, score + 5)
        }

        // Bonus for verification
        if result.verificationsPerformed > 0 && result.verificationSuccessRate >= 80 {
            score = min(100, score + 5)
        }

        // Penalty for crashes
        if result.crashesDetected > 0 {
            score = max(0, score - Double(result.crashesDetected * 10))
        }

        return score
    }
}

// MARK: - Supporting Types

@available(macOS 26.0, iOS 26.0, *)
struct SessionResponse: Codable {
    let id: UUID
}

/// Backend errors
public enum BackendError: Error {
    case sessionCreationFailed
    case sessionUpdateFailed
    case uploadFailed
}
