import Foundation

public struct Simulator: Identifiable, Codable, Hashable, Sendable {
    public enum State: String, Codable, Sendable {
        case booted = "Booted"
        case shutdown = "Shutdown"
        case creating = "Creating"
        case shuttingDown = "Shutting Down"
        case unknown

        public init(simctlValue: String) {
            self = State(rawValue: simctlValue) ?? .unknown
        }
    }

    public let id: UUID
    public let name: String
    public let runtime: String
    public let state: State
    public let isAvailable: Bool
    public let isVisibleInDeviceHub: Bool

    public init(
        id: UUID,
        name: String,
        runtime: String,
        state: State,
        isAvailable: Bool,
        isVisibleInDeviceHub: Bool = false
    ) {
        self.id = id
        self.name = name
        self.runtime = runtime
        self.state = state
        self.isAvailable = isAvailable
        self.isVisibleInDeviceHub = isVisibleInDeviceHub
    }
}

public enum SimulatorListParser {
    private struct Payload: Decodable {
        let devices: [String: [Device]]
    }

    private struct Device: Decodable {
        let name: String
        let udid: String
        let state: String
        let isAvailable: Bool?
    }

    public static func parse(_ data: Data) throws -> [Simulator] {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.devices.flatMap { runtimeIdentifier, devices in
            devices.compactMap { device -> Simulator? in
                guard let id = UUID(uuidString: device.udid) else { return nil }
                return Simulator(
                    id: id,
                    name: device.name,
                    runtime: displayName(for: runtimeIdentifier),
                    state: .init(simctlValue: device.state),
                    isAvailable: device.isAvailable ?? true,
                    isVisibleInDeviceHub: false
                )
            }
        }
        .filter(\.isAvailable)
        .sorted {
            if $0.state != $1.state { return $0.state == .booted }
            if $0.runtime != $1.runtime { return $0.runtime > $1.runtime }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func displayName(for identifier: String) -> String {
        let value = identifier.split(separator: ".").last.map(String.init) ?? identifier
        let components = value.split(separator: "-").map(String.init)
        guard components.count >= 3, components[0] == "iOS" else {
            return value.replacingOccurrences(of: "-", with: " ")
        }
        return "iOS \(components.dropFirst().joined(separator: "."))"
    }

    public static func sorted(_ simulators: [Simulator]) -> [Simulator] {
        simulators.sorted {
            if $0.state != $1.state { return $0.state == .booted }
            if $0.runtime != $1.runtime { return $0.runtime > $1.runtime }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
