import Foundation
import SimBridgeCore
import SimBridgeHardware

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var simulators: [Simulator] = []
    @Published var selectedSimulatorID: UUID?
    @Published var bluetoothEnabled = true
    @Published var cameraEnabled = true
    @Published var selectedCameraID: String?
    @Published private(set) var sessions: [UUID: BridgeSession] = [:]
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?
    @Published private(set) var activity: [String] = []

    let hardware = HardwareCatalog()
    private let discovery: any SimulatorDiscovering
    private let registry: BridgeSessionRegistry

    init(discovery: any SimulatorDiscovering = SimctlSimulatorDiscovery(), registry: BridgeSessionRegistry = BridgeSessionRegistry()) {
        self.discovery = discovery
        self.registry = registry
    }

    var selectedSimulator: Simulator? { simulators.first { $0.id == selectedSimulatorID } }
    var selectedSession: BridgeSession? {
        guard let selectedSimulatorID else { return nil }
        return sessions[selectedSimulatorID]
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            simulators = try await discovery.discover()
            if selectedSimulator == nil {
                selectedSimulatorID = simulators.first(where: { $0.state == .booted })?.id ?? simulators.first?.id
            }
            if selectedCameraID == nil { selectedCameraID = hardware.cameras.first?.id }
            log("Found \(simulators.count) available simulator\(simulators.count == 1 ? "" : "s").")
        } catch {
            errorMessage = error.localizedDescription
            log("Simulator discovery failed: \(error.localizedDescription)")
        }
    }

    func toggleBridge() async {
        guard let simulator = selectedSimulator else { return }
        do {
            if selectedSession?.status == .running {
                await registry.stop(simulatorID: simulator.id)
                sessions.removeValue(forKey: simulator.id)
                if sessions.isEmpty {
                    hardware.cameraCapture.stop()
                    hardware.simulatorBluetooth.stop()
                }
                log("Stopped bridge for \(simulator.name).")
            } else {
                if bluetoothEnabled {
                    try await hardware.simulatorBluetooth.start()
                    log("Simulator BLE engine opened and is arming booted simulators.")
                }
                if cameraEnabled {
                    try await hardware.cameraCapture.start(deviceID: selectedCameraID)
                    log("Camera connected: \(selectedCameraName).")
                }
                let options = BridgeOptions(
                    bluetoothEnabled: bluetoothEnabled, cameraEnabled: cameraEnabled, cameraID: selectedCameraID
                )
                let session = try await registry.start(simulator: simulator, options: options)
                sessions[simulator.id] = session
                log("Started control session for \(simulator.name) at \(session.endpoint).")
            }
        } catch {
            errorMessage = error.localizedDescription
            log("Bridge could not start: \(error.localizedDescription)")
        }
    }

    func toggleCameraConnection() async {
        if hardware.cameraCapture.state == .connected {
            hardware.cameraCapture.stop()
            log("Camera disconnected.")
            return
        }
        do {
            try await hardware.cameraCapture.start(deviceID: selectedCameraID)
            log("Camera connected: \(selectedCameraName).")
        } catch {
            errorMessage = error.localizedDescription
            log("Camera connection failed: \(error.localizedDescription)")
        }
    }

    func toggleSimulatorCamera() async {
        if hardware.simulatorCamera.state == .running {
            hardware.simulatorCamera.stop()
            log("Simulator camera injection disabled and cleanup requested.")
            return
        }
        do {
            hardware.cameraCapture.stop()
            try await hardware.simulatorCamera.start()
            log("Simulator camera engine opened. Complete its one-time setup and select Camera.")
        } catch {
            errorMessage = error.localizedDescription
            log("Simulator camera injection failed: \(error.localizedDescription)")
        }
    }

    func toggleSimulatorBluetooth() async {
        if hardware.simulatorBluetooth.state == .running {
            hardware.simulatorBluetooth.stop()
            log("Simulator BLE injection disabled and cleanup requested.")
            return
        }
        do {
            try await hardware.simulatorBluetooth.start()
            log("Simulator BLE engine opened. Approve Bluetooth access if macOS asks, then relaunch the simulator app.")
        } catch {
            errorMessage = error.localizedDescription
            log("Simulator BLE injection failed: \(error.localizedDescription)")
        }
    }

    private var selectedCameraName: String {
        hardware.cameras.first { $0.id == selectedCameraID }?.name ?? "selected camera"
    }

    private func log(_ message: String) {
        let time = Date.now.formatted(date: .omitted, time: .standard)
        activity.insert("[\(time)] \(message)", at: 0)
        activity = Array(activity.prefix(100))
    }
}
