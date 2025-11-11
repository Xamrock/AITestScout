import Foundation
import XCTest

/// High-level facade for AI-powered app exploration
///
/// Scout provides a simple, one-line API for exploring iOS apps
/// with AI. It orchestrates all the underlying components (HierarchyAnalyzer,
/// AICrawler, ActionExecutor) and provides a clean interface.
///
/// **Simple Usage:**
/// ```swift
/// func testExploration() throws {
///     let result = try Scout.explore(app, steps: 10)
///     print("Discovered \(result.screensDiscovered) screens")
/// }
/// ```
///
/// **Detailed Usage:**
/// ```swift
/// func testExploration() throws {
///     let result = try Scout.explore(
///         app,
///         steps: 20,
///         goal: "Test the checkout flow"
///     )
///
///     try result.assertDiscovered(minScreens: 3)
///     try result.assertTransitions(min: 5)
/// }
/// ```
@available(macOS 26.0, iOS 26.0, *)
@MainActor
public class Scout: XCTestCase, @unchecked Sendable {
    /// The most recent exploration result
    nonisolated(unsafe) private static var _lastResult: ExplorationResult?

    /// Access the last exploration result
    nonisolated public static var lastResult: ExplorationResult? {
        return _lastResult
    }

    /// Explore an app with AI guidance
    ///
    /// This method orchestrates the entire exploration process:
    /// 1. Initializes HierarchyAnalyzer and AICrawler
    /// 2. Runs the exploration loop for N steps
    /// 3. Executes AI-recommended actions
    /// 4. Tracks discovered screens and transitions
    /// 5. Returns comprehensive results
    ///
    /// - Parameters:
    ///   - app: The XCUIApplication to explore
    ///   - steps: Maximum number of exploration steps (default: 20)
    ///   - goal: The exploration goal for AI guidance (default: systematic exploration)
    ///   - outputDirectory: Optional directory for generated files (default: temp directory)
    /// - Returns: ExplorationResult with discovered screens, transitions, and navigation graph
    /// - Throws: Errors from component initialization or action execution
    ///
    /// **Example:**
    /// ```swift
    /// // Simple one-liner
    /// try Scout.explore(app, steps: 10)
    ///
    /// // With custom output directory
    /// let result = try Scout.explore(
    ///     app,
    ///     steps: 15,
    ///     outputDirectory: URL(fileURLWithPath: "./UITests/Generated")
    /// )
    /// ```
    @discardableResult
    nonisolated public static func explore(
        _ app: XCUIApplication,
        steps: Int = 20,
        goal: String = "Explore the app systematically",
        outputDirectory: URL? = nil
    ) throws -> ExplorationResult {
        return try explore(app, config: ExplorationConfig(
            steps: steps,
            goal: goal,
            outputDirectory: outputDirectory
        ))
    }

