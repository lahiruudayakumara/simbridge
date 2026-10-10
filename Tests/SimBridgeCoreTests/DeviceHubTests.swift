import Foundation
import Testing
@testable import SimBridgeCore

@Suite("Xcode 27 Device Hub inventory")
struct DeviceHubTests {
    @Test("parses simulated devices and excludes physical devices")
    func parsesDeviceHubJSON() throws {
        let json = #"""
        {
          "info":{"jsonVersion":5,"outcome":"success"},
          "result":{"devices":[
            {
              "identifier":"72E4ABB7-F0A8-4C43-A3B1-2F859C586E3F",
              "properties":{
                "hardware":{"marketingName":"iPhone 18 Pro","platform":"iOS","reality":"simulated","udid":"72E4ABB7-F0A8-4C43-A3B1-2F859C586E3F"},
                "software":{"osVersionNumber":{"stringValue":"27.0"}},
                "state":{"bootState":"booted","name":"iPhone 18 Pro","visibilityClass":"simulators"}
              }
            },
            {
              "identifier":"11111111-1111-1111-1111-111111111111",
              "properties":{
                "hardware":{"marketingName":"Physical iPhone","platform":"iOS","reality":"physical","udid":"11111111-1111-1111-1111-111111111111"},
                "software":{"osVersionNumber":{"stringValue":"27.0"}},
                "state":{"bootState":"booted","name":"Physical iPhone","visibilityClass":"default"}
              }
            }
          ]}
        }
        """#.data(using: .utf8)!

        let simulators = try DeviceHubListParser.parse(json)

        #expect(simulators.count == 1)
        #expect(simulators[0].name == "iPhone 18 Pro")
        #expect(simulators[0].runtime == "iOS 27.0")
        #expect(simulators[0].state == .booted)
        #expect(simulators[0].isVisibleInDeviceHub)
    }

    @Test("Device Hub state enriches rather than duplicates CoreSimulator devices")
    func mergesInventory() {
        let id = UUID(uuidString: "72E4ABB7-F0A8-4C43-A3B1-2F859C586E3F")!
        let core = Simulator(
            id: id, name: "iPhone 18 Pro", runtime: "iOS 27.0",
            state: .shutdown, isAvailable: true
        )
        let hub = Simulator(
            id: id, name: "iPhone 18 Pro", runtime: "iOS 27.0",
            state: .booted, isAvailable: true, isVisibleInDeviceHub: true
        )

        let merged = SimulatorInventoryMerger.merge(coreSimulator: [core], deviceHub: [hub])

        #expect(merged.count == 1)
        #expect(merged[0].state == .booted)
        #expect(merged[0].isVisibleInDeviceHub)
    }

    @Test("keeps a Device Hub-only simulator when CoreSimulator is unavailable")
    func keepsDeviceHubOnlyDevice() {
        let hub = Simulator(
            id: UUID(), name: "iPhone 18 Pro", runtime: "iOS 27.0",
            state: .booted, isAvailable: true, isVisibleInDeviceHub: true
        )
        #expect(SimulatorInventoryMerger.merge(coreSimulator: [], deviceHub: [hub]) == [hub])
    }
}
