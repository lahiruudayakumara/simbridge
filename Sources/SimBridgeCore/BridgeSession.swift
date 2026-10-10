import Foundation

public struct BridgeOptions: Codable, Equatable, Sendable {
    public var bluetoothEnabled: Bool
    public var cameraEnabled: Bool
    public var cameraID: String?

    public init(bluetoothEnabled: Bool = true, cameraEnabled: Bool = true, cameraID: String? = nil) {
        self.bluetoothEnabled = bluetoothEnabled
        self.cameraEnabled = cameraEnabled
        self.cameraID = cameraID
    }
}

public struct BridgeSession: Identifiable, Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case starting, running, failed, stopped }

    public let id: UUID
    public let simulatorID: UUID
    public let simulatorName: String
    public let endpoint: String
    public let startedAt: Date
    public var options: BridgeOptions
    public var status: Status

    public init(
        id: UUID = UUID(), simulatorID: UUID, simulatorName: String, endpoint: String,
        startedAt: Date = Date(), options: BridgeOptions, status: Status = .starting
    ) {
        self.id = id
        self.simulatorID = simulatorID
        self.simulatorName = simulatorName
        self.endpoint = endpoint
        self.startedAt = startedAt
        self.options = options
        self.status = status
    }
}

public enum BridgeSessionError: LocalizedError, Sendable {
    case simulatorNotBooted, noHardwareSelected, alreadyRunning

    public var errorDescription: String? {
        switch self {
        case .simulatorNotBooted: "Start the selected simulator before starting a bridge."
        case .noHardwareSelected: "Enable Bluetooth LE or camera before starting a bridge."
        case .alreadyRunning: "A bridge is already running for this simulator."
        }
    }
}

public actor BridgeSessionRegistry {
    private var sessions: [UUID: BridgeSession] = [:]
    private let socketDirectory: URL

    public init(socketDirectory: URL? = nil) {
        self.socketDirectory = socketDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("simbridge", isDirectory: true)
    }

    public func start(simulator: Simulator, options: BridgeOptions) throws -> BridgeSession {
        guard simulator.state == .booted else { throw BridgeSessionError.simulatorNotBooted }
        guard options.bluetoothEnabled || options.cameraEnabled else { throw BridgeSessionError.noHardwareSelected }
        guard sessions[simulator.id]?.status != .running else { throw BridgeSessionError.alreadyRunning }

        try FileManager.default.createDirectory(at: socketDirectory, withIntermediateDirectories: true)
        let endpoint = socketDirectory.appendingPathComponent("\(simulator.id.uuidString.lowercased()).sock").path
        let session = BridgeSession(
            simulatorID: simulator.id, simulatorName: simulator.name, endpoint: endpoint,
            options: options, status: .running
        )
        sessions[simulator.id] = session
        try writeManifest(for: session)
        return session
    }

    public func stop(simulatorID: UUID) {
        guard var session = sessions[simulatorID] else { return }
        session.status = .stopped
        sessions[simulatorID] = session
        try? FileManager.default.removeItem(at: manifestURL(for: simulatorID))
    }

    public func session(for simulatorID: UUID) -> BridgeSession? { sessions[simulatorID] }

    public func allSessions() -> [BridgeSession] {
        sessions.values.sorted { $0.startedAt < $1.startedAt }
    }

    private func manifestURL(for simulatorID: UUID) -> URL {
        socketDirectory.appendingPathComponent("\(simulatorID.uuidString.lowercased()).json")
    }

    private func writeManifest(for session: BridgeSession) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(session).write(to: manifestURL(for: session.simulatorID), options: .atomic)
    }
}
