import Foundation
import Testing
@testable import SimBridgeCore

@Suite("bridge session registry")
struct BridgeSessionRegistryTests {
    private let booted = Simulator(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Test iPhone",
        runtime: "iOS 18.2", state: .booted, isAvailable: true
    )

    @Test("starts a session and writes a discoverable manifest")
    func startsSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let registry = BridgeSessionRegistry(socketDirectory: directory)
        let session = try await registry.start(simulator: booted, options: BridgeOptions())
        #expect(session.status == .running)
        #expect(session.simulatorID == booted.id)
        let manifest = directory.appendingPathComponent("\(booted.id.uuidString.lowercased()).json")
        #expect(FileManager.default.fileExists(atPath: manifest.path))
    }

    @Test("rejects a shutdown simulator")
    func rejectsShutdownSimulator() async {
        let simulator = Simulator(id: UUID(), name: "Sleeping iPhone", runtime: "iOS 18.2", state: .shutdown, isAvailable: true)
        let registry = BridgeSessionRegistry()
        await #expect(throws: BridgeSessionError.self) {
            try await registry.start(simulator: simulator, options: BridgeOptions())
        }
    }

    @Test("requires at least one hardware bridge")
    func rejectsEmptyOptions() async {
        let registry = BridgeSessionRegistry()
        await #expect(throws: BridgeSessionError.self) {
            try await registry.start(simulator: booted, options: BridgeOptions(bluetoothEnabled: false, cameraEnabled: false))
        }
    }
}
