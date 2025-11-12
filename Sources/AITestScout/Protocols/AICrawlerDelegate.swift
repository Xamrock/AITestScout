import Foundation

/// Delegate protocol for observing and customizing AICrawler behavior
///
/// All methods are optional. Implement only the methods you need to observe or customize crawler behavior.
///
/// This protocol provides extension points for:
/// - **Observing AI decisions** - Track what the AI chooses and why
/// - **Screen discovery tracking** - Know when new screens are found
/// - **Navigation monitoring** - Observe transitions between screens
/// - **Stuck detection alerts** - React when crawler detects it's stuck
/// - **Custom integrations** - Run accessibility scans, performance tests, analytics, etc.
///
/// Example:
/// ```swift
/// class MyDelegate: AICrawlerDelegate {
///     func didDiscoverNewScreen(_ fingerprint: String, hierarchy: CompressedHierarchy) {
///         // Run accessibility scan on new screen
///         AccessibilityScanner.scan(hierarchy)
///     }
///
///     func didMakeDecision(_ decision: ExplorationDecision, hierarchy: CompressedHierarchy) {
///         // Log decision to analytics
///         Analytics.track("AI Decision", decision: decision)
///     }
///
///     func didRecordTransition(from: String, to: String, action: Action, duration: TimeInterval) {
///         // Monitor performance
///         PerformanceMonitor.record(transition: action, duration: duration)
///     }
/// }
/// ```
@available(macOS 26.0, iOS 26.0, *)
public protocol AICrawlerDelegate: AnyObject, Sendable {

    // MARK: - Decision Lifecycle

    /// Called when the crawler is about to make an AI decision
    /// - Parameter hierarchy: The current screen hierarchy being analyzed
    /// - Note: Use this to prepare for decision making (e.g., start timers, log context)
    func willMakeDecision(hierarchy: CompressedHierarchy)

    /// Called after the AI has made a decision
    /// - Parameters:
    ///   - decision: The decision the AI made
    ///   - hierarchy: The hierarchy that was analyzed
    /// - Note: Use this to log decisions, validate choices, or run custom analysis
    func didMakeDecision(_ decision: ExplorationDecision, hierarchy: CompressedHierarchy)

    // MARK: - Screen Discovery

    /// Called when a new screen is discovered during exploration
    /// - Parameters:
    ///   - fingerprint: The unique fingerprint of the newly discovered screen
    ///   - hierarchy: The captured hierarchy of the new screen
    /// - Note: Use this to run accessibility scans, capture screenshots, or log screen info
    func didDiscoverNewScreen(_ fingerprint: String, hierarchy: CompressedHierarchy)

    /// Called when revisiting a screen that's already been seen
    /// - Parameters:
    ///   - fingerprint: The fingerprint of the screen being revisited
    ///   - visitCount: How many times this screen has been visited (including this one)
    /// - Note: Use this to detect navigation loops or track frequently visited screens
    func didRevisitScreen(_ fingerprint: String, visitCount: Int)

    // MARK: - Navigation & Transitions

    /// Called after a transition between screens is recorded in the navigation graph
    /// - Parameters:
    ///   - fromFingerprint: Source screen fingerprint
    ///   - toFingerprint: Destination screen fingerprint
    ///   - action: The action that caused the transition
    ///   - duration: How long the transition took
    /// - Note: Use this to monitor performance, track user flows, or run post-transition checks
    func didRecordTransition(
        from fromFingerprint: String,
        to toFingerprint: String,
        action: Action,
        duration: TimeInterval
    )

    // MARK: - Stuck Detection

    /// Called when the crawler detects it's stuck on the same screen
    /// - Parameters:
    ///   - attemptCount: Number of failed attempts on this screen
    ///   - screenFingerprint: The fingerprint of the screen where crawler is stuck
    /// - Note: Use this to log stuck situations, take debugging screenshots, or trigger manual intervention
    func didDetectStuck(attemptCount: Int, screenFingerprint: String)

    // MARK: - Error Handling

    /// Called when an error occurs during crawling
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Additional context about where the error happened
    func didEncounterError(_ error: Error, context: String?)
}

// MARK: - Default Implementations (All Optional)

@available(macOS 26.0, iOS 26.0, *)
public extension AICrawlerDelegate {
    func willMakeDecision(hierarchy: CompressedHierarchy) { }

    func didMakeDecision(_ decision: ExplorationDecision, hierarchy: CompressedHierarchy) { }

    func didDiscoverNewScreen(_ fingerprint: String, hierarchy: CompressedHierarchy) { }

    func didRevisitScreen(_ fingerprint: String, visitCount: Int) { }

    func didRecordTransition(
        from fromFingerprint: String,
        to toFingerprint: String,
        action: Action,
        duration: TimeInterval
    ) { }

    func didDetectStuck(attemptCount: Int, screenFingerprint: String) { }

    func didEncounterError(_ error: Error, context: String?) { }
}
