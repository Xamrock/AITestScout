import Foundation

/// Tracks where a typed value originated from during exploration
///
/// Used for logging, debugging, and dashboard visualization to show
/// which values came from fixtures vs AI generation vs fallbacks.
///
/// **Usage:**
/// ```swift
/// let (value, source) = resolver.resolve(element: emailField)
/// print("[AITestScout] Typing '\(value)' (source: \(source.description))")
/// ```
public enum ValueSource: Equatable, Codable {
    /// Exact identifier match from fixture
    case fixtureExact(pattern: String)

    /// Pattern match from fixture (regex, contains, etc.)
    case fixturePattern(patternType: String, pattern: String)

    /// Screen context match from fixture
    case fixtureContext(screen: String, field: String)

    /// Semantic match from fixture
    case fixtureSemantic(fieldType: String)

    /// Type-based default from fixture
    case fixtureDefault(fieldType: String)

    /// Environment variable substitution
    case environmentVariable(key: String)

    /// AI-generated context-aware value
    case aiGenerated(context: String)

    /// Generic fallback value
    case fallback

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case pattern
        case patternType
        case screen
        case field
        case fieldType
        case key
        case context
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "fixtureExact":
            let pattern = try container.decode(String.self, forKey: .pattern)
            self = .fixtureExact(pattern: pattern)
        case "fixturePattern":
            let patternType = try container.decode(String.self, forKey: .patternType)
            let pattern = try container.decode(String.self, forKey: .pattern)
            self = .fixturePattern(patternType: patternType, pattern: pattern)
        case "fixtureContext":
            let screen = try container.decode(String.self, forKey: .screen)
            let field = try container.decode(String.self, forKey: .field)
            self = .fixtureContext(screen: screen, field: field)
        case "fixtureSemantic":
            let fieldType = try container.decode(String.self, forKey: .fieldType)
            self = .fixtureSemantic(fieldType: fieldType)
        case "fixtureDefault":
            let fieldType = try container.decode(String.self, forKey: .fieldType)
            self = .fixtureDefault(fieldType: fieldType)
        case "environmentVariable":
            let key = try container.decode(String.self, forKey: .key)
            self = .environmentVariable(key: key)
        case "aiGenerated":
            let context = try container.decode(String.self, forKey: .context)
            self = .aiGenerated(context: context)
        case "fallback":
            self = .fallback
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid source type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .fixtureExact(let pattern):
            try container.encode("fixtureExact", forKey: .type)
            try container.encode(pattern, forKey: .pattern)
        case .fixturePattern(let patternType, let pattern):
            try container.encode("fixturePattern", forKey: .type)
            try container.encode(patternType, forKey: .patternType)
            try container.encode(pattern, forKey: .pattern)
        case .fixtureContext(let screen, let field):
            try container.encode("fixtureContext", forKey: .type)
            try container.encode(screen, forKey: .screen)
            try container.encode(field, forKey: .field)
        case .fixtureSemantic(let fieldType):
            try container.encode("fixtureSemantic", forKey: .type)
            try container.encode(fieldType, forKey: .fieldType)
        case .fixtureDefault(let fieldType):
            try container.encode("fixtureDefault", forKey: .type)
            try container.encode(fieldType, forKey: .fieldType)
        case .environmentVariable(let key):
            try container.encode("environmentVariable", forKey: .type)
            try container.encode(key, forKey: .key)
        case .aiGenerated(let context):
            try container.encode("aiGenerated", forKey: .type)
            try container.encode(context, forKey: .context)
        case .fallback:
            try container.encode("fallback", forKey: .type)
        }
    }

    // MARK: - Display

    /// Human-readable description for logging
    public var description: String {
        switch self {
        case .fixtureExact(let pattern):
            return "fixture (exact: \(pattern))"
        case .fixturePattern(let patternType, let pattern):
            return "fixture (\(patternType): \(pattern))"
        case .fixtureContext(let screen, let field):
            return "fixture (context: \(screen)/\(field))"
        case .fixtureSemantic(let fieldType):
            return "fixture (semantic: \(fieldType))"
        case .fixtureDefault(let fieldType):
            return "fixture (default: \(fieldType))"
        case .environmentVariable(let key):
            return "environment ($\(key))"
        case .aiGenerated(let context):
            return "AI generated (\(context))"
        case .fallback:
            return "fallback"
        }
    }

    /// Short label for dashboard display
    public var label: String {
        switch self {
        case .fixtureExact:
            return "Fixture (exact)"
        case .fixturePattern:
            return "Fixture (pattern)"
        case .fixtureContext:
            return "Fixture (context)"
        case .fixtureSemantic:
            return "Fixture (semantic)"
        case .fixtureDefault:
            return "Fixture (default)"
        case .environmentVariable:
            return "Environment"
        case .aiGenerated:
            return "AI"
        case .fallback:
            return "Fallback"
        }
    }

    /// Color code for dashboard visualization
    /// Returns CSS color class name
    public var colorClass: String {
        switch self {
        case .fixtureExact, .environmentVariable:
            return "source-exact" // Green - highest confidence
        case .fixturePattern, .fixtureContext, .fixtureSemantic:
            return "source-pattern" // Blue - good confidence
        case .fixtureDefault:
            return "source-default" // Yellow - moderate confidence
        case .aiGenerated:
            return "source-ai" // Orange - AI inferred
        case .fallback:
            return "source-fallback" // Red - needs attention
        }
    }

    /// Confidence level (0.0 - 1.0) for this value source
    public var confidence: Double {
        switch self {
        case .fixtureExact, .environmentVariable:
            return 1.0
        case .fixturePattern, .fixtureContext:
            return 0.9
        case .fixtureSemantic:
            return 0.8
        case .fixtureDefault:
            return 0.7
        case .aiGenerated:
            return 0.6
        case .fallback:
            return 0.4
        }
    }
}
