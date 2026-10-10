import Foundation

/// Parses the stable JSON document emitted by Xcode 27's `devicectl`.
public enum DeviceHubListParser {
    private struct Payload: Decodable { let result: ResultPayload }
    private struct ResultPayload: Decodable { let devices: [Device] }
    private struct Device: Decodable {
        let identifier: String
        let properties: Properties
    }
    private struct Properties: Decodable {
        let hardware: Hardware
        let software: Software?
        let state: DeviceState
    }
    private struct Hardware: Decodable {
        let marketingName: String?
        let platform: String?
        let reality: String?
        let udid: String?
    }
    private struct Software: Decodable { let osVersionNumber: VersionNumber? }
    private struct VersionNumber: Decodable { let stringValue: String? }
    private struct DeviceState: Decodable {
        let bootState: String?
        let name: String?
        let visibilityClass: String?
    }

    public static func parse(_ data: Data) throws -> [Simulator] {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.result.devices.compactMap { device in
            let hardware = device.properties.hardware
            let state = device.properties.state
            guard hardware.reality?.lowercased() == "simulated" || state.visibilityClass == "simulators" else {
                return nil
            }
            guard let id = UUID(uuidString: hardware.udid ?? device.identifier) else { return nil }
            let name = state.name ?? hardware.marketingName ?? "Simulator"
            let platform = hardware.platform ?? "iOS"
            let version = device.properties.software?.osVersionNumber?.stringValue
            return Simulator(
                id: id,
                name: name,
                runtime: version.map { "\(platform) \($0)" } ?? platform,
                state: simulatorState(from: state.bootState),
                isAvailable: true,
                isVisibleInDeviceHub: true
            )
        }
    }

    private static func simulatorState(from bootState: String?) -> Simulator.State {
        switch bootState?.lowercased() {
        case "booted": .booted
        case "shutdown": .shutdown
        case "creating": .creating
        case "shuttingdown", "shutting down": .shuttingDown
        default: .unknown
        }
    }
}

public enum SimulatorInventoryMerger {
    public static func merge(coreSimulator: [Simulator], deviceHub: [Simulator]) -> [Simulator] {
        var merged = Dictionary(uniqueKeysWithValues: coreSimulator.map { ($0.id, $0) })
        for hubDevice in deviceHub {
            if let coreDevice = merged[hubDevice.id] {
                merged[hubDevice.id] = Simulator(
                    id: coreDevice.id,
                    name: hubDevice.name,
                    runtime: hubDevice.runtime,
                    state: hubDevice.state,
                    isAvailable: coreDevice.isAvailable,
                    isVisibleInDeviceHub: true
                )
            } else {
                merged[hubDevice.id] = hubDevice
            }
        }
        return SimulatorListParser.sorted(Array(merged.values))
    }
}
