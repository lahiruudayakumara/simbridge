import Foundation
import Testing
@testable import SimBridgeCore

@Suite("simctl device parsing")
struct SimulatorListParserTests {
    @Test("parses, filters, and puts booted devices first")
    func parsesDeviceList() throws {
        let json = #"""
        {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-2":[
          {"name":"iPhone 16","udid":"00000000-0000-0000-0000-000000000001","state":"Shutdown","isAvailable":true},
          {"name":"iPad Pro","udid":"00000000-0000-0000-0000-000000000002","state":"Booted","isAvailable":true},
          {"name":"Old Phone","udid":"00000000-0000-0000-0000-000000000003","state":"Shutdown","isAvailable":false}
        ]}}
        """#.data(using: .utf8)!
        let devices = try SimulatorListParser.parse(json)
        #expect(devices.count == 2)
        #expect(devices[0].name == "iPad Pro")
        #expect(devices[0].runtime == "iOS 18.2")
        #expect(devices[0].state == .booted)
    }

    @Test("unknown states remain representable")
    func unknownState() throws {
        let json = #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-19-0":[{"name":"Future Phone","udid":"00000000-0000-0000-0000-000000000004","state":"Pausing"}]}}"#.data(using: .utf8)!
        let device = try #require(SimulatorListParser.parse(json).first)
        #expect(device.state == .unknown)
        #expect(device.isAvailable)
    }
}
