import Foundation

/// Generates an interactive HTML dashboard for exploration results
@available(macOS 26.0, iOS 26.0, *)
public class DashboardGenerator {

    public init() {}

    /// Generates a complete HTML dashboard
    /// - Parameters:
    ///   - result: The exploration result
    ///   - generatedTestCode: The generated Swift test code (optional)
    ///   - steps: Exploration steps for timeline (optional)
    /// - Returns: HTML string ready to write to file
    public func generate(
        result: ExplorationResult,
        generatedTestCode: String? = nil,
        steps: [ExplorationStep]? = nil
    ) -> String {
        let stepsJSON = encodeStepsToJSON(steps ?? [])
        let navigationGraphJSON = encodeNavigationGraphToJSON(result.navigationGraph)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>AITestScout Exploration Report - Xamrock</title>
            <style>
                \(cssStyles)
            </style>
        </head>
        <body>
            <div class="container">
                \(headerSection())
                \(heroStatusCard(result: result))
                \(journeyTimeline(steps: steps ?? []))
                \(generatedTestsSection(testCode: generatedTestCode))
                \(coverageMapSection(result: result))
                \(detailedMetricsSection(result: result))
                \(footerSection())
            </div>

            <div id="keyboard-hints" class="keyboard-hints">
                <div class="hint-title">Keyboard Shortcuts</div>
                <div class="hint-item"><kbd>C</kbd> Copy all tests</div>
                <div class="hint-item"><kbd>E</kbd> Expand all</div>
                <div class="hint-item"><kbd>F</kbd> Show failures</div>
                <div class="hint-item"><kbd>/</kbd> Search</div>
                <div class="hint-item"><kbd>Esc</kbd> Collapse all</div>
                <div class="hint-footer">Press <kbd>?</kbd> to toggle</div>
            </div>

            <div id="screenshot-modal" class="screenshot-modal" onclick="closeScreenshot(event)">
                <div class="screenshot-modal-content">
                    <button class="screenshot-modal-close" onclick="closeScreenshot(event)">Close (Esc)</button>
                    <img id="screenshot-modal-img" src="" alt="Screenshot">
                    <div class="screenshot-modal-caption" id="screenshot-modal-caption"></div>
                </div>
            </div>

            <script>
                // Embed data
                const EXPLORATION_DATA = {
                    result: \(encodeResultToJSON(result)),
                    steps: \(stepsJSON),
                    navigationGraph: \(navigationGraphJSON),
                    testCode: \(generatedTestCode != nil ? "\"\(escapeJavaScript(generatedTestCode!))\"" : "null")
                };

                \(javascript)
            </script>
        </body>
        </html>
        """
    }

    // MARK: - HTML Sections

    private func headerSection() -> String {
        return """
        <header class="header">
            <div class="header-left">
                <div class="logo">
                    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
                        <rect width="28" height="28" rx="6" fill="url(#gradient)"/>
                        <path d="M8 14L12 18L20 10" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
                        <defs>
                            <linearGradient id="gradient" x1="0" y1="0" x2="28" y2="28">
                                <stop offset="0%" stop-color="#5e6ad2"/>
                                <stop offset="100%" stop-color="#6875e2"/>
                            </linearGradient>
                        </defs>
                    </svg>
                    <span class="logo-text">Xamrock <span class="logo-product">AITestScout</span></span>
                </div>
            </div>
            <div class="header-right">
                <button class="icon-btn" onclick="toggleKeyboardHints()" title="Keyboard shortcuts (?)">
                    <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                        <path d="M8 0C3.58 0 0 3.58 0 8s3.58 8 8 8 8-3.58 8-8-3.58-8-8-8zm.5 13H7.5v-1.5h1V13zm1.5-4.5h-1V11h-2V7.5h1c.83 0 1.5-.67 1.5-1.5S8.83 4.5 8 4.5 6.5 5.17 6.5 6H5c0-1.66 1.34-3 3-3s3 1.34 3 3c0 1.29-.82 2.39-1.96 2.81z"/>
                    </svg>
                </button>
                <div class="header-timestamp" id="timestamp"></div>
            </div>
        </header>
        """
    }

    private func heroStatusCard(result: ExplorationResult) -> String {
        let healthScore = calculateHealthScore(result: result)
        // Crashes take priority over other failures
        let hasCrashes = result.crashesDetected > 0
        let statusIcon = hasCrashes ? "💥" : (result.hasCriticalFailures ? "⚠️" : "✅")
        let statusText = hasCrashes ? "Crash Detected" : (result.hasCriticalFailures ? "Issues Found" : "All Clear")

        return """
        <section class="hero-card">
            <div class="hero-content">
                <div class="status-group">
                    <div class="status-icon">\(statusIcon)</div>
                    <div class="status-details">
                        <div class="status-text">\(statusText)</div>
                        <div class="status-subtitle">Health Score: \(healthScore)</div>
                    </div>
                </div>
                <div class="metric-group">
                    <div class="metric-compact">
                        <span class="metric-label">Screens</span>
                        <span class="metric-value">\(result.screensDiscovered)</span>
                    </div>
                    <div class="metric-compact">
                        <span class="metric-label">Success</span>
                        <span class="metric-value">\(result.successRatePercent)%</span>
                    </div>
                    <div class="metric-compact">
                        <span class="metric-label">Duration</span>
                        <span class="metric-value">\(formatDuration(result.duration))</span>
                    </div>
                    <div class="metric-compact">
                        <span class="metric-label">Transitions</span>
                        <span class="metric-value">\(result.transitions)</span>
                    </div>
                </div>
            </div>
        </section>
        """
    }

    private func journeyTimeline(steps: [ExplorationStep]) -> String {
        guard !steps.isEmpty else { return "" }

        let failedCount = steps.filter { !$0.wasSuccessful }.count

        return """
        <section class="timeline-section">
            <div class="section-header">
                <div class="section-title">
                    <h2>Journey Timeline</h2>
                    <span class="section-badge">\(steps.count) steps</span>
                    \(failedCount > 0 ? "<span class=\"section-badge badge-warning\">\(failedCount) failed</span>" : "")
                </div>
                <div class="section-controls">
                    <input type="text" id="timeline-search" class="search-input" placeholder="Search steps... (/)" />
                    <select id="timeline-filter" class="filter-select">
                        <option value="all">All Steps</option>
                        <option value="success">✅ Success Only</option>
                        <option value="failed">❌ Failed Only</option>
                        <option value="crash">💥 Crashes Only</option>
                        <option value="retry">🔄 Retries Only</option>
                    </select>
                </div>
            </div>
            <div class="timeline" id="timeline">
                \(renderTimelineSteps(steps))
            </div>
        </section>
        """
    }

    private func renderTimelineSteps(_ steps: [ExplorationStep]) -> String {
        return steps.enumerated().map { index, step in
            // Crash steps get special treatment
            let isCrash = step.didCauseCrash
            let statusClass = isCrash ? "step-crash" : (step.wasSuccessful ? "step-success" : "step-failure")
            let icon = isCrash ? "💥" : (step.wasSuccessful ? "✅" : "❌")
            let retryBadge = step.wasRetry ? "<span class=\"retry-badge\">🔄 Retry</span>" : ""
            let crashBadge = isCrash ? "<span class=\"crash-badge\">💥 CRASH</span>" : ""
            let targetText = step.targetElement ?? "N/A"
            let textTyped = step.textTyped.map { text in " \"\(text)\"" } ?? ""
            let confidence = step.confidence
            let confidenceClass = confidence >= 80 ? "high" : (confidence >= 50 ? "medium" : "low")

            let verificationHTML: String
            if let verification = step.verificationResult {
                let vIcon = verification.passed ? "✓" : "✗"
                verificationHTML = """
                <div class="step-verification">
                    <span class="verification-icon \(verification.passed ? "verified" : "failed")">\(vIcon)</span>
                    <span class="verification-text">\(escapeHtml(verification.reason))</span>
                </div>
                """
            } else {
                verificationHTML = ""
            }

            let screenshotHTML: String
            if let screenshotPath = step.screenshotPath {
                screenshotHTML = """
                <div class="detail-row">
                    <span class="detail-label">Screenshot:</span>
                </div>
                <div class="screenshot-preview">
                    <img src="\(escapeHtml(screenshotPath))"
                         alt="Step \(index + 1) screenshot"
                         onclick="openScreenshot('\(escapeJavaScript(screenshotPath))', \(index + 1))"
                         loading="lazy">
                </div>
                """
            } else {
                screenshotHTML = ""
            }

            // AI Interaction section
            let aiInteractionHTML: String
            if !step.aiPrompt.isEmpty || !step.aiResponse.isEmpty {
                aiInteractionHTML = """
                <div class="ai-interaction-section">
                    <div class="ai-section-header" onclick="event.stopPropagation(); toggleAISection(\(index))">
                        <span class="ai-section-title">🤖 AI Interaction</span>
                        <span class="ai-expand-hint">(click to expand)</span>
                    </div>
                    <div class="ai-section-content" id="ai-section-\(index)">
                        \(!step.aiPrompt.isEmpty ? """
                        <div class="ai-prompt">
                            <div class="ai-label">📝 Prompt Sent:</div>
                            <pre class="ai-code">\(escapeHtml(step.aiPrompt))</pre>
                        </div>
                        """ : "")
                        \(!step.aiResponse.isEmpty ? """
                        <div class="ai-response">
                            <div class="ai-label">🤖 Response Received:</div>
                            <pre class="ai-code">\(escapeHtml(step.aiResponse))</pre>
                        </div>
                        """ : "")
                    </div>
                </div>
                """
            } else {
                aiInteractionHTML = ""
            }

            return """
            <div class="timeline-item \(statusClass)" data-step="\(index)" data-action="\(step.action)" data-success="\(step.wasSuccessful)" data-retry="\(step.wasRetry)" data-crash="\(isCrash)">
                <div class="timeline-connector"></div>
                <div class="timeline-marker">\(icon)</div>
                <div class="timeline-card" onclick="toggleStep(\(index))">
                    <div class="timeline-compact">
                        <div class="timeline-compact-left">
                            <span class="step-number">#\(index + 1)</span>
                            <span class="step-action">\(step.action.uppercased())</span>
                            <span class="step-target">\(escapeHtml(targetText))\(escapeHtml(textTyped))</span>
                            \(crashBadge)
                            \(retryBadge)
                        </div>
                        <div class="timeline-compact-right">
                            <span class="confidence-badge confidence-\(confidenceClass)">\(confidence)%</span>
                            <svg class="expand-icon" width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                                <path d="M4 6l4 4 4-4z"/>
                            </svg>
                        </div>
                    </div>
                    <div class="timeline-details">
                        <div class="detail-row">
                            <span class="detail-label">Screen:</span>
                            <span class="detail-value">\(escapeHtml(step.screenDescription))</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Interactive Elements:</span>
                            <span class="detail-value">\(step.interactiveElementCount)</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Reasoning:</span>
                            <span class="detail-value">\(escapeHtml(step.reasoning))</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Confidence:</span>
                            <span class="detail-value">\(confidence)% (\(confidenceClass))</span>
                        </div>
                        \(verificationHTML)
                        \(screenshotHTML)
                        \(aiInteractionHTML)
                    </div>
                </div>
            </div>
            """
        }.joined(separator: "\n")
    }

    private func generatedTestsSection(testCode: String?) -> String {
        guard let code = testCode, !code.isEmpty else { return "" }

        return """
        <section class="collapsible-section" id="section-tests">
            <div class="section-header clickable" onclick="toggleSection('tests')">
                <div class="section-title">
                    <h2>Generated Tests</h2>
                    <span class="section-badge">Swift</span>
                </div>
                <div class="section-controls">
                    <button class="btn btn-small" onclick="event.stopPropagation(); copyCode('generated-tests')">
                        📋 Copy All
                    </button>
                    <svg class="expand-icon" width="20" height="20" viewBox="0 0 16 16" fill="currentColor">
                        <path d="M4 6l4 4 4-4z"/>
                    </svg>
                </div>
            </div>
            <div class="section-content">
                <div class="code-container">
                    <pre id="generated-tests" class="code-block"><code class="language-swift">\(escapeHtml(code))</code></pre>
                </div>
            </div>
        </section>
        """
    }

    private func coverageMapSection(result: ExplorationResult) -> String {
        let graph = result.navigationGraph
        let screensList = Array(graph.nodes.values.prefix(10)) // Show max 10 screens

        let screensHTML = screensList.enumerated().map { index, node in
            let screenTypeLabel = node.screenType?.rawValue ?? "Screen"
            return """
            <div class="screen-item">
                <div class="screen-number">\(index + 1)</div>
                <div class="screen-info">
                    <div class="screen-hash">\(screenTypeLabel) · \(String(node.fingerprint.prefix(8)))</div>
                    <div class="screen-visits">\(node.visitCount)x visited</div>
                </div>
            </div>
            """
        }.joined(separator: "\n")

        return """
        <section class="collapsible-section" id="section-coverage">
            <div class="section-header clickable" onclick="toggleSection('coverage')">
                <div class="section-title">
                    <h2>Screen Coverage</h2>
                    <span class="section-badge">\(result.screensDiscovered) screens</span>
                    <span class="section-badge">\(result.transitions) transitions</span>
                </div>
                <svg class="expand-icon" width="20" height="20" viewBox="0 0 16 16" fill="currentColor">
                    <path d="M4 6l4 4 4-4z"/>
                </svg>
            </div>
            <div class="section-content">
                <div class="screens-list">
                    \(screensHTML.isEmpty ? "<p style='color: var(--text-muted); padding: 16px;'>No screen data available</p>" : screensHTML)
                </div>
            </div>
        </section>
        """
    }

    private func detailedMetricsSection(result: ExplorationResult) -> String {
        var metricsHTML = """
        <div class="metrics-grid">
            <div class="metric-item">
                <div class="metric-header">
                    <span class="metric-icon">🎯</span>
                    <span class="metric-title">Success Rate</span>
                </div>
                <div class="metric-value">\(result.successRatePercent)%</div>
                <div class="metric-detail">\(result.successfulActions) of \(result.totalActions) actions</div>
                <div class="metric-bar">
                    <div class="metric-fill success" style="width: \(result.successRatePercent)%"></div>
                </div>
            </div>
        """

        if result.verificationsPerformed > 0 {
            metricsHTML += """
            <div class="metric-item">
                <div class="metric-header">
                    <span class="metric-icon">🔍</span>
                    <span class="metric-title">Verification Rate</span>
                </div>
                <div class="metric-value">\(result.verificationSuccessRate)%</div>
                <div class="metric-detail">\(result.verificationsPassed) of \(result.verificationsPerformed) passed</div>
                <div class="metric-bar">
                    <div class="metric-fill verified" style="width: \(result.verificationSuccessRate)%"></div>
                </div>
            </div>
            """
        }

        if result.retryAttempts > 0 {
            metricsHTML += """
            <div class="metric-item">
                <div class="metric-header">
                    <span class="metric-icon">🔄</span>
                    <span class="metric-title">Retry Attempts</span>
                </div>
                <div class="metric-value">\(result.retryAttempts)</div>
                <div class="metric-detail">Alternative actions tried</div>
            </div>
            """
        }

        // Add crash metrics if crashes detected
        if result.crashesDetected > 0 {
            metricsHTML += """
            <div class="metric-item metric-crash">
                <div class="metric-header">
                    <span class="metric-icon">💥</span>
                    <span class="metric-title">Crash Detected</span>
                </div>
                <div class="metric-value">\(result.crashesDetected)</div>
                <div class="metric-detail">App crashed during exploration</div>
                <div class="metric-action">
                    <button class="btn btn-small" onclick="document.getElementById('timeline-filter').value='crash'; document.getElementById('timeline-filter').dispatchEvent(new Event('change'));">
                        View Crash Steps
                    </button>
                </div>
            </div>
            """
        }

        metricsHTML += """
            <div class="metric-item">
                <div class="metric-header">
                    <span class="metric-icon">⏱️</span>
                    <span class="metric-title">Execution Time</span>
                </div>
                <div class="metric-value">\(formatDuration(result.duration))</div>
                <div class="metric-detail">Total exploration time</div>
            </div>
        </div>
        """

        return """
        <section class="collapsible-section" id="section-metrics">
            <div class="section-header clickable" onclick="toggleSection('metrics')">
                <div class="section-title">
                    <h2>Detailed Metrics</h2>
                </div>
                <svg class="expand-icon" width="20" height="20" viewBox="0 0 16 16" fill="currentColor">
                    <path d="M4 6l4 4 4-4z"/>
                </svg>
            </div>
            <div class="section-content">
                \(metricsHTML)
            </div>
        </section>
        """
    }

    private func footerSection() -> String {
        return """
        <footer class="footer">
            <div class="footer-content">
                <div class="footer-left">
                    <div class="footer-logo">
                        <svg width="20" height="20" viewBox="0 0 28 28" fill="none">
                            <rect width="28" height="28" rx="6" fill="url(#gradient-footer)"/>
                            <path d="M8 14L12 18L20 10" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
                            <defs>
                                <linearGradient id="gradient-footer" x1="0" y1="0" x2="28" y2="28">
                                    <stop offset="0%" stop-color="#5e6ad2"/>
                                    <stop offset="100%" stop-color="#6875e2"/>
                                </linearGradient>
                            </defs>
                        </svg>
                        <span>Powered by <strong>Xamrock AITestScout</strong></span>
                    </div>
                    <div class="footer-tagline">AI-powered iOS test exploration & generation</div>
                </div>
                <div class="footer-right">
                    <a href="https://github.com/xamrock/ai-test-scout" target="_blank" class="footer-link">
                        <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor">
                            <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
                        </svg>
                        GitHub
                    </a>
                    <a href="https://xamrock.com" target="_blank" class="footer-link">
                        <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor">
                            <path d="M8 0C3.6 0 0 3.6 0 8s3.6 8 8 8 8-3.6 8-8-3.6-8-8-8zm0 12c-2.2 0-4-1.8-4-4s1.8-4 4-4 4 1.8 4 4-1.8 4-4 4zm1-6H7v4h2V6z"/>
                        </svg>
                        Xamrock.com
                    </a>
                </div>
            </div>
        </footer>
        """
    }

    // MARK: - Helper Functions

    private func calculateHealthScore(result: ExplorationResult) -> Int {
        var score = result.successRatePercent

        // Bonus for high coverage
        if result.screensDiscovered >= 5 {
            score = min(100, score + 5)
        }

        // Bonus for high verification rate
        if result.verificationsPerformed > 0 && result.verificationSuccessRate >= 80 {
            score = min(100, score + 5)
        }

        // Penalty for failures
        if result.failedActions > 0 {
            score = max(0, score - (result.failedActions * 2))
        }

        return score
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)m \(remainingSeconds)s"
    }

    private func escapeHtml(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func escapeJavaScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func highlightSwiftCode(_ code: String) -> String {
        var highlighted = code

        // Keywords
        let keywords = ["import", "class", "func", "let", "var", "if", "else", "for", "while", "return", "throw", "try", "catch", "guard", "switch", "case", "break", "continue", "public", "private", "override", "static", "final", "struct", "enum", "protocol", "extension", "self", "super"]
        for keyword in keywords {
            highlighted = highlighted.replacingOccurrences(
                of: "\\b\(keyword)\\b",
                with: "<span class=\"keyword\">\(keyword)</span>",
                options: .regularExpression
            )
        }

        // Strings
        highlighted = highlighted.replacingOccurrences(
            of: "\"([^\"]*?)\"",
            with: "<span class=\"string\">\"$1\"</span>",
            options: .regularExpression
        )

        // Comments
        highlighted = highlighted.replacingOccurrences(
            of: "//(.*)$",
            with: "<span class=\"comment\">//$1</span>",
            options: .regularExpression
        )

        return highlighted
    }

    private func encodeStepsToJSON(_ steps: [ExplorationStep]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(steps),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return json
    }

    private func encodeNavigationGraphToJSON(_ graph: NavigationGraph) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(graph),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"nodes\": {}, \"edges\": []}"
        }

        return json
    }

    private func encodeResultToJSON(_ result: ExplorationResult) -> String {
        let startTimeMs = Int(result.startTime.timeIntervalSince1970 * 1000)
        return """
        {
            "screensDiscovered": \(result.screensDiscovered),
            "transitions": \(result.transitions),
            "duration": \(result.duration),
            "successfulActions": \(result.successfulActions),
            "failedActions": \(result.failedActions),
            "successRatePercent": \(result.successRatePercent),
            "verificationsPerformed": \(result.verificationsPerformed),
            "verificationsPassed": \(result.verificationsPassed),
            "verificationsFailed": \(result.verificationsFailed),
            "retryAttempts": \(result.retryAttempts),
            "hasCriticalFailures": \(result.hasCriticalFailures),
            "startTime": \(startTimeMs)
        }
        """
    }

    // MARK: - CSS Styles

    private var cssStyles: String {
        return """
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --bg-primary: #0d0e12;
            --bg-secondary: #16171d;
            --bg-elevated: #1a1b21;
            --border-subtle: rgba(255, 255, 255, 0.06);
            --border-medium: rgba(255, 255, 255, 0.12);
            --text-primary: #e6eaf0;
            --text-secondary: #b4bcd0;
            --text-muted: #6c7489;
            --accent-purple: #5e6ad2;
            --accent-purple-hover: #6875e2;
            --success: #3dd68c;
            --warning: #f5a524;
            --error: #ef4444;
            --transition: 200ms cubic-bezier(0.4, 0, 0.2, 1);
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, sans-serif;
            background: var(--bg-primary);
            color: var(--text-secondary);
            line-height: 1.6;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
            min-height: 100vh;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: var(--bg-secondary);
            min-height: 100vh;
        }

