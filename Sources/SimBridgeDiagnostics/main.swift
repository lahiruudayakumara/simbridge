import Darwin
import Foundation
import SimBridgeCore

@main
struct SimBridgeDiagnostics {
    static func main() async {
        do {
            let simulators = try await SimctlSimulatorDiscovery().discover()
            if CommandLine.arguments.contains("--json") {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                FileHandle.standardOutput.write(try encoder.encode(simulators))
                FileHandle.standardOutput.write(Data("\n".utf8))
            } else {
                for simulator in simulators {
                    let deviceHub = simulator.isVisibleInDeviceHub ? "Device Hub" : "CoreSimulator"
                    print("\(simulator.state.rawValue)\t\(simulator.name)\t\(simulator.runtime)\t\(deviceHub)\t\(simulator.id)")
                }
            }
        } catch {
            FileHandle.standardError.write(Data("SimBridge diagnostics failed: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }
}