    /// Explore an app with detailed configuration
    ///
    /// - Parameters:
    ///   - app: The XCUIApplication to explore
    ///   - config: Exploration configuration
    /// - Returns: ExplorationResult with discovered screens, transitions, and navigation graph
    /// - Throws: Errors from component initialization or action execution
    nonisolated public static func explore(
        _ app: XCUIApplication,
        config: ExplorationConfig
    ) throws -> ExplorationResult {
        // Create a temporary test case instance for xcAwait
        let testCase = Scout()

        // CRITICAL: Allow Scout's internal test case to continue after XCUITest failures
        // This is essential for crash detection - when the app crashes, XCUITest records
        // errors (timeouts, empty frame), but we need to continue execution to generate
        // crash reproduction tests. The user's test case settings remain independent.
        testCase.continueAfterFailure = true

        // REUSES: HierarchyAnalyzer (existing component)
        let analyzer = HierarchyAnalyzer()

        // REUSES: AICrawler (existing component) via xcAwait helper
        let crawler = try testCase.xcAwait {
            try await AICrawler()
        }

        // Set fixture if provided in config
        if let fixture = config.fixture {
            try testCase.xcAwait {
                await crawler.setFixture(fixture)
            }
            if config.verboseOutput {
                print("🔧 Using custom test data fixture")
            }
        }

        // REUSES: ActionExecutor (new wrapper around XCUIApplication)
        let executor = ActionExecutor(app: app)

        // REUSES: ExplorationPath (existing component)
        _ = crawler.startExploration(goal: config.goal)

        // Track timing
        let startTime = Date()

        // Determine output directory ONCE for this entire exploration session
        // This ensures screenshots, tests, and dashboard all go to the same directory
        var outputDir: URL?
        var screenshotsDir: URL?
        if let explorationPath = crawler.explorationPath {
            do {
                outputDir = try determineOutputDirectory(
                    configured: config.outputDirectory,
                    sessionId: explorationPath.sessionId,
                    saveToProjectRoot: config.saveToProjectRoot
                )
                screenshotsDir = outputDir!.appendingPathComponent("screenshots")
                try FileManager.default.createDirectory(at: screenshotsDir!, withIntermediateDirectories: true)
                print("📸 Screenshots directory created: \(screenshotsDir!.path)")
            } catch {
                print("⚠️  Failed to create screenshots directory: \(error)")
            }
        } else {
            print("⚠️  No exploration path available for screenshots directory")
        }

        // Exploration loop - run on MainActor for UI operations
        let (duration, stats, verificationStats) = try testCase.xcAwait {
            try await Task { @MainActor in
                var localDuration: TimeInterval = 0
                var localStats: CoverageStats?
                var verificationsPerformed = 0
                var verificationsPassed = 0
                var verificationsFailed = 0
                var retryAttempts = 0

                do {
                    var crashDetected = false  // Track if crash occurred
                    for stepNumber in 1...config.steps {
                        // 1. REUSES: analyzer.capture() (existing, MainActor-isolated)
                        let beforeHierarchy = analyzer.capture(from: app)

                        // Save screenshot for this step
                        var screenshotPath: String? = nil
                        if let screenshotsDir = screenshotsDir {
                            if beforeHierarchy.screenshot.isEmpty {
                                print("⚠️  Step \(stepNumber): Screenshot data is empty (size: \(beforeHierarchy.screenshot.count) bytes)")
                            } else {
                                let filename = "step_\(stepNumber)_before.png"
                                let screenshotFileURL = screenshotsDir.appendingPathComponent(filename)
                                do {
                                    try beforeHierarchy.screenshot.write(to: screenshotFileURL)
                                    screenshotPath = "screenshots/\(filename)" // Relative path for portability
                                    print("📸 Step \(stepNumber): Saved screenshot (\(beforeHierarchy.screenshot.count) bytes)")
                                } catch {
                                    print("⚠️  Step \(stepNumber): Failed to save screenshot: \(error)")
                                }
                            }
                        } else {
                            print("⚠️  Step \(stepNumber): Screenshots directory not available")
                        }

                        // 2. REUSES: crawler.decideNextActionWithChoices() (existing)
                        let result = try await crawler.decideNextActionWithChoices(
                            hierarchy: beforeHierarchy,
                            goal: config.goal,
                            recordStep: false  // Scout will record after retry loop
                        )
                        let decision = result.decision
                        let aiPrompt = result.aiPrompt
                        let aiResponse = result.aiResponse

                        // 3. Check if done
                        if decision.action == "done" {
                            print("✅ Exploration complete at step \(stepNumber)")
                            break
                        }

                        // 4. Execute action with verification and retry logic (Phase 3)
                        var currentDecision = decision
                        var actionSuccessful = false
                        var verificationResult: VerificationResult? = nil
                        var attemptNumber = 0
                        let maxAttempts = config.enableVerification ? 1 + config.maxRetries : 1

                        while attemptNumber < maxAttempts {
                            // 4a. Execute the action
                            do {
                                actionSuccessful = try executor.execute(currentDecision)
                            } catch {
                                // Catch all errors (ActionError and XCUIElement runtime errors)
                                let errorMessage = (error as? ActionError)?.localizedDescription ?? error.localizedDescription
                                print("⚠️  Action failed: \(errorMessage)")

                                // Check if app crashed AFTER action execution error
                                // The error might be due to the app crashing during/after the tap
                                if app.state == .notRunning {
                                    print("💥 CRASH DETECTED at step \(stepNumber) (after action error)")
                                    print("   Action: \(currentDecision.action)")
                                    print("   Error: \(errorMessage)")
                                    if let target = currentDecision.targetElement {
                                        print("   Target: \(target)")
                                    }

                                    let crashStep = ExplorationStep.from(
                                        decision: currentDecision,
                                        hierarchy: beforeHierarchy,
                                        wasSuccessful: false,
                                        screenshotPath: screenshotPath,
                                        didCauseCrash: true,
                                        aiPrompt: aiPrompt,
                                        aiResponse: aiResponse
                                    )
                                    crawler.explorationPath?.addStep(crashStep)

                                    // Generate crash test IMMEDIATELY when crash is detected
                                    if config.generateTests,
                                       let explorationPath = crawler.explorationPath,
                                       let outputDir = outputDir {
                                        do {
                                            let crashTestFileURL = outputDir.appendingPathComponent("CrashReproductionTest.swift")
                                            try explorationPath.saveCrashTest(for: crashStep, to: crashTestFileURL)
                                            print("💥 Crash test generated immediately at: \(crashTestFileURL.path)")
                                        } catch {
                                            print("⚠️  Failed to save crash test immediately: \(error)")
                                        }
                                    }

                                    throw NSError(domain: "AppCrash", code: 1, userInfo: [
                                        NSLocalizedDescriptionKey: "App crashed at step \(stepNumber)"
                                    ])
                                }

                                crawler.markLastStepFailed(reason: errorMessage)
                                actionSuccessful = false
                                // Action execution failure - don't verify, break retry loop
                                break
                            }

                            // 4b. If action executed successfully, check for crash
                            // Note: element.tap() includes automatic 60s wait for app to idle
                            // If a crash happened, we'll be here 60+ seconds after the tap
                            if actionSuccessful {
                                // DEBUG: Log app state
                                let currentState = app.state

                                // IMMEDIATE crash check (no wait needed - tap already waited)
                                if currentState == .notRunning {

                                    // Mark this step as crash-causing
                                    let crashStep = ExplorationStep.from(
                                        decision: currentDecision,
                                        hierarchy: beforeHierarchy,
                                        wasSuccessful: false,
                                        screenshotPath: screenshotPath,
                                        didCauseCrash: true,
                                        aiPrompt: aiPrompt,
                                        aiResponse: aiResponse
                                    )
                                    crawler.explorationPath?.addStep(crashStep)

                                    // Generate crash test IMMEDIATELY when crash is detected
                                    if config.generateTests,
                                       let explorationPath = crawler.explorationPath,
                                       let outputDir = outputDir {
                                        do {
                                            let crashTestFileURL = outputDir.appendingPathComponent("CrashReproductionTest.swift")
                                            try explorationPath.saveCrashTest(for: crashStep, to: crashTestFileURL)
                                        } catch {
                                            print("⚠️  Failed to save crash test immediately: \(error)")
                                        }
                                    }

                                    // Break out of both retry loop and exploration loop
                                    // The exploration path has auto-saved, so crash is persisted
                                    throw NSError(domain: "AppCrash", code: 1, userInfo: [
                                        NSLocalizedDescriptionKey: "App crashed at step \(stepNumber)"
                                    ])
                                }

                                // Small wait for UI to settle (normal case)
                                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                            }

                            // 4c. Verify action outcome (Phase 3)
                            if config.enableVerification && actionSuccessful {
                                // NOTE: app.state is unreliable for crash detection
                                // It often still shows .runningForeground even after crash
                                // We detect crashes by checking if hierarchy capture returns empty

                                // Capture hierarchy - if app crashed, this will return empty
                                // This is the fastest approach since we need the hierarchy anyway
                                let afterHierarchy = analyzer.capture(from: app)

                                // CRASH DETECTION: Empty hierarchy after successful action = crash
                                // HierarchyAnalyzer returns empty elements when app is not running
                                if afterHierarchy.elements.isEmpty && !beforeHierarchy.elements.isEmpty {

                                    let crashStep = ExplorationStep.from(
                                        decision: currentDecision,
                                        hierarchy: beforeHierarchy,
                                        wasSuccessful: false,
                                        screenshotPath: screenshotPath,
                                        didCauseCrash: true,
                                        aiPrompt: aiPrompt,
                                        aiResponse: aiResponse
                                    )
                                    crawler.explorationPath?.addStep(crashStep)

                                    // Generate crash test IMMEDIATELY when crash is detected
                                    if config.generateTests,
                                       let explorationPath = crawler.explorationPath,
                                       let outputDir = outputDir {
                                        do {
                                            let crashTestFileURL = outputDir.appendingPathComponent("CrashReproductionTest.swift")
                                            try explorationPath.saveCrashTest(for: crashStep, to: crashTestFileURL)
                                        } catch {
                                            print("⚠️  Failed to save crash test immediately: \(error)")
                                        }
                                    }

                                    // Don't throw - just exit exploration to allow test generation
                                    print("💥 Ending exploration due to crash")
                                    // Set flag and break out of retry loop
                                    crashDetected = true
                                    break
                                }

                                verificationResult = crawler.verifyAction(
                                    decision: currentDecision,
                                    beforeHierarchy: beforeHierarchy,
                                    afterHierarchy: afterHierarchy
                                )

                                verificationsPerformed += 1

                                if verificationResult!.passed {
                                    verificationsPassed += 1
                                    // Success! Break the retry loop
                                    break
                                } else {
                                    verificationsFailed += 1

                                    // Try next alternative if available
                                    attemptNumber += 1
                                    if attemptNumber < maxAttempts,
                                       attemptNumber - 1 < currentDecision.alternativeActions.count {
                                        retryAttempts += 1
                                        let alternativeAction = currentDecision.alternativeActions[attemptNumber - 1]

                                        // Convert alternative to decision
                                        currentDecision = try await crawler.convertAlternativeToDecision(
                                            alternativeAction,
                                            context: afterHierarchy
                                        )
                                    } else {
                                        // No more alternatives, accept the failure
                                        break
                                    }
                                }
                            } else {
                                // Verification disabled or action failed - exit retry loop
                                break
                            }
                        }

                        // If crash detected, break out of exploration loop
                        if crashDetected {
                            break
                        }

                        // 5. Record step with verification result and screenshot path
                        let step = ExplorationStep.from(
                            decision: currentDecision,
                            hierarchy: beforeHierarchy,
                            wasSuccessful: actionSuccessful && (verificationResult?.passed ?? true),
                            verificationResult: verificationResult,
                            wasRetry: attemptNumber > 0,
                            screenshotPath: screenshotPath,
                            aiPrompt: aiPrompt,
                            aiResponse: aiResponse
                        )
                        crawler.explorationPath?.addStep(step)
                    }

                    // Calculate duration and get stats
                    localDuration = Date().timeIntervalSince(startTime)
                    localStats = crawler.getCoverageStats()
                } catch {
                    // If exploration fails, still return partial results
                    localDuration = Date().timeIntervalSince(startTime)
                    localStats = crawler.getCoverageStats()
                    throw error
                }

                return (
                    localDuration,
                    localStats!,
                    (verificationsPerformed, verificationsPassed, verificationsFailed, retryAttempts)
                )
            }.value
        }

        // Get action statistics from exploration path
        let (successfulActions, failedActions) = crawler.explorationPath?.successRate ?? (0, 0)

        // Check if we have crashes
        let hasCrashes = crawler.explorationPath?.steps.contains { $0.didCauseCrash } ?? false
        let crashesDetected = hasCrashes ? 1 : 0

        // Generate test files if configured and there were failures or crashes
        var testFileURL: URL?
        var reportFileURL: URL?
        var crashTestFileURL: URL?
        var dashboardURL: URL?

        if config.generateTests, let explorationPath = crawler.explorationPath, (failedActions > 0 || hasCrashes) {
            do {
                // Use the SAME output directory that was created for screenshots
                let finalOutputDir = outputDir ?? {
                    try! determineOutputDirectory(
                        configured: config.outputDirectory,
                        sessionId: explorationPath.sessionId,
                        saveToProjectRoot: config.saveToProjectRoot
                    )
                }()

                try FileManager.default.createDirectory(at: finalOutputDir, withIntermediateDirectories: true)

                // Save test suite (if there were non-crash failures)
                if failedActions > 0 {
                    testFileURL = finalOutputDir.appendingPathComponent("GeneratedTests.swift")
                    try explorationPath.saveTestSuite(to: testFileURL!, className: "GeneratedUITests")
                }

                // Save crash test (if crash detected)
                if hasCrashes, let crashStep = explorationPath.steps.first(where: { $0.didCauseCrash }) {
                    crashTestFileURL = finalOutputDir.appendingPathComponent("CrashReproductionTest.swift")
                    try explorationPath.saveCrashTest(for: crashStep, to: crashTestFileURL!)
                }

                // Save failure report (if there were non-crash failures)
                if failedActions > 0 {
                    reportFileURL = finalOutputDir.appendingPathComponent("FailureReport.md")
                    try explorationPath.saveFailureReport(to: reportFileURL!)
                }

                if config.verboseOutput {
                    print("\n📁 Generated test artifacts:")
                    if let testFile = testFileURL {
                        print("   Tests: \(testFile.path)")
                    }
                    if let crashTest = crashTestFileURL {
                        print("   💥 Crash Test: \(crashTest.path)")
                    }
                    if let report = reportFileURL {
                        print("   Report: \(report.path)")
                    }
                }
            } catch {
                print("⚠️  Failed to save test artifacts: \(error)")
            }
        }

        // Create result
        let result = ExplorationResult(
            screensDiscovered: stats.totalScreens,
            transitions: stats.totalEdges,
            duration: duration,
            navigationGraph: crawler.navigationGraph,
            successfulActions: successfulActions,
            failedActions: failedActions,
            generatedTestFile: testFileURL,
            generatedReportFile: reportFileURL,
            verificationsPerformed: verificationStats.0,
            verificationsPassed: verificationStats.1,
            verificationsFailed: verificationStats.2,
            retryAttempts: verificationStats.3,
            startTime: startTime,
            crashesDetected: crashesDetected
        )

        // Generate interactive HTML dashboard
        if config.generateDashboard {
            do {
                let dashboardOutputDir: URL
                if let testFile = testFileURL {
                    // Use same directory as tests
                    dashboardOutputDir = testFile.deletingLastPathComponent()
                } else if let existingOutputDir = outputDir {
                    // Use the SAME output directory that was created for screenshots
                    dashboardOutputDir = existingOutputDir
                    try FileManager.default.createDirectory(at: dashboardOutputDir, withIntermediateDirectories: true)
                } else if let explorationPath = crawler.explorationPath {
                    // Create directory even if no tests generated (fallback, shouldn't happen)
                    dashboardOutputDir = try determineOutputDirectory(
                        configured: config.outputDirectory,
                        sessionId: explorationPath.sessionId,
                        saveToProjectRoot: config.saveToProjectRoot
                    )
                    try FileManager.default.createDirectory(at: dashboardOutputDir, withIntermediateDirectories: true)
                } else {
                    // Fallback to temp directory
                    dashboardOutputDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("AITestScoutExplorations")
                        .appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: dashboardOutputDir, withIntermediateDirectories: true)
                }

                // Generate dashboard HTML
                let dashboardGenerator = DashboardGenerator()
                // Use crash test code if no regular test file exists (crash-only scenarios)
                let testCode: String?
                if let testFile = testFileURL {
                    testCode = try? String(contentsOf: testFile, encoding: .utf8)
                } else if let crashTest = crashTestFileURL {
                    testCode = try? String(contentsOf: crashTest, encoding: .utf8)
                } else {
                    testCode = nil
                }
                let htmlContent = dashboardGenerator.generate(
                    result: result,
                    generatedTestCode: testCode,
                    steps: crawler.explorationPath?.steps
                )

                // Save dashboard
                dashboardURL = dashboardOutputDir.appendingPathComponent("dashboard.html")
                try htmlContent.write(to: dashboardURL!, atomically: true, encoding: String.Encoding.utf8)

                if config.verboseOutput {
                    print("   Dashboard: \(dashboardURL!.path)")
                }

                // Auto-open dashboard in browser
                if config.autoOpenDashboard {
                    openInBrowser(url: dashboardURL!)
                    if config.verboseOutput {
                        print("\n🌐 Opening dashboard in browser...")
                        print("   If it doesn't open automatically, paste this into your browser:")
                        print("   file://\(dashboardURL!.path)")
                    }
                }
            } catch {
                print("⚠️  Failed to generate dashboard: \(error)")
            }
        }

