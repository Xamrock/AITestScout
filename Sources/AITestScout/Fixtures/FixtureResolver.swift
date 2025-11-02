import Foundation
import FoundationModels

/// Resolves values for UI elements using a multi-level strategy
///
/// The resolver implements a 7-level cascade for finding the best value:
/// 1. Screen context + field match (most specific)
/// 2. Exact identifier match
/// 3. Pattern match (regex, contains, etc.)
/// 4. Semantic match
/// 5. Type-based default
/// 6. AI-generated context-aware value
/// 7. Generic fallback
///
/// **Usage:**
/// ```swift
/// let resolver = FixtureResolver(fixture: myFixture)
/// let (value, source) = try await resolver.resolve(
///     element: emailField,
///     screenType: .login
/// )
/// print("Using value: \(value) from \(source.description)")
/// ```
@available(macOS 26.0, iOS 26.0, *)
@MainActor
public class FixtureResolver {
    /// The fixture to resolve values from
    private let fixture: ExplorationFixture?

    /// AI session for generating context-aware values (lazy loaded)
    private var aiSession: LanguageModelSession?

    /// Initialize resolver with optional fixture
    /// - Parameter fixture: Fixture to resolve from (nil = no fixture, use fallbacks)
    public init(fixture: ExplorationFixture? = nil) {
        self.fixture = fixture
    }

    // MARK: - Value Resolution

    /// Resolve a value for a given element
    /// - Parameters:
    ///   - element: The UI element to find a value for
    ///   - screenType: Optional screen type for context-aware matching
    /// - Returns: Tuple of (value, source) indicating the resolved value and where it came from
    public func resolve(
        element: MinimalElement,
        screenType: ScreenType? = nil
    ) async throws -> (value: String, source: ValueSource) {

        guard let fixture = fixture else {
            // No fixture - use fallback
            return try await resolveFallback(element: element, screenType: screenType)
        }

        // Level 1: Screen context + field match
        if let screenType = screenType {
            if let (value, pattern) = resolveScreenContext(element: element, screenType: screenType, fixture: fixture) {
                return (value, .fixtureContext(screen: screenType.rawValue, field: pattern))
            }
        }

        // Level 2: Exact identifier match
        if let (value, identifier) = resolveExactIdentifier(element: element, fixture: fixture) {
            return (value, .fixtureExact(pattern: identifier))
        }

        // Level 3: Pattern match
        if let (value, pattern) = resolvePattern(element: element, screenType: screenType, fixture: fixture) {
            return (value, .fixturePattern(patternType: patternTypeName(pattern), pattern: patternDescription(pattern)))
        }

        // Level 4: Semantic match
        if let (value, fieldType) = resolveSemantic(element: element, fixture: fixture) {
            return (value, .fixtureSemantic(fieldType: fieldType.rawValue))
        }

        // Level 5: Type-based default
        if let (value, fieldType) = resolveDefault(element: element, fixture: fixture) {
            return (value, .fixtureDefault(fieldType: fieldType.rawValue))
        }

        // Level 6 & 7: Fallback based on mode
        return try await resolveFallback(element: element, screenType: screenType)
    }

    // MARK: - Level 1: Screen Context

    private func resolveScreenContext(
        element: MinimalElement,
        screenType: ScreenType,
        fixture: ExplorationFixture
    ) -> (value: String, pattern: String)? {
        // Sort patterns by priority (highest first)
        let sorted = fixture.patterns.sorted { $0.key.priority > $1.key.priority }

        for (pattern, value) in sorted {
            if case .screenContext = pattern,
               pattern.matches(element, screenType: screenType) {
                if let field = element.id ?? element.label {
                    return (value, field)
                }
            }
        }
        return nil
    }

    // MARK: - Level 2: Exact Identifier

    private func resolveExactIdentifier(
        element: MinimalElement,
        fixture: ExplorationFixture
    ) -> (value: String, identifier: String)? {
        guard let identifier = element.id else {
            return nil
        }

        for (pattern, value) in fixture.patterns {
            if case .identifier(let target) = pattern, target == identifier {
                return (value, identifier)
            }
        }

        return nil
    }

    // MARK: - Level 3: Pattern Match

    private func resolvePattern(
        element: MinimalElement,
        screenType: ScreenType?,
        fixture: ExplorationFixture
    ) -> (value: String, pattern: FieldPattern)? {
        // Sort patterns by priority (highest first)
        let sorted = fixture.patterns.sorted { $0.key.priority > $1.key.priority }

        for (pattern, value) in sorted {
            // Skip screen context patterns (handled in level 1)
            if case .screenContext = pattern {
                continue
            }
            // Skip identifier patterns (handled in level 2)
            if case .identifier = pattern {
                continue
            }
            // Skip semantic patterns (handled in level 4)
            if case .semantic = pattern {
                continue
            }

            if pattern.matches(element, screenType: screenType) {
                return (value, pattern)
            }
        }

        return nil
    }

    // MARK: - Level 4: Semantic Match

    private func resolveSemantic(
        element: MinimalElement,
        fixture: ExplorationFixture
    ) -> (value: String, fieldType: SemanticFieldType)? {
        for (pattern, value) in fixture.patterns {
            if case .semantic(let fieldType) = pattern,
               fieldType.matches(element) {
                return (value, fieldType)
            }
        }
        return nil
    }

