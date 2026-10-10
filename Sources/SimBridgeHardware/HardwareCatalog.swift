import AVFoundation
import Combine
import CoreBluetooth
import Foundation

public struct CameraSource: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

@MainActor
public final class HardwareCatalog: NSObject, ObservableObject {
    @Published public private(set) var cameras: [CameraSource] = []
    @Published public private(set) var bluetoothState = "Checking…"
    public let cameraCapture = CameraCaptureController()
    public let simulatorCamera = SimulatorCameraInjectionController()
    public let simulatorBluetooth = SimulatorBluetoothInjectionController()
    private var centralManager: CBCentralManager?

    public override init() {
        super.init()
        refreshCameras()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    public func refreshCameras() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified
        )
        cameras = session.devices.map { CameraSource(id: $0.uniqueID, name: $0.localizedName) }
    }
}

extension HardwareCatalog: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let label: String
        switch central.state {
        case .poweredOn: label = "Available"
        case .poweredOff: label = "Powered off"
        case .unauthorized: label = "Permission required"
        case .unsupported: label = "Unsupported"
        case .resetting: label = "Resetting…"
        case .unknown: label = "Checking…"
        @unknown default: label = "Unknown"
        }
        Task { @MainActor [weak self] in self?.bluetoothState = label }
    }
}
