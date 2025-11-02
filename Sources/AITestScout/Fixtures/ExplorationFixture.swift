import Foundation

/// Test data fixture for exploration sessions
///
/// Provides values for form fields, inputs, and other interactive elements
/// during automated UI exploration. Supports multiple matching strategies,
/// environment variable substitution, and validation rules.
///
/// **Usage:**
/// ```swift
/// // Simple usage with file
/// let fixture = try ExplorationFixture.load(from: "fixtures/login-flow.json")
///
/// // Programmatic usage
/// let fixture = ExplorationFixture(
///     name: "Checkout Flow",
///     patterns: [
///         .identifier("emailField"): "customer@test.com",
///         .contains("password"): "SecurePass123",
///         .semantic(.creditCard): "4242424242424242"
///     ],
///     defaults: [
///         .email: "default@example.com",
///         .phone: "555-9999"
///     ]
/// )
///
/// // Use in exploration
/// var config = ExplorationConfig(steps: 20, goal: "Complete checkout")
/// config.fixture = fixture
/// try Scout.explore(app, config: config)
/// ```
public struct ExplorationFixture: Codable, Sendable {
    /// Human-readable name for this fixture
    public var name: String?

    /// Description of what this fixture is for
    public var description: String?

    /// Version of fixture format (for future compatibility)
    public var version: String

    /// Pattern-based value mappings
    public var patterns: [FieldPattern: String]

    /// Type-based default values
    public var defaults: [SemanticFieldType: String]

    /// Validation rules for values
    public var validation: [String: ValidationRule]?

    /// Fallback mode when no match found
    public var fallbackMode: FallbackMode

    // MARK: - Initialization

    public init(
        name: String? = nil,
        description: String? = nil,
        version: String = "1.0",
        patterns: [FieldPattern: String] = [:],
        defaults: [SemanticFieldType: String] = [:],
        validation: [String: ValidationRule]? = nil,
        fallbackMode: FallbackMode = .aiGenerated
    ) {
        self.name = name
        self.description = description
        self.version = version
        self.patterns = patterns
        self.defaults = defaults
        self.validation = validation
        self.fallbackMode = fallbackMode
    }

    // MARK: - File Loading

    /// Load fixture from JSON file
    /// - Parameter path: File path (relative to working directory or absolute)
    /// - Returns: Loaded fixture with environment variables substituted
    /// - Throws: Errors if file cannot be loaded or parsed
    public static func load(from path: String) throws -> ExplorationFixture {
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(path)
        }

