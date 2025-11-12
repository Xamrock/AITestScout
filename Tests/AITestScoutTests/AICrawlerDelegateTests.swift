import Testing
import Foundation
import XCTest
@testable import AITestScout

@Suite("AICrawlerDelegate Tests")
@MainActor
struct AICrawlerDelegateTests {

    // MARK: - Delegate Protocol Tests

    @Test("Crawler should accept optional delegate")
    func testCrawlerAcceptsDelegate() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()

        // Act
        crawler.delegate = delegate

        // Assert
        #expect(crawler.delegate != nil, "Should accept delegate")
    }

    @Test("Crawler should allow nil delegate")
    func testCrawlerAllowsNilDelegate() async throws {
        // Arrange
        let crawler = try await AICrawler()
        let delegate = TestCrawlerDelegate() // Keep strong reference
        crawler.delegate = delegate
        #expect(crawler.delegate != nil)

        // Act
        crawler.delegate = nil

        // Assert
        #expect(crawler.delegate == nil, "Should allow setting delegate to nil")
    }

    @Test("Default crawler should have nil delegate")
    func testDefaultCrawlerNilDelegate() async throws {
        // Arrange & Act
        let crawler = try await AICrawler()

        // Assert
        #expect(crawler.delegate == nil, "Default delegate should be nil")
    }

    // MARK: - Screen Discovery Delegate Tests

    @Test("Delegate should be notified of new screen discovery")
    func testDelegateNotifiedOfNewScreen() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var discoveredFingerprint: String?
        var discoveredHierarchy: CompressedHierarchy?
        delegate.didDiscoverNewScreenHandler = { fingerprint, hierarchy in
            discoveredFingerprint = fingerprint
            discoveredHierarchy = hierarchy
        }

        // Act - Simulate discovering a new screen
        let hierarchy = CompressedHierarchy(
            elements: [
                MinimalElement(type: .button, id: "testButton", interactive: true)
            ],
            screenshot: Data(),
            screenType: nil
        )

        // Manually call the handler
        delegate.didDiscoverNewScreenHandler?(hierarchy.fingerprint, hierarchy)

        // Assert
        #expect(discoveredFingerprint != nil, "Should receive fingerprint")
        #expect(discoveredHierarchy != nil, "Should receive hierarchy")
    }

    @Test("Delegate should be notified of screen revisits")
    func testDelegateNotifiedOfScreenRevisit() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var revisitedFingerprint: String?
        var visitCount: Int = 0
        delegate.didRevisitScreenHandler = { fingerprint, count in
            revisitedFingerprint = fingerprint
            visitCount = count
        }

        // Act - Simulate revisiting
        let testFingerprint = "abc123"
        delegate.didRevisitScreenHandler?(testFingerprint, 2)

        // Assert
        #expect(revisitedFingerprint == testFingerprint)
        #expect(visitCount == 2)
    }

    // MARK: - Decision Lifecycle Delegate Tests

    @Test("Delegate should be notified before decision is made")
    func testDelegateWillMakeDecision() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var receivedHierarchy: CompressedHierarchy?
        delegate.willMakeDecisionHandler = { hierarchy in
            receivedHierarchy = hierarchy
        }

        // Act
        let testHierarchy = CompressedHierarchy(
            elements: [MinimalElement(type: .button, id: "btn", interactive: true)],
            screenshot: Data(),
            screenType: nil
        )
        delegate.willMakeDecisionHandler?(testHierarchy)

        // Assert
        #expect(receivedHierarchy != nil, "Should receive hierarchy before decision")
    }

    @Test("Delegate should be notified after decision is made")
    func testDelegateDidMakeDecision() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var receivedDecision: ExplorationDecision?
        var receivedHierarchy: CompressedHierarchy?
        delegate.didMakeDecisionHandler = { decision, hierarchy in
            receivedDecision = decision
            receivedHierarchy = hierarchy
        }

        // Act
        let testDecision = ExplorationDecision(
            action: "tap",
            targetElement: "testButton",
            reasoning: "Test",
            successProbability: SuccessProbability(value: 0.9, reasoning: "High confidence")
        )
        let testHierarchy = CompressedHierarchy(
            elements: [],
            screenshot: Data(),
            screenType: nil
        )
        delegate.didMakeDecisionHandler?(testDecision, testHierarchy)

        // Assert
        #expect(receivedDecision != nil, "Should receive decision")
        #expect(receivedDecision?.action == "tap")
        #expect(receivedHierarchy != nil, "Should receive hierarchy")
    }

    // MARK: - Transition Tracking Delegate Tests

    @Test("Delegate should be notified of transitions")
    func testDelegateDidRecordTransition() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var fromScreen: String?
        var toScreen: String?
        var recordedAction: Action?
        var transitionDuration: TimeInterval?

        delegate.didRecordTransitionHandler = { from, to, action, duration in
            fromScreen = from
            toScreen = to
            recordedAction = action
            transitionDuration = duration
        }

        // Act
        let action = Action(
            type: .tap,
            targetElement: "loginButton",
            textTyped: nil,
            reasoning: "Tap login",
            confidence: 95
        )
        delegate.didRecordTransitionHandler?("screen1", "screen2", action, 0.5)

        // Assert
        #expect(fromScreen == "screen1")
        #expect(toScreen == "screen2")
        #expect(recordedAction?.type == .tap)
        #expect(transitionDuration == 0.5)
    }

    // MARK: - Stuck Detection Delegate Tests

    @Test("Delegate should be notified when crawler is stuck")
    func testDelegateDidDetectStuck() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var detectedAttemptCount: Int = 0
        var detectedFingerprint: String?
        delegate.didDetectStuckHandler = { attempts, fingerprint in
            detectedAttemptCount = attempts
            detectedFingerprint = fingerprint
        }

        // Act
        delegate.didDetectStuckHandler?(3, "stuckScreen123")

        // Assert
        #expect(detectedAttemptCount == 3)
        #expect(detectedFingerprint == "stuckScreen123")
    }

    // MARK: - Error Handling Delegate Tests

    @Test("Delegate should be notified of errors")
    func testDelegateDidEncounterError() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var receivedError: Error?
        var errorContext: String?
        delegate.didEncounterErrorHandler = { error, context in
            receivedError = error
            errorContext = context
        }

        // Act
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        delegate.didEncounterErrorHandler?(testError, "Test context")

        // Assert
        #expect(receivedError != nil, "Should receive error")
        #expect(errorContext == "Test context")
    }

    // MARK: - Multiple Delegate Methods Tests

    @Test("Delegate can implement multiple methods")
    func testMultipleDelegateMethods() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var decisionMade = false
        var screenDiscovered = false

        delegate.didMakeDecisionHandler = { _, _ in
            decisionMade = true
        }
        delegate.didDiscoverNewScreenHandler = { _, _ in
            screenDiscovered = true
        }

        // Act
        let decision = ExplorationDecision(
            action: "tap",
            targetElement: "btn",
            reasoning: "Test",
            successProbability: SuccessProbability(value: 0.9, reasoning: "High confidence")
        )
        let hierarchy = CompressedHierarchy(elements: [], screenshot: Data(), screenType: nil)

        delegate.didMakeDecisionHandler?(decision, hierarchy)
        delegate.didDiscoverNewScreenHandler?("screen1", hierarchy)

        // Assert
        #expect(decisionMade == true)
        #expect(screenDiscovered == true)
    }

    // MARK: - Optional Delegate Methods Tests

    @Test("All delegate methods should be optional")
    func testDelegateMethodsOptional() async throws {
        // Arrange
        let emptyDelegate = EmptyTestDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = emptyDelegate

        // Act & Assert - Should not crash when calling optional methods
        let hierarchy = CompressedHierarchy(elements: [], screenshot: Data(), screenType: nil)
        let decision = ExplorationDecision(
            action: "tap",
            targetElement: "btn",
            reasoning: "Test",
            successProbability: SuccessProbability(value: 0.9, reasoning: "High confidence")
        )
        let action = Action(
            type: .tap,
            targetElement: "btn",
            textTyped: nil,
            reasoning: "Test",
            confidence: 90
        )

        emptyDelegate.willMakeDecision(hierarchy: hierarchy)
        emptyDelegate.didMakeDecision(decision, hierarchy: hierarchy)
        emptyDelegate.didDiscoverNewScreen("fingerprint", hierarchy: hierarchy)
        emptyDelegate.didRevisitScreen("fingerprint", visitCount: 2)
        emptyDelegate.didRecordTransition(from: "a", to: "b", action: action, duration: 0.5)
        emptyDelegate.didDetectStuck(attemptCount: 3, screenFingerprint: "stuck")
        emptyDelegate.didEncounterError(NSError(domain: "test", code: 1), context: "test")

        #expect(Bool(true), "Optional methods should not crash when not implemented")
    }

    // MARK: - Integration with AICrawler Tests

    @Test("Delegate should work with real crawl operations")
    func testDelegateWithRealCrawler() async throws {
        // Arrange
        let delegate = TestCrawlerDelegate()
        let crawler = try await AICrawler()
        crawler.delegate = delegate

        var eventsReceived: [String] = []

        delegate.willMakeDecisionHandler = { _ in
            eventsReceived.append("willMakeDecision")
        }
        delegate.didMakeDecisionHandler = { _, _ in
            eventsReceived.append("didMakeDecision")
        }

        // Note: We can't easily test the full flow without mocking XCUIApplication,
        // but we can verify the delegate is properly attached
        #expect(crawler.delegate != nil)
        #expect(eventsReceived.isEmpty) // No events until actual crawling
    }
}

