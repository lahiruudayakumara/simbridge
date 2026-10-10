import Foundation

public enum SimulatorDiscoveryError: LocalizedError, Sendable {
    case commandFailed(String)
    case invalidOutput
    case allServicesFailed(coreSimulator: String, deviceHub: String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message): "simctl failed: \(message)"
        case .invalidOutput: "simctl returned data that could not be read."
        case .allServicesFailed(let coreSimulator, let deviceHub):
            "Simulator services are unavailable. CoreSimulator: \(coreSimulator). Device Hub: \(deviceHub)."
        }
    }
}

public protocol SimulatorDiscovering: Sendable {
    func discover() async throws -> [Simulator]
}

public struct SimctlSimulatorDiscovery: SimulatorDiscovering {
    public init() {}

    public func discover() async throws -> [Simulator] {
        async let coreSimulatorResult = attempt {
            try await run(arguments: ["simctl", "list", "devices", "--json"])
        }
        async let deviceHubResult = attempt {
            try await run(arguments: [
                "devicectl", "--quiet", "--json-output", "-",
                "--omit-deprecated-fields-in-json", "list", "devices",
            ])
        }

        let (coreAttempt, hubAttempt) = await (coreSimulatorResult, deviceHubResult)
        let coreDevices = try? SimulatorListParser.parse(coreAttempt.get())
        let hubDevices = try? DeviceHubListParser.parse(hubAttempt.get())

        if coreDevices == nil && hubDevices == nil {
            throw SimulatorDiscoveryError.allServicesFailed(
                coreSimulator: coreAttempt.failureDescription,
                deviceHub: hubAttempt.failureDescription
            )
        }
        return SimulatorInventoryMerger.merge(
            coreSimulator: coreDevices ?? [],
            deviceHub: hubDevices ?? []
        )
    }

    private func attempt(
        _ operation: @escaping @Sendable () async throws -> Data
    ) async -> Result<Data, SimulatorDiscoveryError> {
        do { return .success(try await operation()) }
        catch let error as SimulatorDiscoveryError { return .failure(error) }
        catch { return .failure(.commandFailed(error.localizedDescription)) }
    }

    private func run(arguments: [String]) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = errors

            do {
                try process.run()
            } catch {
                throw SimulatorDiscoveryError.commandFailed(error.localizedDescription)
            }
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let data = errors.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8) ?? "exit \(process.terminationStatus)"
                throw SimulatorDiscoveryError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard !data.isEmpty else { throw SimulatorDiscoveryError.invalidOutput }
            return data
        }.value
    }
}

private extension Result where Failure == SimulatorDiscoveryError {
    var failureDescription: String {
        switch self {
        case .success: "available"
        case .failure(let error): error.localizedDescription
        }
    }
}
