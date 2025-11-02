import Foundation

/// Pattern matching strategies for identifying fields during exploration
///
/// Patterns are evaluated in priority order (exact identifier → regex → contains → semantic)
/// to find the best match for a given UI element.
///
/// **Usage:**
/// ```swift
/// let fixture = ExplorationFixture(patterns: [
///     .identifier("loginEmailField"): "admin@test.com",
///     .contains("password"): "SecurePass123",
///     .regex("card.*number"): "4242424242424242",
///     .placeholder("Enter ZIP"): "94103",
///     .label("Phone Number"): "555-0123",
///     .semantic(.email): "user@company.com",
///     .screenContext("login", field: "email"): "specific@login.com"
/// ])
/// ```
public enum FieldPattern: Hashable, Codable, Sendable {
    /// Exact match on element identifier
    case identifier(String)

    /// Case-insensitive substring match on identifier
    case contains(String)

    /// Regular expression match on identifier
    case regex(String)

    /// Match on placeholder text
    case placeholder(String)

    /// Match on element label/accessibilityLabel
    case label(String)

    /// Semantic type matching (email, phone, url, etc.)
    case semantic(SemanticFieldType)

    /// Context-aware matching (screen type + field identifier)
    case screenContext(screen: String, field: String)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case value
        case screen
        case field
        case semanticType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "identifier":
            let value = try container.decode(String.self, forKey: .value)
            self = .identifier(value)
        case "contains":
            let value = try container.decode(String.self, forKey: .value)
            self = .contains(value)
        case "regex":
            let value = try container.decode(String.self, forKey: .value)
            self = .regex(value)
        case "placeholder":
            let value = try container.decode(String.self, forKey: .value)
            self = .placeholder(value)
        case "label":
            let value = try container.decode(String.self, forKey: .value)
            self = .label(value)
        case "semantic":
            let semanticType = try container.decode(SemanticFieldType.self, forKey: .semanticType)
            self = .semantic(semanticType)
        case "screenContext":
            let screen = try container.decode(String.self, forKey: .screen)
            let field = try container.decode(String.self, forKey: .field)
            self = .screenContext(screen: screen, field: field)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid pattern type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .identifier(let value):
            try container.encode("identifier", forKey: .type)
            try container.encode(value, forKey: .value)
        case .contains(let value):
            try container.encode("contains", forKey: .type)
            try container.encode(value, forKey: .value)
        case .regex(let value):
            try container.encode("regex", forKey: .type)
            try container.encode(value, forKey: .value)
        case .placeholder(let value):
            try container.encode("placeholder", forKey: .type)
            try container.encode(value, forKey: .value)
        case .label(let value):
            try container.encode("label", forKey: .type)
            try container.encode(value, forKey: .value)
        case .semantic(let semanticType):
            try container.encode("semantic", forKey: .type)
            try container.encode(semanticType, forKey: .semanticType)
        case .screenContext(let screen, let field):
            try container.encode("screenContext", forKey: .type)
            try container.encode(screen, forKey: .screen)
            try container.encode(field, forKey: .field)
        }
    }

    // MARK: - Pattern Matching

    /// Check if this pattern matches a given element
    /// - Parameters:
    ///   - element: The UI element to match against
    ///   - screenType: Optional screen type for context matching
    /// - Returns: True if pattern matches the element
    public func matches(_ element: MinimalElement, screenType: ScreenType? = nil) -> Bool {
        switch self {
        case .identifier(let target):
            return element.id == target

        case .contains(let substring):
            let lowercased = substring.lowercased()
            if let id = element.id, id.lowercased().contains(lowercased) {
                return true
            }
            if let label = element.label, label.lowercased().contains(lowercased) {
                return true
            }
            return false

        case .regex(let pattern):
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return false
            }
            if let id = element.id {
                let range = NSRange(id.startIndex..<id.endIndex, in: id)
                if regex.firstMatch(in: id, options: [], range: range) != nil {
                    return true
                }
            }
            if let label = element.label {
                let range = NSRange(label.startIndex..<label.endIndex, in: label)
                if regex.firstMatch(in: label, options: [], range: range) != nil {
                    return true
                }
            }
            return false

        case .placeholder(let target):
            // MinimalElement doesn't have placeholder field yet, so check label/value
            return element.label == target || element.value == target

        case .label(let target):
            return element.label == target

        case .semantic(let fieldType):
            return fieldType.matches(element)

        case .screenContext(let screen, let field):
            guard let screenType = screenType,
                  screenType.rawValue.lowercased() == screen.lowercased() else {
                return false
            }
            // Check if field matches identifier or contains
            if let id = element.id, id.lowercased().contains(field.lowercased()) {
                return true
            }
            if let label = element.label, label.lowercased().contains(field.lowercased()) {
                return true
            }
            return false
        }
    }

    /// Priority for pattern matching (higher = evaluated first)
    public var priority: Int {
        switch self {
        case .screenContext:
            return 100 // Most specific
        case .identifier:
            return 90
        case .semantic:
            return 80
        case .regex:
            return 70
        case .label:
            return 60
        case .placeholder:
            return 50
        case .contains:
            return 40 // Least specific
        }
    }
}

/// Semantic field types for intelligent matching
public enum SemanticFieldType: String, Codable, Hashable, Sendable {
    case email
    case password
    case phone
    case url
    case creditCard
    case zipCode
    case name
    case address
    case city
    case state
    case country
    case username
    case search
    case date
    case number

    /// Check if an element semantically matches this type
    func matches(_ element: MinimalElement) -> Bool {
        let identifier = (element.id ?? element.label ?? "").lowercased()

        switch self {
        case .email:
            return identifier.contains("email") || identifier.contains("e-mail")
        case .password:
            return identifier.contains("password") || identifier.contains("pwd")
        case .phone:
            return identifier.contains("phone") || identifier.contains("tel") || identifier.contains("mobile")
        case .url:
            return identifier.contains("url") || identifier.contains("website") || identifier.contains("link")
        case .creditCard:
            return identifier.contains("card") || identifier.contains("credit") || identifier.contains("payment")
        case .zipCode:
            return identifier.contains("zip") || identifier.contains("postal")
        case .name:
            return identifier.contains("name") || identifier.contains("fullname")
        case .address:
            return identifier.contains("address") || identifier.contains("street")
        case .city:
            return identifier.contains("city") || identifier.contains("town")
        case .state:
            return identifier.contains("state") || identifier.contains("province")
        case .country:
            return identifier.contains("country") || identifier.contains("nation")
        case .username:
            return identifier.contains("username") || identifier.contains("user") && identifier.contains("name")
        case .search:
            return identifier.contains("search") || identifier.contains("query")
        case .date:
            return identifier.contains("date") || identifier.contains("birthday") || identifier.contains("dob")
        case .number:
            return identifier.contains("number") || identifier.contains("quantity") || identifier.contains("amount")
        }
    }

    /// Generate a realistic default value for this semantic type
    public var defaultValue: String {
        switch self {
        case .email:
            return "test@example.com"
        case .password:
            return "TestPassword123"
        case .phone:
            return "555-0100"
        case .url:
            return "https://example.com"
        case .creditCard:
            return "4242424242424242"
        case .zipCode:
            return "94103"
        case .name:
            return "Test User"
        case .address:
            return "123 Main St"
        case .city:
            return "San Francisco"
        case .state:
            return "CA"
        case .country:
            return "USA"
        case .username:
            return "testuser"
        case .search:
            return "test query"
        case .date:
            return "1990-01-15"
        case .number:
            return "42"
        }
    }
}