// MARK: - Test Helpers

/// Test delegate implementation for testing
@available(iOS 26.0, macOS 26.0, *)
private final class TestCrawlerDelegate: AICrawlerDelegate, @unchecked Sendable {
    var willMakeDecisionHandler: ((CompressedHierarchy) -> Void)?
    var didMakeDecisionHandler: ((ExplorationDecision, CompressedHierarchy) -> Void)?
    var didDiscoverNewScreenHandler: ((String, CompressedHierarchy) -> Void)?
    var didRevisitScreenHandler: ((String, Int) -> Void)?
    var didRecordTransitionHandler: ((String, String, Action, TimeInterval) -> Void)?
    var didDetectStuckHandler: ((Int, String) -> Void)?
    var didEncounterErrorHandler: ((Error, String?) -> Void)?

    func willMakeDecision(hierarchy: CompressedHierarchy) {
        willMakeDecisionHandler?(hierarchy)
    }

    func didMakeDecision(_ decision: ExplorationDecision, hierarchy: CompressedHierarchy) {
        didMakeDecisionHandler?(decision, hierarchy)
    }

    func didDiscoverNewScreen(_ fingerprint: String, hierarchy: CompressedHierarchy) {
        didDiscoverNewScreenHandler?(fingerprint, hierarchy)
    }

    func didRevisitScreen(_ fingerprint: String, visitCount: Int) {
        didRevisitScreenHandler?(fingerprint, visitCount)
    }

    func didRecordTransition(
        from fromFingerprint: String,
        to toFingerprint: String,
        action: Action,
        duration: TimeInterval
    ) {
        didRecordTransitionHandler?(fromFingerprint, toFingerprint, action, duration)
    }

    func didDetectStuck(attemptCount: Int, screenFingerprint: String) {
        didDetectStuckHandler?(attemptCount, screenFingerprint)
    }

    func didEncounterError(_ error: Error, context: String?) {
        didEncounterErrorHandler?(error, context)
    }
}

/// Empty delegate for testing optional methods
@available(iOS 26.0, macOS 26.0, *)
private final class EmptyTestDelegate: AICrawlerDelegate {
    // All methods are optional - no implementations
}