        /* Header */
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 20px 32px;
            border-bottom: 1px solid var(--border-subtle);
            background: var(--bg-secondary);
        }

        .header-left {
            display: flex;
            align-items: center;
            gap: 16px;
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .logo-text {
            font-size: 1rem;
            font-weight: 600;
            color: var(--text-primary);
            letter-spacing: -0.01em;
        }

        .logo-product {
            color: var(--text-muted);
            font-weight: 400;
        }

        .header-right {
            display: flex;
            align-items: center;
            gap: 16px;
        }

        .icon-btn {
            background: transparent;
            border: 1px solid var(--border-medium);
            border-radius: 6px;
            padding: 8px;
            cursor: pointer;
            color: var(--text-muted);
            transition: all var(--transition);
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .icon-btn:hover {
            background: var(--bg-elevated);
            border-color: var(--border-medium);
            color: var(--text-secondary);
        }

        .header-timestamp {
            font-size: 0.875rem;
            color: var(--text-muted);
        }

        /* Hero Card */
        .hero-card {
            margin: 16px 32px;
            background: linear-gradient(135deg, rgba(94, 106, 210, 0.05) 0%, rgba(94, 106, 210, 0.02) 100%);
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            padding: 16px 24px;
            position: relative;
        }

        .hero-content {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 32px;
        }

        .status-group {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .status-icon {
            font-size: 2rem;
            line-height: 1;
        }

        .status-details {
            display: flex;
            flex-direction: column;
            gap: 2px;
        }

        .status-text {
            font-size: 1rem;
            font-weight: 600;
            color: var(--text-primary);
            letter-spacing: -0.01em;
            line-height: 1.2;
        }

        .status-subtitle {
            font-size: 0.75rem;
            color: var(--text-muted);
            font-weight: 500;
        }

        .metric-group {
            display: flex;
            gap: 32px;
            align-items: center;
        }

        .metric-compact {
            display: flex;
            flex-direction: column;
            align-items: flex-end;
            gap: 2px;
        }

        .metric-compact .metric-label {
            font-size: 0.75rem;
            color: var(--text-muted);
            font-weight: 500;
        }

        .metric-compact .metric-value {
            font-size: 1.25rem;
            font-weight: 600;
            color: var(--text-primary);
            letter-spacing: -0.01em;
            line-height: 1;
        }

        /* Timeline Section */
        .timeline-section {
            margin: 0 32px 24px;
        }

        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding: 0 8px;
        }

        .section-header.clickable {
            cursor: pointer;
            padding: 16px;
            margin: 0 -16px 20px;
            border-radius: 8px;
            transition: background var(--transition);
        }

        .section-header.clickable:hover {
            background: rgba(255, 255, 255, 0.02);
        }

        .section-title {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .section-title h2 {
            font-size: 1.125rem;
            font-weight: 600;
            color: var(--text-primary);
            letter-spacing: -0.01em;
        }

        .section-badge {
            padding: 4px 10px;
            background: rgba(255, 255, 255, 0.06);
            border-radius: 4px;
            font-size: 0.75rem;
            color: var(--text-secondary);
            font-weight: 500;
        }

        .badge-warning {
            background: rgba(239, 68, 68, 0.15);
            color: var(--error);
        }

        .section-controls {
            display: flex;
            gap: 12px;
            align-items: center;
        }

        .search-input {
            padding: 8px 12px;
            background: var(--bg-elevated);
            border: 1px solid var(--border-subtle);
            border-radius: 6px;
            color: var(--text-secondary);
            font-size: 0.875rem;
            width: 200px;
            transition: all var(--transition);
        }

        .search-input:focus {
            outline: none;
            border-color: var(--accent-purple);
        }

        .search-input::placeholder {
            color: var(--text-muted);
        }

        .filter-select {
            padding: 8px 12px;
            background: var(--bg-elevated);
            border: 1px solid var(--border-subtle);
            border-radius: 6px;
            color: var(--text-secondary);
            font-size: 0.875rem;
            cursor: pointer;
            transition: all var(--transition);
        }

        .filter-select:hover {
            border-color: var(--border-medium);
        }

        .filter-select:focus {
            outline: none;
            border-color: var(--accent-purple);
        }

        /* Timeline */
        .timeline {
            position: relative;
            display: flex;
            flex-direction: column;
            gap: 2px;
        }

        .timeline-item {
            position: relative;
            display: flex;
            gap: 16px;
            padding-left: 40px;
        }

        .timeline-item.hidden {
            display: none;
        }

        .timeline-connector {
            position: absolute;
            left: 16px;
            top: 32px;
            width: 1px;
            height: calc(100% + 2px);
            background: var(--border-subtle);
        }

        .timeline-item:last-child .timeline-connector {
            display: none;
        }

        .timeline-marker {
            position: absolute;
            left: 8px;
            top: 8px;
            width: 18px;
            height: 18px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.625rem;
            background: var(--bg-elevated);
            border: 2px solid var(--border-medium);
            border-radius: 50%;
        }

        .step-success .timeline-marker {
            border-color: var(--success);
            background: rgba(61, 214, 140, 0.15);
        }

        .step-failure .timeline-marker {
            border-color: var(--error);
            background: rgba(239, 68, 68, 0.15);
        }

        .step-crash .timeline-marker {
            border-color: var(--warning);
            background: rgba(245, 165, 36, 0.2);
            animation: pulse 2s ease-in-out infinite;
        }

        @keyframes pulse {
            0%, 100% {
                transform: scale(1);
                opacity: 1;
            }
            50% {
                transform: scale(1.1);
                opacity: 0.8;
            }
        }

        .timeline-card {
            flex: 1;
            background: rgba(255, 255, 255, 0.02);
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            padding: 12px 16px;
            cursor: pointer;
            transition: all var(--transition);
        }

        .timeline-card:hover {
            background: rgba(255, 255, 255, 0.04);
            border-color: var(--border-medium);
        }

        .step-failure .timeline-card {
            border-left: 2px solid var(--error);
        }

        .step-crash .timeline-card {
            border-left: 3px solid var(--warning);
            background: rgba(245, 165, 36, 0.05);
        }

        .timeline-compact {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 16px;
        }

        .timeline-compact-left {
            display: flex;
            align-items: center;
            gap: 12px;
            flex: 1;
            min-width: 0;
        }

        .timeline-compact-right {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .step-number {
            color: var(--accent-purple);
            font-weight: 600;
            font-size: 0.875rem;
            flex-shrink: 0;
        }

        .step-action {
            padding: 2px 8px;
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid var(--border-subtle);
            border-radius: 4px;
            font-size: 0.75rem;
            font-weight: 600;
            color: var(--text-muted);
            flex-shrink: 0;
        }

        .step-target {
            color: var(--text-secondary);
            font-size: 0.875rem;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .retry-badge {
            padding: 2px 6px;
            background: rgba(245, 158, 11, 0.15);
            border-radius: 4px;
            font-size: 0.7rem;
            color: var(--warning);
            flex-shrink: 0;
        }

        .crash-badge {
            padding: 4px 8px;
            background: rgba(245, 165, 36, 0.2);
            border: 1px solid var(--warning);
            border-radius: 4px;
            font-size: 0.75rem;
            font-weight: 700;
            color: var(--warning);
            flex-shrink: 0;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .confidence-badge {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.75rem;
            font-weight: 600;
            flex-shrink: 0;
        }

        .confidence-high {
            background: rgba(61, 214, 140, 0.15);
            color: var(--success);
        }

        .confidence-medium {
            background: rgba(245, 158, 11, 0.15);
            color: var(--warning);
        }

        .confidence-low {
            background: rgba(239, 68, 68, 0.15);
            color: var(--error);
        }

        .expand-icon {
            color: var(--text-muted);
            transition: transform var(--transition);
            flex-shrink: 0;
        }

        .timeline-card.expanded .expand-icon {
            transform: rotate(180deg);
        }

        .timeline-details {
            display: none;
            margin-top: 16px;
            padding-top: 16px;
            border-top: 1px solid var(--border-subtle);
        }

        .timeline-card.expanded .timeline-details {
            display: block;
        }

        .detail-row {
            display: flex;
            gap: 12px;
            margin-bottom: 12px;
            font-size: 0.875rem;
        }

        .detail-row:last-child {
            margin-bottom: 0;
        }

        .detail-label {
            color: var(--text-muted);
            font-weight: 500;
            min-width: 150px;
            flex-shrink: 0;
        }

        .detail-value {
            color: var(--text-secondary);
            flex: 1;
        }

        .step-verification {
            display: flex;
            align-items: flex-start;
            gap: 8px;
            padding: 12px;
            background: rgba(255, 255, 255, 0.02);
            border-radius: 6px;
            margin-top: 12px;
        }

        .verification-icon {
            flex-shrink: 0;
            width: 20px;
            height: 20px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.75rem;
            font-weight: bold;
        }

        .verification-icon.verified {
            background: rgba(61, 214, 140, 0.15);
            color: var(--success);
        }

        .verification-icon.failed {
            background: rgba(239, 68, 68, 0.15);
            color: var(--error);
        }

        .verification-text {
            flex: 1;
            font-size: 0.875rem;
            color: var(--text-secondary);
        }

        /* AI Interaction Section */
        .ai-interaction-section {
            margin-top: 16px;
            border-top: 1px solid var(--border-subtle);
            padding-top: 16px;
        }

        .ai-section-header {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 12px;
            background: rgba(94, 106, 210, 0.08);
            border: 1px solid rgba(94, 106, 210, 0.2);
            border-radius: 6px;
            cursor: pointer;
            transition: all var(--transition);
            user-select: none;
        }

        .ai-section-header:hover {
            background: rgba(94, 106, 210, 0.12);
            border-color: rgba(94, 106, 210, 0.3);
        }

        .ai-section-title {
            font-size: 0.875rem;
            font-weight: 600;
            color: var(--text-primary);
        }

        .ai-expand-hint {
            font-size: 0.75rem;
            color: var(--text-muted);
            margin-left: auto;
        }

        .ai-section-content {
            display: none;
            margin-top: 12px;
            animation: slideDown 0.2s ease-out;
        }

        .ai-section-content.visible {
            display: block;
        }

        .ai-prompt,
        .ai-response {
            margin-bottom: 16px;
        }

        .ai-prompt:last-child,
        .ai-response:last-child {
            margin-bottom: 0;
        }

        .ai-label {
            font-size: 0.8125rem;
            font-weight: 600;
            color: var(--text-muted);
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .ai-code {
            background: var(--bg-primary);
            border: 1px solid var(--border-subtle);
            border-radius: 6px;
            padding: 16px;
            font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', monospace;
            font-size: 0.75rem;
            line-height: 1.6;
            color: var(--text-secondary);
            overflow-x: auto;
            white-space: pre-wrap;
            word-wrap: break-word;
            max-height: 400px;
            overflow-y: auto;
        }

        .ai-code::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }

        .ai-code::-webkit-scrollbar-track {
            background: var(--bg-secondary);
            border-radius: 4px;
        }

        .ai-code::-webkit-scrollbar-thumb {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 4px;
        }

        .ai-code::-webkit-scrollbar-thumb:hover {
            background: rgba(255, 255, 255, 0.15);
        }

        /* Screenshot Preview */
        .screenshot-preview {
            margin-top: 12px;
            border-radius: 6px;
            overflow: hidden;
            background: rgba(255, 255, 255, 0.02);
            border: 1px solid var(--border-subtle);
            max-width: 300px;
        }

        .screenshot-preview img {
            width: 100%;
            height: auto;
            display: block;
            cursor: pointer;
            transition: opacity var(--transition);
        }

        .screenshot-preview img:hover {
            opacity: 0.85;
        }

        /* Screenshot Modal */
        .screenshot-modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.9);
            z-index: 2000;
            justify-content: center;
            align-items: center;
            padding: 24px;
        }

        .screenshot-modal.visible {
            display: flex;
        }

        .screenshot-modal-content {
            max-width: 90%;
            max-height: 90%;
            position: relative;
        }

        .screenshot-modal img {
            max-width: 100%;
            max-height: 90vh;
            display: block;
            border-radius: 8px;
            box-shadow: 0 24px 48px rgba(0, 0, 0, 0.6);
        }

        .screenshot-modal-close {
            position: absolute;
            top: -40px;
            right: 0;
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid var(--border-medium);
            border-radius: 6px;
            padding: 8px 16px;
            color: var(--text-primary);
            font-size: 0.875rem;
            cursor: pointer;
            transition: all var(--transition);
        }

        .screenshot-modal-close:hover {
            background: rgba(255, 255, 255, 0.15);
        }

        .screenshot-modal-caption {
            position: absolute;
            bottom: -40px;
            left: 0;
            right: 0;
            text-align: center;
            color: var(--text-secondary);
            font-size: 0.875rem;
        }

        /* Collapsible Sections */
        .collapsible-section {
            margin: 0 32px 24px;
        }

        .collapsible-section .section-content {
            display: none;
            margin-top: 16px;
        }

        .collapsible-section.expanded .section-content {
            display: block;
        }

        .collapsible-section.expanded .expand-icon {
            transform: rotate(180deg);
        }

        /* Code Container */
        .code-container {
            background: var(--bg-primary);
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            overflow: hidden;
        }

        .code-block {
            margin: 0;
            padding: 24px;
            background: var(--bg-primary);
            color: var(--text-secondary);
            font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', monospace;
            font-size: 0.8125rem;
            line-height: 1.7;
            overflow-x: auto;
            max-height: 600px;
        }

        .code-block .keyword {
            color: #ff79c6;
        }

        .code-block .string {
            color: #50fa7b;
        }

        .code-block .comment {
            color: #6272a4;
        }

        /* Screen Coverage List */
        .screens-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 8px;
        }

        .screen-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px;
            background: rgba(255, 255, 255, 0.02);
            border: 1px solid var(--border-subtle);
            border-radius: 6px;
            transition: all var(--transition);
        }

        .screen-item:hover {
            background: rgba(255, 255, 255, 0.04);
            border-color: var(--border-medium);
        }

        .screen-number {
            width: 32px;
            height: 32px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: rgba(94, 106, 210, 0.15);
            color: var(--accent-purple);
            border-radius: 6px;
            font-weight: 600;
            font-size: 0.875rem;
            flex-shrink: 0;
        }

        .screen-info {
            display: flex;
            flex-direction: column;
            gap: 2px;
            min-width: 0;
        }

        .screen-hash {
            font-size: 0.8125rem;
            color: var(--text-secondary);
            font-family: 'SF Mono', Monaco, monospace;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .screen-visits {
            font-size: 0.75rem;
            color: var(--text-muted);
        }

        /* Detailed Metrics */
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 16px;
        }

        .metric-item {
            background: rgba(255, 255, 255, 0.02);
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            padding: 20px;
        }

        .metric-item.metric-crash {
            background: rgba(245, 165, 36, 0.05);
            border: 1px solid rgba(245, 165, 36, 0.3);
        }

        .metric-action {
            margin-top: 12px;
        }

        .metric-action .btn {
            width: 100%;
            background: var(--warning);
            color: var(--bg-primary);
            font-weight: 600;
            border: none;
        }

        .metric-action .btn:hover {
            background: var(--accent-purple);
        }

        .metric-header {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 12px;
        }

        .metric-icon {
            font-size: 1.25rem;
        }

        .metric-title {
            font-size: 0.875rem;
            font-weight: 600;
            color: var(--text-primary);
        }

        .metric-value {
            font-size: 2rem;
            font-weight: 700;
            color: var(--text-primary);
            letter-spacing: -0.02em;
            line-height: 1;
            margin-bottom: 4px;
        }

        .metric-detail {
            font-size: 0.8125rem;
            color: var(--text-muted);
            margin-bottom: 12px;
        }

        .metric-bar {
            height: 6px;
            background: rgba(255, 255, 255, 0.06);
            border-radius: 3px;
            overflow: hidden;
        }

        .metric-fill {
            height: 100%;
            transition: width var(--transition);
        }

        .metric-fill.success {
            background: var(--success);
        }

        .metric-fill.verified {
            background: var(--accent-purple);
        }

        /* Buttons */
        .btn {
            padding: 8px 14px;
            border: 1px solid var(--border-medium);
            border-radius: 6px;
            font-size: 0.875rem;
            font-weight: 500;
            cursor: pointer;
            transition: all var(--transition);
            background: transparent;
            color: var(--text-secondary);
        }

        .btn:hover {
            background: rgba(255, 255, 255, 0.06);
            border-color: var(--border-medium);
        }

        .btn-small {
            padding: 6px 12px;
            font-size: 0.8125rem;
        }

        /* Footer */
        .footer {
            background: var(--bg-secondary);
            padding: 32px;
            border-top: 1px solid var(--border-subtle);
            margin-top: 48px;
        }

        .footer-content {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 24px;
        }

        .footer-left {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .footer-logo {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 0.875rem;
            color: var(--text-muted);
        }

        .footer-logo strong {
            color: var(--text-secondary);
            font-weight: 600;
        }

        .footer-tagline {
            font-size: 0.75rem;
            color: var(--text-muted);
        }

        .footer-right {
            display: flex;
            gap: 16px;
        }

        .footer-link {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 0.875rem;
            color: var(--accent-purple);
            text-decoration: none;
            transition: color var(--transition);
        }

        .footer-link:hover {
            color: var(--accent-purple-hover);
        }

        /* Keyboard Hints */
        .keyboard-hints {
            position: fixed;
            bottom: 24px;
            right: 24px;
            background: var(--bg-elevated);
            border: 1px solid var(--border-medium);
            border-radius: 8px;
            padding: 16px;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
            opacity: 0;
            pointer-events: none;
            transition: opacity var(--transition);
            z-index: 1000;
        }

        .keyboard-hints.visible {
            opacity: 1;
            pointer-events: auto;
        }

        .hint-title {
            font-size: 0.875rem;
            font-weight: 600;
            color: var(--text-primary);
            margin-bottom: 12px;
        }

        .hint-item {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
            font-size: 0.8125rem;
            color: var(--text-secondary);
        }

        .hint-footer {
            margin-top: 12px;
            padding-top: 12px;
            border-top: 1px solid var(--border-subtle);
            font-size: 0.75rem;
            color: var(--text-muted);
        }

        kbd {
            padding: 2px 6px;
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid var(--border-medium);
            border-radius: 4px;
            font-family: inherit;
            font-size: 0.75rem;
            font-weight: 600;
            color: var(--text-primary);
        }

        /* Responsive */
        @media (max-width: 768px) {
            .header {
                padding: 16px 20px;
            }

            .hero-card {
                margin: 16px 20px;
                padding: 24px;
            }

            .hero-content {
                flex-direction: column;
            }

            .hero-metrics {
                grid-template-columns: repeat(2, 1fr);
            }

            .timeline-section,
            .collapsible-section {
                margin: 0 20px 20px;
            }

            .section-controls {
                flex-direction: column;
                align-items: stretch;
            }

            .search-input {
                width: 100%;
            }

            .metrics-grid {
                grid-template-columns: 1fr;
            }

            .footer-content {
                flex-direction: column;
                text-align: center;
            }
        }
        """
    }

    // MARK: - JavaScript

    private var javascript: String {
        return """
        // Initialize timestamp
        function updateTimestamp() {
            const timestampEl = document.getElementById('timestamp');
            if (timestampEl && EXPLORATION_DATA && EXPLORATION_DATA.result && EXPLORATION_DATA.result.startTime) {
                const scanTime = new Date(EXPLORATION_DATA.result.startTime);
                timestampEl.textContent = scanTime.toLocaleString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric',
                    hour: 'numeric',
                    minute: '2-digit'
                });
            }
        }

        // Toggle step expansion
        function toggleStep(index) {
            const card = document.querySelector(`[data-step="${index}"] .timeline-card`);
            if (card) {
                card.classList.toggle('expanded');
            }
        }

        // Toggle AI interaction section
        function toggleAISection(stepIndex) {
            const aiSection = document.getElementById(`ai-section-${stepIndex}`);
            if (aiSection) {
                aiSection.classList.toggle('visible');
            }
        }

        // Toggle section expansion
        function toggleSection(sectionId) {
            const section = document.getElementById(`section-${sectionId}`);
            if (section) {
                section.classList.toggle('expanded');
                // Save state
                const isExpanded = section.classList.contains('expanded');
                localStorage.setItem(`section-${sectionId}-expanded`, isExpanded);
            }
        }

        // Copy code to clipboard
        function copyCode(elementId) {
            const element = document.getElementById(elementId);
            if (!element) return;

            const text = element.textContent;
            navigator.clipboard.writeText(text).then(() => {
                showToast('✅ Copied to clipboard!');
            }).catch(err => {
                console.error('Failed to copy:', err);
                showToast('❌ Failed to copy');
            });
        }

        // Show toast notification
        function showToast(message) {
            const toast = document.createElement('div');
            toast.textContent = message;
            toast.style.cssText = `
                position: fixed;
                bottom: 24px;
                left: 50%;
                transform: translateX(-50%);
                background: var(--bg-elevated);
                color: var(--text-primary);
                padding: 12px 24px;
                border-radius: 8px;
                border: 1px solid var(--border-medium);
                box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
                font-weight: 500;
                font-size: 0.875rem;
                z-index: 2000;
                animation: slideUp 0.3s ease-out;
            `;

            document.body.appendChild(toast);

            setTimeout(() => {
                toast.style.animation = 'slideDown 0.3s ease-in';
                setTimeout(() => toast.remove(), 300);
            }, 2000);
        }

        // Add toast animations
        const toastStyles = document.createElement('style');
        toastStyles.textContent = `
            @keyframes slideUp {
                from {
                    transform: translate(-50%, 100px);
                    opacity: 0;
                }
                to {
                    transform: translate(-50%, 0);
                    opacity: 1;
                }
            }
            @keyframes slideDown {
                from {
                    transform: translate(-50%, 0);
                    opacity: 1;
                }
                to {
                    transform: translate(-50%, 100px);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(toastStyles);

        // Toggle keyboard hints
        function toggleKeyboardHints() {
            const hints = document.getElementById('keyboard-hints');
            if (hints) {
                hints.classList.toggle('visible');
            }
        }

        // Screenshot modal functions
        function openScreenshot(path, stepNumber) {
            const modal = document.getElementById('screenshot-modal');
            const img = document.getElementById('screenshot-modal-img');
            const caption = document.getElementById('screenshot-modal-caption');

            if (modal && img && caption) {
                img.src = path;
                caption.textContent = `Step ${stepNumber} Screenshot`;
                modal.classList.add('visible');
                document.body.style.overflow = 'hidden'; // Prevent background scroll
            }
        }

        function closeScreenshot(event) {
            // Only close if clicking the modal backdrop or close button
            if (event.target.id === 'screenshot-modal' || event.target.classList.contains('screenshot-modal-close')) {
                const modal = document.getElementById('screenshot-modal');
                if (modal) {
                    modal.classList.remove('visible');
                    document.body.style.overflow = ''; // Restore scroll
                }
            }
        }

        // Timeline filtering
        function setupFiltering() {
            const searchInput = document.getElementById('timeline-search');
            const filterSelect = document.getElementById('timeline-filter');
            const timelineItems = document.querySelectorAll('.timeline-item');

            function filterTimeline() {
                const searchTerm = searchInput ? searchInput.value.toLowerCase() : '';
                const filterValue = filterSelect ? filterSelect.value : 'all';

                timelineItems.forEach(item => {
                    const stepNumber = item.dataset.step;
                    const action = item.dataset.action.toLowerCase();
                    const isSuccess = item.dataset.success === 'true';
                    const isRetry = item.dataset.retry === 'true';
                    const isCrash = item.dataset.crash === 'true';
                    const card = item.querySelector('.timeline-card');
                    const text = card ? card.textContent.toLowerCase() : '';

                    // Search filter
                    const matchesSearch = !searchTerm || text.includes(searchTerm);

                    // Category filter
                    let matchesFilter = true;
                    if (filterValue === 'success') {
                        matchesFilter = isSuccess;
                    } else if (filterValue === 'failed') {
                        matchesFilter = !isSuccess;
                    } else if (filterValue === 'crash') {
                        matchesFilter = isCrash;
                    } else if (filterValue === 'retry') {
                        matchesFilter = isRetry;
                    }

                    // Show/hide based on filters
                    if (matchesSearch && matchesFilter) {
                        item.classList.remove('hidden');
                    } else {
                        item.classList.add('hidden');
                    }
                });
            }

            if (searchInput) {
                searchInput.addEventListener('input', filterTimeline);
            }

            if (filterSelect) {
                filterSelect.addEventListener('change', filterTimeline);
            }
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            // Ignore if user is typing in an input
            if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
                if (e.key === 'Escape') {
                    e.target.blur();
                }
                return;
            }

            switch(e.key.toLowerCase()) {
                case 'c':
                    // Copy all tests
                    copyCode('generated-tests');
                    break;

                case 'e':
                    // Expand all sections
                    document.querySelectorAll('.collapsible-section').forEach(section => {
                        section.classList.add('expanded');
                    });
                    showToast('📂 All sections expanded');
                    break;

                case 'f':
                    // Filter to failures
                    const filterSelect = document.getElementById('timeline-filter');
                    if (filterSelect) {
                        filterSelect.value = 'failed';
                        filterSelect.dispatchEvent(new Event('change'));
                        showToast('❌ Showing only failures');
                    }
                    break;

                case '/':
                    // Focus search
                    e.preventDefault();
                    const searchInput = document.getElementById('timeline-search');
                    if (searchInput) {
                        searchInput.focus();
                    }
                    break;

                case 'escape':
                    // Close screenshot modal first if open
                    const modal = document.getElementById('screenshot-modal');
                    if (modal && modal.classList.contains('visible')) {
                        closeScreenshot({ target: modal });
                        break;
                    }
                    // Collapse all
                    document.querySelectorAll('.collapsible-section').forEach(section => {
                        section.classList.remove('expanded');
                    });
                    document.querySelectorAll('.timeline-card.expanded').forEach(card => {
                        card.classList.remove('expanded');
                    });
                    toggleKeyboardHints(); // Also hide hints if visible
                    break;

                case '?':
                    // Toggle keyboard hints
                    toggleKeyboardHints();
                    break;
            }
        });

        // Restore section states from localStorage
        function restoreSectionStates() {
            ['tests', 'coverage', 'metrics'].forEach(sectionId => {
                const isExpanded = localStorage.getItem(`section-${sectionId}-expanded`) === 'true';
                const section = document.getElementById(`section-${sectionId}`);
                if (section && isExpanded) {
                    section.classList.add('expanded');
                }
            });
        }

        // Auto-expand failed steps
        function autoExpandFailedSteps() {
            const failedSteps = document.querySelectorAll('.step-failure .timeline-card');
            failedSteps.forEach(card => {
                card.classList.add('expanded');
            });
        }


        // Initialize on DOM load
        document.addEventListener('DOMContentLoaded', () => {
            updateTimestamp();
            setupFiltering();
            restoreSectionStates();
            autoExpandFailedSteps();
        });
        """
    }
}

