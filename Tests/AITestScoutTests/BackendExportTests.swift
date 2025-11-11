import Testing
import Foundation
@testable import AITestScout

@Suite("Backend Export Tests")
struct BackendExportTests {

    // MARK: - Test Fixtures

    /// Creates a sample exploration path for testing
    private func makeSamplePath(
        goal: String = "Test exploration",
        stepCount: Int = 0,
        successfulSteps: Int = 0
    ) -> ExplorationPath {
        let path = ExplorationPath(goal: goal, sessionId: UUID())

        for i in 0..<stepCount {
            let isSuccessful = i < successfulSteps
            let step = ExplorationStep(
                action: i % 3 == 0 ? "tap" : (i % 3 == 1 ? "type" : "swipe"),
                targetElement: i % 3 == 2 ? nil : "element\(i)",
                textTyped: i % 3 == 1 ? "test\(i)@example.com" : nil,
                screenDescription: "Screen \(i / 2)",
                interactiveElementCount: 3 + i,
                reasoning: "Step \(i) reasoning",
                confidence: 70 + (i * 5) % 30,
                wasSuccessful: isSuccessful,
                screenshotPath: i % 2 == 0 ? "screenshots/step_\(i).png" : nil
            )
            path.addStep(step)
        }

        return path
    }

    /// Creates a sample navigation graph for testing
    private func makeSampleGraph(screenCount: Int = 0) -> NavigationGraph {
        let graph = NavigationGraph()

        for i in 0..<screenCount {
            let node = ScreenNode(
                fingerprint: "screen\(i)",
                screenType: i == 0 ? .login : .content,
                elements: [],
                screenshot: Data(),
                depth: i,
                parentFingerprint: i > 0 ? "screen\(i-1)" : nil
            )
            graph.addNode(node)
        }

        return graph
    }

    // MARK: - Backend Export Tests

    @Suite("Backend Export")
    struct ExportTests {

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Exports BackendExplorationData with correct version")
        func exportVersion() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath()
            let graph = NavigationGraph()

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.version == "1.0")
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Exports all exploration steps")
        func exportSteps() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath(stepCount: 5, successfulSteps: 3)
            let graph = NavigationGraph()

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.steps.count == 5)
            #expect(backendData.steps[0].stepNumber == 1)
            #expect(backendData.steps[0].action == "tap")
            #expect(backendData.steps[0].wasSuccessful == true)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Exports navigation graph data")
        func exportNavigationGraph() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath()
            let graph = BackendExportTests().makeSampleGraph(screenCount: 3)

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.navigationGraph.totalScreens == 3)
            #expect(backendData.navigationGraph.totalTransitions == 0)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Exports insights with correct metrics")
        func exportInsights() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath(stepCount: 10, successfulSteps: 7)
            let graph = NavigationGraph()

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.insights.totalSteps == 10)
            #expect(backendData.insights.successfulSteps == 7)
            #expect(backendData.insights.failedSteps == 3)
            #expect(backendData.insights.crashSteps == 0)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Step numbers are sequential starting from 1")
        func stepNumbering() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath(stepCount: 3)
            let graph = NavigationGraph()

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.steps[0].stepNumber == 1)
            #expect(backendData.steps[1].stepNumber == 2)
            #expect(backendData.steps[2].stepNumber == 3)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Screenshot paths are included when present")
        func screenshotPaths() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath(stepCount: 4)
            let graph = NavigationGraph()

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            // Even steps have screenshots (0, 2), odd steps don't (1, 3)
            #expect(backendData.steps[0].screenshotPath == "screenshots/step_0.png")
            #expect(backendData.steps[1].screenshotPath == nil)
            #expect(backendData.steps[2].screenshotPath == "screenshots/step_2.png")
            #expect(backendData.steps[3].screenshotPath == nil)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Empty element contexts are included")
        func emptyElementContexts() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath()
            let graph = NavigationGraph()

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.elementContexts.isEmpty)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Handles empty exploration path")
        func emptyPath() throws {
            let exporter = ExplorationExporter()
            let path = ExplorationPath(goal: "Empty path")
            let graph = NavigationGraph()

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.steps.isEmpty)
            #expect(backendData.insights.totalSteps == 0)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Calculates average confidence correctly")
        func averageConfidence() throws {
            let exporter = ExplorationExporter()
            let path = ExplorationPath(goal: "Confidence test")

            // Add steps with known confidence values: 70, 75, 80 (avg = 75)
            for i in 0..<3 {
                let step = ExplorationStep(
                    action: "tap",
                    targetElement: "element\(i)",
                    textTyped: nil,
                    screenDescription: "Screen",
                    interactiveElementCount: 5,
                    reasoning: "Test",
                    confidence: 70 + (i * 5),
                    wasSuccessful: true
                )
                path.addStep(step)
            }

            let graph = NavigationGraph()

            let data = try exporter.exportBackendData(
                explorationPath: path,
                navigationGraph: graph
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.insights.avgConfidence == 75.0)
        }
    }

    // MARK: - File Saving Tests

    @Suite("File Saving")
    struct FileSavingTests {

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Saves exploration.json to file")
        func saveToFile() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath(stepCount: 2)
            let graph = NavigationGraph()

            // Create temp directory
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("BackendExportTests_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let fileURL = tempDir.appendingPathComponent("exploration.json")

            // Save file
            try exporter.saveBackendData(
                explorationPath: path,
                navigationGraph: graph,
                to: fileURL
            )

            // Verify file exists
            #expect(FileManager.default.fileExists(atPath: fileURL.path))

            // Verify file contents are valid
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.steps.count == 2)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Overwrites existing file")
        func overwriteExisting() throws {
            let exporter = ExplorationExporter()
            let path1 = BackendExportTests().makeSamplePath(stepCount: 2)
            let path2 = BackendExportTests().makeSamplePath(stepCount: 5)
            let graph = NavigationGraph()

            // Create temp directory
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("BackendExportTests_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let fileURL = tempDir.appendingPathComponent("exploration.json")

            // Save first file
            try exporter.saveBackendData(
                explorationPath: path1,
                navigationGraph: graph,
                to: fileURL
            )

            // Save second file (overwrite)
            try exporter.saveBackendData(
                explorationPath: path2,
                navigationGraph: graph,
                to: fileURL
            )

            // Verify second file contents
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backendData = try decoder.decode(BackendExplorationData.self, from: data)

            #expect(backendData.steps.count == 5)
        }

        @available(macOS 26.0, iOS 26.0, *)
        @Test("Creates parent directories if needed")
        func createParentDirectories() throws {
            let exporter = ExplorationExporter()
            let path = BackendExportTests().makeSamplePath(stepCount: 1)
            let graph = NavigationGraph()

            // Create temp directory
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("BackendExportTests_\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let nestedDir = tempDir.appendingPathComponent("nested/path")
            let fileURL = nestedDir.appendingPathComponent("exploration.json")

            // Save file (should create nested/path directories)
            try exporter.saveBackendData(
                explorationPath: path,
                navigationGraph: graph,
                to: fileURL
            )

            // Verify file exists
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }
}
