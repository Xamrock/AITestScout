import Foundation

/// Information about the application under test
public struct AppContext: Codable, Equatable {
    /// Bundle identifier (e.g., "com.example.app")
    public let bundleId: String

    /// App version (e.g., "2.5.0")
    public let appVersion: String

    /// Build number (e.g., "145")
    public let buildNumber: String

    /// Launch arguments passed to the app during testing
    public let launchArguments: [String]

    /// Launch environment variables
    public let launchEnvironment: [String: String]

    public init(
        bundleId: String,
        appVersion: String,
        buildNumber: String,
        launchArguments: [String] = [],
        launchEnvironment: [String: String] = [:]
    ) {
        self.bundleId = bundleId
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.launchArguments = launchArguments
        self.launchEnvironment = launchEnvironment
    }
}
