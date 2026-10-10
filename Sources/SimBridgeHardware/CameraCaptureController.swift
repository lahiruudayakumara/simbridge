@preconcurrency import AVFoundation
import Combine
import Foundation

public enum CameraConnectionState: Equatable, Sendable {
    case idle
    case requestingPermission
    case connecting
    case connected
    case permissionDenied
    case noCamera
    case failed(String)

    public var label: String {
        switch self {
        case .idle: "Not connected"
        case .requestingPermission: "Requesting permission…"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .permissionDenied: "Camera permission denied"
        case .noCamera: "Camera unavailable"
        case .failed(let message): "Connection failed: \(message)"
        }
    }
}

public enum CameraCaptureError: LocalizedError, Sendable {
    case permissionDenied
    case deviceUnavailable
    case inputCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Camera access is denied. Enable SimBridge in System Settings → Privacy & Security → Camera."
        case .deviceUnavailable:
            "The selected camera is no longer available."
        case .inputCreationFailed(let message):
            "The camera could not be opened: \(message)"
        }
    }
}

private final class CameraCaptureEngine: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dev.simbridge.camera.capture", qos: .userInitiated)

    func start(deviceID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    guard let device = AVCaptureDevice(uniqueID: deviceID) else {
                        throw CameraCaptureError.deviceUnavailable
                    }
                    let input: AVCaptureDeviceInput
                    do { input = try AVCaptureDeviceInput(device: device) }
                    catch { throw CameraCaptureError.inputCreationFailed(error.localizedDescription) }

                    if session.isRunning { session.stopRunning() }
                    session.beginConfiguration()
                    session.sessionPreset = .high
                    session.inputs.forEach(session.removeInput)
                    guard session.canAddInput(input) else {
                        session.commitConfiguration()
                        throw CameraCaptureError.inputCreationFailed("AVFoundation rejected the selected input.")
                    }
                    session.addInput(input)
                    session.commitConfiguration()
                    session.startRunning()
                    guard session.isRunning else {
                        throw CameraCaptureError.inputCreationFailed("The capture session did not start.")
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            session.commitConfiguration()
        }
    }
}

@MainActor
public final class CameraCaptureController: ObservableObject {
    @Published public private(set) var state: CameraConnectionState = .idle
    private let engine = CameraCaptureEngine()

    public var session: AVCaptureSession { engine.session }

    public init() {}

    public func start(deviceID: String?) async throws {
        guard let deviceID else {
            state = .noCamera
            throw CameraCaptureError.deviceUnavailable
        }

        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        if authorization == .notDetermined {
            state = .requestingPermission
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                state = .permissionDenied
                throw CameraCaptureError.permissionDenied
            }
        } else if authorization != .authorized {
            state = .permissionDenied
            throw CameraCaptureError.permissionDenied
        }

        state = .connecting
        do {
            try await engine.start(deviceID: deviceID)
            state = .connected
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    public func stop() {
        engine.stop()
        state = .idle
    }
}