    // MARK: - Level 5: Type-based Default

    private func resolveDefault(
        element: MinimalElement,
        fixture: ExplorationFixture
    ) -> (value: String, fieldType: SemanticFieldType)? {
        // Try to infer semantic type from element
        for (fieldType, value) in fixture.defaults {
            if fieldType.matches(element) {
                return (value, fieldType)
            }
        }

        return nil
    }

    // MARK: - Level 6 & 7: Fallback

    private func resolveFallback(
        element: MinimalElement,
        screenType: ScreenType?
    ) async throws -> (value: String, source: ValueSource) {
        let fallbackMode = fixture?.fallbackMode ?? .aiGenerated

        switch fallbackMode {
        case .aiGenerated:
            // Use AI to generate context-aware value
            return try await resolveAIGenerated(element: element, screenType: screenType)

        case .semanticDefaults:
            // Use semantic defaults only
            return resolveSemanticDefault(element: element)

        case .generic:
            // Use generic fallback
            return (generateGenericFallback(element: element), .fallback)

        case .strict:
            // Fail in strict mode
            throw FixtureError.noMatchFound(element: element.id ?? element.label ?? "unknown")
        }
    }

    // MARK: - AI Generation

    private func resolveAIGenerated(
        element: MinimalElement,
        screenType: ScreenType?
    ) async throws -> (value: String, source: ValueSource) {
        // Lazy load AI session
        if aiSession == nil {
            aiSession = LanguageModelSession()
            aiSession?.prewarm()
        }

        guard let session = aiSession else {
            // Fallback if AI not available
            return resolveSemanticDefault(element: element)
        }

        let identifier = element.id ?? element.label ?? "field"
        let screenContext = screenType?.rawValue ?? "unknown screen"

        let prompt = """
        Generate a realistic test value for a form field.

        Field identifier: \(identifier)
        Screen type: \(screenContext)
        Field type: \(element.type.rawValue)

        Return ONLY the value, nothing else. The value should be:
        - Realistic and contextually appropriate
        - Valid for the field type
        - Concise (no explanations)

        Examples:
        - email field → user@example.com
        - password field → SecurePass123
        - apartment number → 12B
        - quantity → 2
        - birth date → 1990-05-15

        Value:
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: AIGeneratedValue.self
            )

            let value = response.content.value.trimmingCharacters(in: .whitespacesAndNewlines)
            return (value, .aiGenerated(context: screenContext))
        } catch {
            // Fallback to semantic if AI fails
            print("⚠️  AI generation failed: \(error), falling back to semantic default")
            return resolveSemanticDefault(element: element)
        }
    }

    // MARK: - Semantic Default

    private func resolveSemanticDefault(element: MinimalElement) -> (value: String, source: ValueSource) {
        // Try to infer semantic type and use its default
        for fieldType in SemanticFieldType.allCases {
            if fieldType.matches(element) {
                return (fieldType.defaultValue, .fixtureDefault(fieldType: fieldType.rawValue))
            }
        }

        // No semantic match - use generic fallback
        return (generateGenericFallback(element: element), .fallback)
    }

    // MARK: - Generic Fallback

    /// Generate a generic fallback value (mirrors current AICrawler behavior)
    private func generateGenericFallback(element: MinimalElement) -> String {
        let identifier = (element.id ?? element.label ?? "").lowercased()

        if identifier.contains("email") {
            return "test@example.com"
        } else if identifier.contains("password") {
            return "TestPassword123"
        } else if identifier.contains("phone") {
            return "555-0100"
        } else if identifier.contains("name") {
            return "Test User"
        } else if identifier.contains("search") {
            return "test query"
        } else {
            return "test input"
        }
    }

    // MARK: - Helpers

    private func patternTypeName(_ pattern: FieldPattern) -> String {
        switch pattern {
        case .identifier:
            return "identifier"
        case .contains:
            return "contains"
        case .regex:
            return "regex"
        case .placeholder:
            return "placeholder"
        case .label:
            return "label"
        case .semantic:
            return "semantic"
        case .screenContext:
            return "screenContext"
        }
    }

    private func patternDescription(_ pattern: FieldPattern) -> String {
        switch pattern {
        case .identifier(let value):
            return value
        case .contains(let value):
            return value
        case .regex(let value):
            return value
        case .placeholder(let value):
            return value
        case .label(let value):
            return value
        case .semantic(let fieldType):
            return fieldType.rawValue
        case .screenContext(let screen, let field):
            return "\(screen)/\(field)"
        }
    }
}

// MARK: - Supporting Types

/// AI-generated value response
@Generable
private struct AIGeneratedValue: Codable {
    let value: String
}

/// Errors that can occur during fixture resolution
public enum FixtureError: Error, LocalizedError {
    case noMatchFound(element: String)

    public var errorDescription: String? {
        switch self {
        case .noMatchFound(let element):
            return "No fixture match found for element '\(element)' and fallback mode is strict"
        }
    }
}

// MARK: - SemanticFieldType Extension

extension SemanticFieldType {
    static var allCases: [SemanticFieldType] {
        return [
            .email, .password, .phone, .url, .creditCard, .zipCode,
            .name, .address, .city, .state, .country, .username,
            .search, .date, .number
        ]
    }
}
