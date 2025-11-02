# Exploration Fixtures

Fixtures provide custom test data for UI exploration, allowing you to specify realistic values for form fields instead of using generic defaults.

## Quick Start

```swift
// Load fixture from file
let fixture = try ExplorationFixture.load(from: "fixtures/login-flow.json")

// Use in exploration
var config = ExplorationConfig(steps: 20, goal: "Test login")
config.fixture = fixture
let result = try Scout.explore(app, config: config)
```

## Fixture Format

Fixtures are JSON files with the following structure:

```json
{
  "version": "1.0",
  "name": "My Test Fixture",
  "description": "Test data for my app",
  "patterns": {
    "emailField": "test@example.com",
    "pattern:contains:password": "SecurePass123",
    "semantic:phone": "555-0123",
    "screen:login|field:email": "admin@app.com"
  },
  "defaults": {
    "email": "default@example.com",
    "phone": "555-9999"
  },
  "fallbackMode": "aiGenerated"
}
```

## Pattern Types

### 1. Exact Identifier Match
```json
{
  "emailField": "user@test.com"
}
```
Matches elements with exact ID `"emailField"`.

### 2. Contains Pattern
```json
{
  "pattern:contains:email": "user@company.com"
}
```
Matches any element whose ID contains "email" (case-insensitive).

### 3. Regex Pattern
```json
{
  "pattern:regex:card.*[Nn]umber": "4242424242424242"
}
```
Matches element IDs using regular expressions.

### 4. Placeholder Match
```json
{
  "pattern:placeholder:Enter email": "test@example.com"
}
```
Matches elements with specific placeholder text.

### 5. Label Match
```json
{
  "pattern:label:Email Address": "user@test.com"
}
```
Matches elements with specific accessibility labels.

### 6. Semantic Match
```json
{
  "semantic:email": "demo@test.com",
  "semantic:phone": "555-0123",
  "semantic:creditCard": "4242424242424242"
}
```

Supported semantic types:
- `email`, `password`, `phone`, `url`
- `creditCard`, `zipCode`, `name`, `address`
- `city`, `state`, `country`, `username`
- `search`, `date`, `number`

### 7. Screen Context Match
```json
{
  "screen:login|field:email": "admin@app.com",
  "screen:checkout|field:email": "customer@shop.com"
}
```
Most specific - matches field on specific screen type.

## Resolution Order (Priority)

When multiple patterns match, they're evaluated in priority order:

1. **Screen context + field** - Most specific
2. **Exact identifier**
3. **Pattern match** (regex, contains, label, placeholder)
4. **Semantic match**
5. **Type-based defaults**
6. **AI-generated** (context-aware)
7. **Generic fallback**

## Environment Variables

Use environment variables for sensitive data:

```json
{
  "patterns": {
    "passwordField": "${TEST_PASSWORD}",
    "apiKeyField": "${API_KEY}"
  }
}
```

Set in your test environment:
```bash
export TEST_PASSWORD="MySecurePassword123"
export API_KEY="sk-test-..."
```

## Defaults

Provide fallback values for semantic types:

```json
{
  "defaults": {
    "email": "default@example.com",
    "phone": "555-9999",
    "name": "Test User",
    "zipCode": "94105"
  }
}
```

## Fallback Modes

Control what happens when no pattern matches:

- **`aiGenerated`** (default) - AI generates context-aware values
- **`semanticDefaults`** - Use semantic type defaults only
- **`generic`** - Use simple generic values ("test input")
- **`strict`** - Throw error if no match found

```json
{
  "fallbackMode": "aiGenerated"
}
```

## Programmatic Usage

Create fixtures in code:

```swift
let fixture = ExplorationFixture(
    name: "Login Test",
    patterns: [
        .identifier("emailField"): "test@example.com",
        .contains("password"): "SecurePass123",
        .semantic(.phone): "555-0123",
        .screenContext(screen: "login", field: "email"): "admin@app.com"
    ],
    defaults: [
        .email: "default@example.com",
        .phone: "555-9999"
    ],
    fallbackMode: .aiGenerated
)

var config = ExplorationConfig(steps: 20, goal: "Test app")
config.fixture = fixture
```

## Best Practices

1. **Use specific patterns first** - Screen context is most reliable
2. **Environment variables for secrets** - Never commit passwords to fixtures
3. **Provide defaults** - Ensure common field types are covered
4. **Enable AI fallback** - Let AI handle unexpected fields gracefully
5. **Version control fixtures** - Share across team (except secrets)

## Examples

See `login-flow.json` for a complete example covering:
- Login credentials
- Multiple screen contexts
- Pattern matching strategies
- Environment variable usage
- Semantic defaults

## Debugging

Enable verbose output to see which values are being used:

```swift
config.verboseOutput = true
```

Console output will show:
```
💎 Using fixture value for 'emailField': admin@app.com
```

Value sources are also tracked in `ExplorationStep` for dashboard visualization.
