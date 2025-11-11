import Foundation
import XCTest

/// CGRect extension for validation
private extension CGRect {
    var isFinite: Bool {
        return origin.x.isFinite && origin.y.isFinite &&
               size.width.isFinite && size.height.isFinite
    }
}

/// Element priority levels for intelligent element selection
private enum ElementPriority: Int, Comparable {
    case critical = 100  // Interactive + ID + Label
    case high = 75       // Interactive + (ID or Label)
    case medium = 50     // Interactive only, or Non-interactive + ID
    case low = 25        // Non-interactive + Label only

    static func < (lhs: ElementPriority, rhs: ElementPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Container for elements with priority for sorting
private struct PrioritizedElement: Comparable {
    let element: MinimalElement
    let priority: ElementPriority
    let semanticPriority: Int  // Semantic priority from SemanticAnalyzer (0-200+)

    static func < (lhs: PrioritizedElement, rhs: PrioritizedElement) -> Bool {
        // First compare by semantic priority (if available)
        if lhs.semanticPriority != rhs.semanticPriority {
            return lhs.semanticPriority < rhs.semanticPriority
        }
        // Fall back to structural priority
        return lhs.priority < rhs.priority
    }
}

/// Snapshot-based element wrapper for zero-query property access
/// XCUIElementSnapshot captures ALL element state in a single query,
/// then all property accesses are free (no additional XCTest queries)
private struct SnapshotElement {
    let snapshot: XCUIElementSnapshot
    let identifier: String
    let label: String
    let elementType: XCUIElement.ElementType
    let value: Any?
    let isEnabled: Bool
    let frame: CGRect
    let children: [XCUIElementSnapshot]

    @MainActor
    init?(from snapshot: XCUIElementSnapshot) {
        self.snapshot = snapshot

        // All property accesses from snapshot are FREE - no XCTest queries!
        self.identifier = snapshot.identifier
        self.label = snapshot.label
        self.elementType = snapshot.elementType
        self.value = snapshot.value
        self.isEnabled = snapshot.isEnabled
        self.frame = snapshot.frame
        self.children = snapshot.children

        // Validate frame is finite (sometimes XCTest returns NaN/Inf values)
        guard self.frame.isFinite else { return nil }
    }
}


/// Analyzes XCUITest element hierarchies and produces compressed, AI-friendly output
@MainActor
public class HierarchyAnalyzer {

    /// Maximum depth to traverse in the element hierarchy (prevents infinite recursion)
    private let maxDepth: Int

    /// Maximum number of children to process per element (prevents excessive processing)
    private let maxChildrenPerElement: Int

    /// Whether to exclude keyboard elements from the hierarchy (recommended for AI crawlers)
    private let excludeKeyboard: Bool

    /// Semantic analyzer for understanding element intent and priority
    private let semanticAnalyzer: SemanticAnalyzerProtocol?

    /// Whether to enrich elements with semantic metadata (intent, priority)
    private let useSemanticAnalysis: Bool

    /// Element categorizer for mapping XCUIElement types to simplified categories
    private let categorizer: ElementCategorizerProtocol

    /// Optional delegate for customizing hierarchy capture behavior
    nonisolated(unsafe) private weak var delegate: HierarchyAnalyzerDelegate?

    /// Whether to capture detailed element context (queries, frame, state)
    private let captureElementContext: Bool

    /// Element contexts captured during hierarchy analysis (for LLM export)
    /// Keyed by element identifier: "type|id|label"
    nonisolated(unsafe) private var elementContextMap: [String: ElementContext] = [:]

    /// Snapshot cache for context capture (avoids re-querying elements)
    /// Maps element key to its snapshot for efficient context capture
    nonisolated(unsafe) private var snapshotCache: [String: XCUIElementSnapshot] = [:]

    /// Public accessor for captured element contexts
    public var capturedElementContexts: [String: ElementContext] {
        return elementContextMap
    }

    /// Initialize with configuration object (recommended)
    /// - Parameter configuration: Configuration options for the analyzer
    nonisolated public init(configuration: HierarchyAnalyzerConfiguration) {
        self.maxDepth = configuration.maxDepth
        self.maxChildrenPerElement = configuration.maxChildrenPerElement
        self.excludeKeyboard = configuration.excludeKeyboard
        self.useSemanticAnalysis = configuration.useSemanticAnalysis
        self.categorizer = configuration.categorizer
        self.semanticAnalyzer = configuration.semanticAnalyzer
        self.delegate = configuration.delegate
        self.captureElementContext = configuration.captureElementContext
    }

    /// Initialize with individual parameters (backward compatibility)
    /// - Parameters:
    ///   - maxDepth: Maximum hierarchy depth (default: 10)
    ///   - maxChildrenPerElement: Max children to process (default: 50)
    ///   - excludeKeyboard: Whether to exclude keyboard elements (default: true)
    ///   - useSemanticAnalysis: Whether to add semantic metadata (default: true)
    nonisolated public convenience init(
        maxDepth: Int = 10,
        maxChildrenPerElement: Int = 50,
        excludeKeyboard: Bool = true,
        useSemanticAnalysis: Bool = true
    ) {
        var config = HierarchyAnalyzerConfiguration()
        config.maxDepth = maxDepth
        config.maxChildrenPerElement = maxChildrenPerElement
        config.excludeKeyboard = excludeKeyboard
        config.useSemanticAnalysis = useSemanticAnalysis
        self.init(configuration: config)
    }

    /// Captures the view hierarchy from an XCUIApplication
    /// - Parameter app: The XCUIApplication to analyze
    /// - Returns: A CompressedHierarchy ready for AI consumption
    @MainActor
    public func capture(from app: XCUIApplication) -> CompressedHierarchy {
        // Notify delegate that capture is beginning
        delegate?.willBeginCapture()

        // CRASH SAFETY: Check if app is running before accessing any properties
        // Accessing app.frame or other properties when app is not running causes timeout
        guard app.state != .notRunning && app.state != .unknown else {
            // App is not running - return empty hierarchy
            return CompressedHierarchy(elements: [], screenshot: Data(), screenType: nil)
        }

        // Capture ALL elements FIRST (uses try? app.snapshot() which fails gracefully)
        let allElements = captureAllElementsFromApp(app)

        // If snapshot failed (crash during capture), return empty hierarchy
        if allElements.isEmpty {
            // Check if app crashed during snapshot
            if app.state == .notRunning {
                return CompressedHierarchy(elements: [], screenshot: Data(), screenType: nil)
            }
        }

        // Capture screenshot AFTER successful snapshot (more stable)
        let screenshotData: Data
        do {
            let screenshot = app.screenshot()
            screenshotData = screenshot.pngRepresentation
        } catch {
            // Screenshot failed - use empty data
            screenshotData = Data()
        }

        // Notify delegate with full data BEFORE compression
        // This allows comprehensive tools to access ALL elements without affecting AI token usage
        delegate?.willCompressHierarchy(app: app, allElements: allElements)

        // Apply compression/prioritization (reduce to top 50 for AI)
        // Also captures detailed context for top 50 elements only (optimization)
        let compressedElements = compressElements(allElements)

        // Detect screen type using semantic analysis
        let screenType = useSemanticAnalysis ? detectScreenType(from: compressedElements) : nil

        let hierarchy = CompressedHierarchy(
            elements: compressedElements,
            screenshot: screenshotData,
            screenType: screenType
        )

        // Notify delegate that capture completed successfully (with compressed data)
        delegate?.didCompleteCapture(hierarchy)

        return hierarchy
    }

    /// Detects the type of screen from captured elements
    private func detectScreenType(from elements: [MinimalElement]) -> ScreenType? {
        guard let analyzer = semanticAnalyzer else { return nil }

        let detectedType = analyzer.detectScreenType(from: elements)

        // Don't return generic "content" type as it's not informative
        return detectedType == .content ? nil : detectedType
    }

    /// Generates a unique key for an element to track duplicates
    /// - Parameter element: The MinimalElement to generate a key for
    /// - Returns: A unique string key combining type, id, and label
    private func elementKey(for element: MinimalElement) -> String {
        return "\(element.type.rawValue)|\(element.id ?? "")|\(element.label ?? "")"
    }

    /// Gets the semantic priority for an element (delegate takes precedence)
    /// - Parameter element: The MinimalElement to get priority for
    /// - Returns: The semantic priority value (from delegate or element's own priority)
    private func getSemanticPriority(for element: MinimalElement) -> Int {
        if let delegatePriority = delegate?.priorityForElement(element) {
            return delegatePriority
        }
        return element.priority ?? 0
    }

    /// Captures ALL elements from the XCUIApplication using snapshot (no compression)
    /// OPTIMIZED: Uses XCUIElementSnapshot for 1 query instead of ~2,700 queries
    /// - Parameter app: The XCUIApplication to analyze
    /// - Returns: Array of ALL captured MinimalElement representations
    @MainActor
    private func captureAllElementsFromApp(_ app: XCUIApplication) -> [MinimalElement] {
        var prioritizedElements: [PrioritizedElement] = []
        var seenElements = Set<String>()  // O(1) duplicate tracking

        // PERFORMANCE OPTIMIZATION: Capture entire hierarchy in ONE query
        // Previously: ~2,700 XCTest queries (300 elements × 9 properties)
        // Now: 1 XCTest query for ENTIRE hierarchy
        guard let rootSnapshot = try? app.snapshot() else {
            // Snapshot failed - return empty array
            return []
        }
        
        print(rootSnapshot)

        // Detect if keyboard is present (still need this check before snapshot)
        let keyboardPresent = excludeKeyboard && app.keyboards.firstMatch.exists

        // Recursively traverse snapshot hierarchy (all property accesses are FREE!)
        func traverse(_ snapshot: XCUIElementSnapshot, depth: Int = 0) {
            // Create SnapshotElement wrapper for property access
            guard let snapshotElement = SnapshotElement(from: snapshot) else { return }

            // Skip system UI elements
            guard !categorizer.shouldSkip(snapshotElement.elementType) else { return }

            // Skip keyboard elements
            if excludeKeyboard && keyboardPresent && isKeyboardElement(snapshotElement) {
                return
            }

            // Create minimal element
            let minimalElement = createMinimalElement(from: snapshotElement)

            // Check if element should be included in results
            // IMPORTANT: We check inclusion but DON'T return early!
            // Container elements like .application and .window won't be included,
            // but we still need to traverse their children to find actual UI elements
            let includeThisElement = shouldInclude(minimalElement)

            if includeThisElement {
                // Check if element already exists (O(1) lookup)
                let key = elementKey(for: minimalElement)

                if !seenElements.contains(key) {
                    seenElements.insert(key)

                    // Cache snapshot for later context capture (if enabled)
                    if captureElementContext {
                        snapshotCache[key] = snapshot
                    }

                    // Calculate priority for sorting
                    // NO LIMITS during traversal - we collect all elements and let
                    // downstream prioritization/compression handle selection
                    let priority = calculatePriority(for: minimalElement)
                    let semanticPriority = getSemanticPriority(for: minimalElement)

                    prioritizedElements.append(PrioritizedElement(
                        element: minimalElement,
                        priority: priority,
                        semanticPriority: semanticPriority
                    ))
                }
            }

            // Recursively traverse children (still FREE - no additional queries!)
            for child in snapshotElement.children {
                traverse(child, depth: depth + 1)
            }
        }

        traverse(rootSnapshot)

        // Return all elements sorted by priority (highest first)
        let allElements = prioritizedElements
            .sorted(by: >) // Highest priority first
            .map { $0.element }

        return allElements
    }

    /// Compresses elements to top 50 for AI consumption and captures detailed context
    /// - Parameter allElements: All captured elements
    /// - Returns: Top 50 elements by priority
    private func compressElements(_ allElements: [MinimalElement]) -> [MinimalElement] {
        let targetCount = 50  // Optimized for AI token efficiency
        let topElements = Array(allElements.prefix(targetCount))

        // Capture detailed context for top 50 elements only using cached snapshots
        // OPTIMIZED: Uses snapshotCache instead of re-querying (0 additional queries!)
        // Previously: ~400-500 XCTest queries for context capture
        // Now: 0 queries - all data already in snapshot cache
        if captureElementContext {
            for (index, element) in topElements.enumerated() {
                let key = elementKey(for: element)
                // Use cached snapshot instead of re-querying
                if let snapshot = snapshotCache[key] {
                    _ = captureElementContext(from: snapshot, minimalElement: element, index: index)
                }
            }
        }

        return topElements
    }


    /// Checks if an element is part of the keyboard hierarchy (SnapshotElement version)
    /// - Parameter snapshot: The snapshot element to check
    /// - Returns: True if the element is part of the keyboard
    @MainActor
    private func isKeyboardElement(_ snapshot: SnapshotElement) -> Bool {
        // Check if element identifier contains keyboard-related strings
        let identifier = snapshot.identifier.lowercased()
        let keyboardIdentifiers = ["keyboard", "autocorrection", "prediction", "emoji"]

        for keyboardId in keyboardIdentifiers {
            if identifier.contains(keyboardId) {
                return true
            }
        }

        // Check if element label suggests it's a keyboard key
        let label = snapshot.label.lowercased()
        if label.count == 1 {
            // Single character labels are likely keyboard keys
            return true
        }

        // Check for common keyboard button labels
        let keyboardLabels = ["return", "space", "shift", "delete", "next keyboard",
                             "dictation", "emoji", "done", "go", "search", "send"]
        for keyboardLabel in keyboardLabels {
            if label.contains(keyboardLabel) || label == keyboardLabel {
                return true
            }
        }

        return false
    }


    /// Creates a MinimalElement from snapshot element properties (OPTIMIZED)
    /// - Parameter snapshot: The snapshot element properties
    /// - Returns: A MinimalElement representation
    @MainActor
    private func createMinimalElement(from snapshot: SnapshotElement) -> MinimalElement {
        let category = categorizer.categorize(snapshot.elementType)

        // Capture current value for interactive elements (helps AI understand state)
        var value: String? = nil
        if category.interactive {
            // Get value from snapshot.value (for inputs, toggles, sliders, etc.)
            if let elementValue = snapshot.value as? String, !elementValue.isEmpty {
                value = elementValue
            } else if let elementValue = snapshot.value as? NSNumber {
                // For toggles (0/1) and sliders (numeric values)
                value = elementValue.stringValue
            }
        }

        // Convert string type to ElementType enum
        let elementType = ElementType(rawValue: category.type) ?? .container

        // Add semantic metadata if enabled
        var intent: SemanticIntent? = nil
        var priority: Int? = nil

        if useSemanticAnalysis, let analyzer = semanticAnalyzer {
            let id = snapshot.identifier.isEmpty ? nil : snapshot.identifier
            let label = snapshot.label.isEmpty ? nil : snapshot.label

            let detectedIntent = analyzer.detectIntent(label: label, identifier: id)
            intent = detectedIntent == .neutral ? nil : detectedIntent

            // Create temporary minimal element for priority calculation
            let tempElement = MinimalElement(
                type: elementType,
                id: id,
                label: label,
                interactive: category.interactive,
                value: value,
                children: []
            )
            priority = analyzer.calculateSemanticPriority(tempElement)
        }

        return MinimalElement(
            type: elementType,
            id: snapshot.identifier.isEmpty ? nil : snapshot.identifier,
            label: snapshot.label.isEmpty ? nil : snapshot.label,
            interactive: category.interactive,
            value: value,
            intent: intent,
            priority: priority,
            children: []
        )
    }


    /// Calculates priority for an element based on its properties
    /// - Parameter element: The MinimalElement to evaluate
    /// - Returns: The calculated ElementPriority
    private func calculatePriority(for element: MinimalElement) -> ElementPriority {
        let hasId = element.id != nil && !element.id!.isEmpty
        let hasLabel = element.label != nil && !element.label!.isEmpty
        let isInteractive = element.interactive

        // Critical: Interactive elements with both ID and label (e.g., loginButton with "Sign In")
        if isInteractive && hasId && hasLabel {
            return .critical
        }

        // High: Interactive elements with either ID or label
        if isInteractive && (hasId || hasLabel) {
            return .high
        }

        // Medium: Interactive without identification, or important non-interactive (has ID)
        if isInteractive || hasId {
            return .medium
        }

        // Low: Non-interactive with only label
        if hasLabel {
            return .low
        }

        return .low
    }

    /// Determines if an element should be included in the final output
    /// - Parameter element: The MinimalElement to evaluate
    /// - Returns: True if the element should be included
    private func shouldInclude(_ element: MinimalElement) -> Bool {
        // Check default inclusion logic first
        var shouldIncludeByDefault = false

        // Always include interactive elements
        if element.interactive { shouldIncludeByDefault = true }

        // Include text elements with actual content
        else if element.type == .text && element.label != nil { shouldIncludeByDefault = true }

        // Include images (they provide visual context)
        else if element.type == .image { shouldIncludeByDefault = true }

        // Include any element with an identifier (developer marked as important)
        else if element.id != nil { shouldIncludeByDefault = true }

        // Include any element with a label (has user-facing content)
        else if element.label != nil { shouldIncludeByDefault = true }

        // If default logic says to skip, don't include
        if !shouldIncludeByDefault {
            return false
        }

        // Consult delegate for final decision (delegate can veto inclusion)
        if let delegate = delegate {
            return delegate.shouldInclude(element)
        }

        return true
    }

    /// Captures detailed element context from snapshot (OPTIMIZED - zero queries)
    /// - Parameters:
    ///   - snapshot: The XCUIElementSnapshot to capture context from
    ///   - minimalElement: The corresponding MinimalElement
    ///   - index: Element index among siblings of same type
    /// - Returns: ElementContext with queries, frame, state, etc.
    @MainActor
    private func captureElementContext(
        from snapshot: XCUIElementSnapshot,
        minimalElement: MinimalElement,
        index: Int
    ) -> ElementContext {
        // Build query strategies (all data from snapshot - no queries!)
        let queries = QueryBuilder.buildQueries(
            elementType: snapshot.elementType,
            id: minimalElement.id,
            label: minimalElement.label,
            index: index
        )

        // Capture accessibility traits from snapshot
        let traits = captureAccessibilityTraits(from: snapshot)

        // Create context using snapshot properties (all FREE!)
        let context = ElementContext(
            xcuiElementType: String(describing: snapshot.elementType),
            frame: snapshot.frame,
            isEnabled: snapshot.isEnabled,
            isVisible: true,  // Snapshot only exists if element was visible
            isHittable: false,  // Conservative default - verified during action execution
            hasFocus: false,  // XCUIElementSnapshot doesn't expose hasFocus in public API
            queries: queries,
            accessibilityTraits: traits,
            accessibilityHint: nil  // XCUIElementSnapshot doesn't expose hint
        )

        // Store in map
        let key = elementKey(for: minimalElement)
        elementContextMap[key] = context

        // Notify delegate
        delegate?.didCaptureElementContext(minimalElement, context: context)

        return context
    }


    /// Captures accessibility traits from snapshot (OPTIMIZED)
    /// - Parameter snapshot: The XCUIElementSnapshot
    /// - Returns: Array of trait strings
    @MainActor
    private func captureAccessibilityTraits(from snapshot: XCUIElementSnapshot) -> [String]? {
        // Infer traits from element type (snapshot provides elementType for free)
        var traits: [String] = []

        switch snapshot.elementType {
        case .button:
            traits.append("button")
        case .textField, .secureTextField, .searchField:
            traits.append("textField")
        case .staticText:
            traits.append("staticText")
        case .image:
            traits.append("image")
        case .link:
            traits.append("link")
        default:
            break
        }

        return traits.isEmpty ? nil : traits
    }


    /// Method to clear captured contexts (useful for memory management in long sessions)
    public func clearCapturedContexts() {
        elementContextMap.removeAll()
        snapshotCache.removeAll()
    }
}
