import AppKit
import Combine
import Foundation

public enum SimulatorCameraInjectionState: Equatable, Sendable {
    case unavailable
    case stopped
    case starting
    case running
    case failed(String)

    public var label: String {
        switch self {
        case .unavailable: "Camera injection helper is not bundled"
        case .stopped: "Simulator feed disabled"
        case .starting: "Starting simulator feed…"
        case .running: "Simulator feed enabled"
        case .failed(let message): "Simulator feed failed: \(message)"
        }
    }
}

public enum SimulatorCameraInjectionError: LocalizedError, Sendable {
    case helperMissing
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .helperMissing:
            "The simulator camera helper is missing. Rebuild SimBridge with ./scripts/build-app.sh."
        case .launchFailed(let message):
            "The simulator camera helper could not start: \(message)"
        }
    }
}

/// Supervises the bundled, MIT-licensed camera injection helper. The helper owns the simulator
/// launch-environment and LLDB hooks and removes its bounded changes during graceful termination.
@MainActor
public final class SimulatorCameraInjectionController: ObservableObject {
    @Published public private(set) var state: SimulatorCameraInjectionState
    public static let helperBundleIdentifier = "com.fauxcam.app"

    private let workspace: NSWorkspace
    private var observers: [NSObjectProtocol] = []

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        state = Self.helperURL == nil ? .unavailable : .stopped
        refresh()
        let center = workspace.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } })
    }

    isolated deinit {
        let center = workspace.notificationCenter
        observers.forEach(center.removeObserver)
    }

    public func start() async throws {
        guard let helperURL = Self.helperURL else {
            state = .unavailable
            throw SimulatorCameraInjectionError.helperMissing
        }
        state = .starting
        do {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.addsToRecentItems = false
            _ = try await workspace.openApplication(at: helperURL, configuration: configuration)
            state = .running
        } catch {
            state = .failed(error.localizedDescription)
            throw SimulatorCameraInjectionError.launchFailed(error.localizedDescription)
        }
    }

    public func stop() {
        guard let application = runningApplication else {
            state = Self.helperURL == nil ? .unavailable : .stopped
            return
        }
        if application.terminate() { state = .stopped }
        else { state = .failed("The helper did not accept a graceful termination request.") }
    }

    public func refresh() {
        guard Self.helperURL != nil else { state = .unavailable; return }
        state = runningApplication == nil ? .stopped : .running
    }

    private var runningApplication: NSRunningApplication? {
        workspace.runningApplications.first { $0.bundleIdentifier == Self.helperBundleIdentifier }
    }

    private static var helperURL: URL? {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/SimBridgeCamera.app", isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