        // Export exploration data in backend-compatible format
        if let explorationPath = crawler.explorationPath {
            do {
                // Determine output directory (reuse existing or create new)
                let explorationDataOutputDir: URL
                if let existingOutputDir = outputDir {
                    explorationDataOutputDir = existingOutputDir
                } else {
                    // Create directory if not already created
                    explorationDataOutputDir = try determineOutputDirectory(
                        configured: config.outputDirectory,
                        sessionId: explorationPath.sessionId,
                        saveToProjectRoot: config.saveToProjectRoot
                    )
                    try FileManager.default.createDirectory(at: explorationDataOutputDir, withIntermediateDirectories: true)
                }

                // Save exploration.json for backend upload
                let explorationDataFile = explorationDataOutputDir.appendingPathComponent("exploration.json")
                let exporter = ExplorationExporter()
                try exporter.saveBackendData(
                    explorationPath: explorationPath,
                    navigationGraph: crawler.navigationGraph,
                    to: explorationDataFile,
                    metadata: explorationPath.metadata
                )

                if config.verboseOutput {
                    print("   Exploration Data: \(explorationDataFile.path)")
                }
            } catch {
                print("⚠️  Failed to export exploration data: \(error)")
            }
        }

        // No longer need to copy - files are already in project root by default

        // Show summary output if verbose
        if config.verboseOutput {
            printExplorationSummary(result: result, config: config)
        }

