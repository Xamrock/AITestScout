import Foundation

/// Metadata enriching an exploration session with context for LLM test generation
///
/// This structure bundles all the additional information (beyond basic exploration steps)
/// that an LLM needs to generate high-quality, reproducible tests.
///
/// **Design Note**: This is optional metadata that can be attached to an ExplorationPath
/// without modifying the core ExplorationPath structure. This maintains backward compatibility.
///
/// Example:
/// ```swift
/// let metadata = ExplorationMetadata(
///     environment: EnvironmentCapture.capture(),
///     elementContexts: contextMap,
///     appContext: AppContext(
///         bundleId: "com.example.app",
///         appVersion: "1.0.0",
///         buildNumber: "100"
///     )
/// )
/// explorationPath.attachMetadata(metadata)
/// ```
public struct ExplorationMetadata: Codable, Equatable {
    /// Environment information (OS, device, screen size, etc.)
    public let environment: EnvironmentInfo

    /// Element contexts mapped by element key (type|id|label)
    /// Contains detailed state and query information for each element
    public let elementContexts: [String: ElementContext]

    /// Application context (bundle ID, version, build)
    public let appContext: AppContext

    public init(
        environment: EnvironmentInfo,
        elementContexts: [String: ElementContext],
        appContext: AppContext
    ) {
        self.environment = environment
        self.elementContexts = elementContexts
        self.appContext = appContext
    }
}