        return try load(from: url)
    }

    /// Load fixture from URL
    /// - Parameter url: File URL
    /// - Returns: Loaded fixture with environment variables substituted
    /// - Throws: Errors if file cannot be loaded or parsed
    public static func load(from url: URL) throws -> ExplorationFixture {
        let data = try Data(contentsOf: url)
        var fixture = try JSONDecoder().decode(ExplorationFixture.self, from: data)

        // Substitute environment variables
        fixture.substituteEnvironmentVariables()

        return fixture
    }

    /// Save fixture to JSON file
    /// - Parameter path: File path to save to
    /// - Throws: Errors if file cannot be written
    public func save(to path: String) throws {
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(path)
        }

        try save(to: url)
    }

    /// Save fixture to URL
    /// - Parameter url: File URL to save to
    /// - Throws: Errors if file cannot be written
    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }

    // MARK: - Environment Variable Substitution

    /// Substitute environment variables in all values
    ///
    /// Replaces `${VAR_NAME}` patterns with actual environment variable values.
    /// If variable is not set, the pattern is left unchanged.
    mutating func substituteEnvironmentVariables() {
        // Substitute in patterns
        var substitutedPatterns: [FieldPattern: String] = [:]
        for (pattern, value) in patterns {
            substitutedPatterns[pattern] = substituteEnvironmentVariables(in: value)
        }
        patterns = substitutedPatterns

        // Substitute in defaults
        var substitutedDefaults: [SemanticFieldType: String] = [:]
        for (fieldType, value) in defaults {
            substitutedDefaults[fieldType] = substituteEnvironmentVariables(in: value)
        }
        defaults = substitutedDefaults
    }

    /// Substitute environment variables in a string
    /// - Parameter string: String that may contain `${VAR_NAME}` patterns
    /// - Returns: String with environment variables replaced
    private func substituteEnvironmentVariables(in string: String) -> String {
        var result = string
        let pattern = "\\$\\{([A-Z_][A-Z0-9_]*)\\}"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return string
        }

        let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))

        // Process matches in reverse to avoid offset issues
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let varNameRange = Range(match.range(at: 1), in: string),
                  let fullRange = Range(match.range, in: string) else {
                continue
            }

            let varName = String(string[varNameRange])
            if let envValue = ProcessInfo.processInfo.environment[varName] {
                result.replaceSubrange(fullRange, with: envValue)
            }
        }

        return result
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case version
        case patterns
        case defaults
        case validation
        case fallbackMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"

        // Decode patterns dictionary (FieldPattern: String)
        if let patternsDict = try? container.decode([String: String].self, forKey: .patterns) {
            var decodedPatterns: [FieldPattern: String] = [:]
            for (key, value) in patternsDict {
                if let pattern = Self.parsePatternKey(key) {
                    decodedPatterns[pattern] = value
                }
            }
            patterns = decodedPatterns
        } else {
            patterns = [:]
        }

        // Decode defaults dictionary (SemanticFieldType: String)
        if let defaultsDict = try? container.decode([String: String].self, forKey: .defaults) {
            defaults = [:]
            for (key, value) in defaultsDict {
                if let fieldType = SemanticFieldType(rawValue: key) {
                    defaults[fieldType] = value
                }
            }
        } else {
            defaults = [:]
        }

        validation = try container.decodeIfPresent([String: ValidationRule].self, forKey: .validation)
        fallbackMode = try container.decodeIfPresent(FallbackMode.self, forKey: .fallbackMode) ?? .aiGenerated
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(version, forKey: .version)

        // Encode patterns as string dictionary
        var patternsDict: [String: String] = [:]
        for (pattern, value) in patterns {
            patternsDict[Self.formatPatternKey(pattern)] = value
        }
        try container.encode(patternsDict, forKey: .patterns)

        // Encode defaults as string dictionary
        var defaultsDict: [String: String] = [:]
        for (fieldType, value) in defaults {
            defaultsDict[fieldType.rawValue] = value
        }
        try container.encode(defaultsDict, forKey: .defaults)

        try container.encodeIfPresent(validation, forKey: .validation)
        try container.encode(fallbackMode, forKey: .fallbackMode)
    }

    // MARK: - Pattern Key Formatting

    /// Format pattern as string key for JSON
    private static func formatPatternKey(_ pattern: FieldPattern) -> String {
        switch pattern {
        case .identifier(let value):
            return value
        case .contains(let value):
            return "pattern:contains:\(value)"
        case .regex(let value):
            return "pattern:regex:\(value)"
        case .placeholder(let value):
            return "pattern:placeholder:\(value)"
        case .label(let value):
            return "pattern:label:\(value)"
        case .semantic(let fieldType):
            return "semantic:\(fieldType.rawValue)"
        case .screenContext(let screen, let field):
            return "screen:\(screen)|field:\(field)"
        }
    }

    /// Parse pattern from string key
    private static func parsePatternKey(_ key: String) -> FieldPattern? {
        if key.hasPrefix("pattern:") {
            let components = key.split(separator: ":", maxSplits: 2).map(String.init)
            guard components.count == 3 else { return nil }

            let patternType = components[1]
            let value = components[2]

            switch patternType {
            case "contains":
                return .contains(value)
            case "regex":
                return .regex(value)
            case "placeholder":
                return .placeholder(value)
            case "label":
                return .label(value)
            default:
                return nil
            }
        } else if key.hasPrefix("semantic:") {
            let fieldTypeStr = String(key.dropFirst("semantic:".count))
            guard let fieldType = SemanticFieldType(rawValue: fieldTypeStr) else { return nil }
            return .semantic(fieldType)
        } else if key.hasPrefix("screen:") {
            // Format: screen:login|field:email
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 2 else { return nil }

            let screenPart = parts[0].dropFirst("screen:".count)
            let fieldPart = parts[1].dropFirst("field:".count)

            return .screenContext(screen: String(screenPart), field: String(fieldPart))
        } else {
            // Plain identifier
            return .identifier(key)
        }
    }
}

// MARK: - Supporting Types

/// Fallback behavior when no fixture match is found
public enum FallbackMode: String, Codable, Sendable {
    /// Use AI to generate context-aware values
    case aiGenerated

    /// Use semantic defaults only
    case semanticDefaults

    /// Use generic "test input" fallback
    case generic

    /// Fail and throw error (strict mode)
    case strict
}

/// Validation rule for field values
public struct ValidationRule: Codable, Sendable {
    /// Expected value type
    public var type: ValidationType?

    /// Minimum length
    public var minLength: Int?

    /// Maximum length
    public var maxLength: Int?

    /// Regular expression pattern to match
    public var pattern: String?

    public init(
        type: ValidationType? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil
    ) {
        self.type = type
        self.minLength = minLength
        self.maxLength = maxLength
        self.pattern = pattern
    }
}

/// Value type for validation
public enum ValidationType: String, Codable, Sendable {
    case email
    case phone
    case url
    case number
    case date
}