        // Store for later access
        _lastResult = result

        return result
    }

    // MARK: - Private Helpers

    /// Determine the output directory for generated files
    /// Uses smart defaults: Temp directory (safe for iOS sandbox) or project root (for CI)
    nonisolated private static func determineOutputDirectory(configured: URL?, sessionId: UUID, saveToProjectRoot: Bool = false) throws -> URL {
        // Use configured directory if provided
        if let configured = configured {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            let sessionFolder = "\(timestamp)_\(sessionId.uuidString.prefix(8))"
            return configured.appendingPathComponent(sessionFolder)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let sessionFolder = "\(timestamp)_\(sessionId.uuidString.prefix(8))"

        // If saveToProjectRoot is enabled (typically for CI), try to use project root
        if saveToProjectRoot {
            do {
                let projectRoot = try findProjectRoot()

                // Verify we're not at filesystem root (sandbox issue)
                if projectRoot.path != "/" && projectRoot.path != "//" {
                    let scoutResultsDir = projectRoot.appendingPathComponent("scout-results")

                    // Test if we can write to this location
                    let testFile = scoutResultsDir.appendingPathComponent(".write-test")
                    do {
                        try FileManager.default.createDirectory(at: scoutResultsDir, withIntermediateDirectories: true)
                        try Data().write(to: testFile)
                        try FileManager.default.removeItem(at: testFile)

                        // Success! We can write to project root
                        return scoutResultsDir.appendingPathComponent(sessionFolder)
                    } catch {
                        // Can't write to project root (iOS sandbox), fall back to temp
                        print("⚠️  Cannot write to project root (sandboxed environment), using temp directory")
                    }
                }
            } catch {
                print("⚠️  Could not find project root, using temp directory")
            }
        }

        // Default: Use temp directory (works in iOS sandbox)
        let tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("AITestScoutExplorations")

        return tempBase.appendingPathComponent(sessionFolder)
    }

    /// Finds the project root directory by looking for common project markers
    /// - Returns: URL to the project root directory
    /// - Throws: Error if project root cannot be determined
    nonisolated private static func findProjectRoot() throws -> URL {
        let fileManager = FileManager.default
        var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        // Look for project markers (Package.swift, .git, *.xcodeproj, *.xcworkspace)
        let projectMarkers = ["Package.swift", ".git", ".xcodeproj", ".xcworkspace"]

        // Search up to 10 levels up
        for _ in 0..<10 {
            // Check if any project marker exists in current directory
            for marker in projectMarkers {
                if marker.hasPrefix(".") && !marker.contains(".") {
                    // Directory marker like .git
                    let markerPath = currentDir.appendingPathComponent(marker)
                    if fileManager.fileExists(atPath: markerPath.path) {
                        return currentDir
                    }
                } else if marker.contains(".") {
                    // File extension marker like .xcodeproj
                    let contents = try? fileManager.contentsOfDirectory(atPath: currentDir.path)
                    if let contents = contents, contents.contains(where: { $0.hasSuffix(marker) }) {
                        return currentDir
                    }
                } else {
                    // File marker like Package.swift
                    let markerPath = currentDir.appendingPathComponent(marker)
                    if fileManager.fileExists(atPath: markerPath.path) {
                        return currentDir
                    }
                }
            }

            // Move up one directory
            let parentDir = currentDir.deletingLastPathComponent()
            if parentDir.path == currentDir.path {
                // Reached root, can't go up further
                break
            }
            currentDir = parentDir
        }

        // Fallback: use current directory
        return URL(fileURLWithPath: fileManager.currentDirectoryPath)
    }

    /// Opens a URL in the default system browser
    /// - Parameter url: The URL to open
    nonisolated private static func openInBrowser(url: URL) {
        #if os(macOS)
        // macOS: use 'open' command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [url.path]
        try? task.run()
        #elseif os(Linux)
        // Linux: use 'xdg-open' command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        task.arguments = [url.path]
        try? task.run()
        #else
        // iOS/other: print URL (can't auto-open in simulator/device)
        print("🌐 Dashboard URL: \(url.absoluteString)")
        #endif
    }

    /// Print a formatted exploration summary for EMs
    nonisolated private static func printExplorationSummary(result: ExplorationResult, config: ExplorationConfig) {

        // Show crash information
        if result.crashesDetected > 0 {
            print("""
            💥 CRASH DETECTED: App crashed during exploration
            
            A crash reproduction test has been generated
            """)
        }

        if result.hasCriticalFailures {
            print("""
            ⚠️  ISSUES FOUND: \(result.failedActions)

            Check the generated test file for reproduction steps
            """)
        } else if result.crashesDetected == 0 {
            print("🎉 Perfect Exploration! All interactions succeeded.")
        }

        if let testFile = result.generatedTestFile, let reportFile = result.generatedReportFile {
            print("""
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            📁 GENERATED FILES
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            Tests:  file://\(testFile.path)
            Report: file://\(reportFile.path)
            """)
        }

        print("""
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Generated by Xamrock AITestScout
        https://github.com/xamrock/ai-test-scout
        """)
    }
}
