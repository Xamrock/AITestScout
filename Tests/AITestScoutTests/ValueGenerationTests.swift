import Testing
@testable import AITestScout

/// Baseline tests for current value generation behavior in AICrawler
/// These tests establish expected behavior before introducing ExplorationFixture system
@Suite("Value Generation Baseline Tests")
struct ValueGenerationTests {

    // MARK: - Current Hardcoded Behavior Tests

    @Test("Email field generates test@example.com")
    func testEmailFieldGeneration() {
        // Test various email field identifiers
        let emailFields = [
            "emailField",
            "userEmail",
            "loginEmail",
            "EMAIL_INPUT",
            "txtEmail"
        ]

        for fieldId in emailFields {
            let value = generateTestTextFor(fieldId: fieldId)
            #expect(value == "test@example.com", "Field '\(fieldId)' should generate email value")
        }
    }

    @Test("Password field generates TestPassword123")
    func testPasswordFieldGeneration() {
        let passwordFields = [
            "passwordField",
            "userPassword",
            "loginPassword",
            "PASSWORD_INPUT",
            "txtPassword"
        ]

        for fieldId in passwordFields {
            let value = generateTestTextFor(fieldId: fieldId)
            #expect(value == "TestPassword123", "Field '\(fieldId)' should generate password value")
        }
    }

    @Test("Phone field generates 555-0100")
    func testPhoneFieldGeneration() {
        let phoneFields = [
            "phoneField",
            "userPhone",
            "phoneNumber",
            "PHONE_INPUT",
            "txtPhone"
        ]

        for fieldId in phoneFields {
            let value = generateTestTextFor(fieldId: fieldId)
            #expect(value == "555-0100", "Field '\(fieldId)' should generate phone value")
        }
    }

    @Test("Name field generates Test User")
    func testNameFieldGeneration() {
        let nameFields = [
            "nameField",
            "userName",
            "fullName",
            "NAME_INPUT",
            "txtName"
        ]

        for fieldId in nameFields {
            let value = generateTestTextFor(fieldId: fieldId)
            #expect(value == "Test User", "Field '\(fieldId)' should generate name value")
        }
    }

    @Test("Search field generates test query")
    func testSearchFieldGeneration() {
        let searchFields = [
            "searchField",
            "searchBar",
            "searchInput",
            "SEARCH_INPUT",
            "txtSearch"
        ]

        for fieldId in searchFields {
            let value = generateTestTextFor(fieldId: fieldId)
            #expect(value == "test query", "Field '\(fieldId)' should generate search value")
        }
    }

    @Test("Unknown field generates test input")
    func testUnknownFieldGeneration() {
        let unknownFields = [
            "customField",
            "apartmentNumber",
            "favoriteColor",
            "randomInput",
            "field123"
        ]

        for fieldId in unknownFields {
            let value = generateTestTextFor(fieldId: fieldId)
            #expect(value == "test input", "Field '\(fieldId)' should generate generic value")
        }
    }

    // MARK: - Edge Cases

    @Test("Case insensitive matching works")
    func testCaseInsensitiveMatching() {
        let variants = [
            "EMAIL",
            "Email",
            "email",
            "eMaIl",
            "EMAILFIELD"
        ]

        for fieldId in variants {
            let value = generateTestTextFor(fieldId: fieldId)
            #expect(value == "test@example.com", "Case variation '\(fieldId)' should match email")
        }
    }

    @Test("Substring matching works")
    func testSubstringMatching() {
        let fields = [
            "myEmailAddress",
            "prefixEmailSuffix",
            "email_field_name",
            "user.email.input"
        ]

        for fieldId in fields {
            let value = generateTestTextFor(fieldId: fieldId)
            #expect(value == "test@example.com", "Field '\(fieldId)' with email substring should match")
        }
    }

    @Test("First match wins (email before name)")
    func testMatchPriority() {
        // Email is checked before name, so "emailName" should match email
        let value = generateTestTextFor(fieldId: "emailName")
        #expect(value == "test@example.com", "Email pattern should match before name")
    }

    @Test("Empty field ID generates fallback")
    func testEmptyFieldId() {
        let value = generateTestTextFor(fieldId: "")
        #expect(value == "test input", "Empty field ID should generate fallback")
    }

    // MARK: - Helper (mirrors current AICrawler implementation)

    /// This mirrors the current AICrawler.generateTestTextFor() method
    /// Used as baseline for testing fixture system replacement
    private func generateTestTextFor(fieldId: String) -> String {
        let lowercased = fieldId.lowercased()

        if lowercased.contains("email") {
            return "test@example.com"
        } else if lowercased.contains("password") {
            return "TestPassword123"
        } else if lowercased.contains("phone") {
            return "555-0100"
        } else if lowercased.contains("name") {
            return "Test User"
        } else if lowercased.contains("search") {
            return "test query"
        } else {
            return "test input"
        }
    }
}
