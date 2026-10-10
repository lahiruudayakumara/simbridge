import AppKit
import SimBridgeCore
import SimBridgeHardware
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView { simulatorList } detail: { dashboard }
            .frame(minWidth: 920, minHeight: 610)
            .task { await model.refresh() }
            .alert("SimBridge", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "Unknown error") }
    }

    private var simulatorList: some View {
        List(selection: $model.selectedSimulatorID) {
            Section("Simulators") {
                ForEach(model.simulators) { simulator in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(simulator.state == .booted ? Color.green : Color.secondary.opacity(0.35))
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(simulator.name).fontWeight(.medium)
                                if simulator.isVisibleInDeviceHub {
                                    Text("Device Hub")
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(.blue.opacity(0.14), in: Capsule())
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text("\(simulator.runtime) · \(simulator.state.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(simulator.id)
                }
            }
        }
        .navigationTitle("SimBridge")
        .toolbar {
            ToolbarItem {
                Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(model.isRefreshing).help("Refresh simulators")
            }
        }
        .overlay {
            if model.simulators.isEmpty && !model.isRefreshing {
                ContentUnavailableView(
                    "No Simulators", systemImage: "iphone.slash",
                    description: Text("Install an iOS runtime in Xcode or boot a Simulator, then refresh.")
                )
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    @ViewBuilder private var dashboard: some View {
        if let simulator = model.selectedSimulator {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(for: simulator)
                    limitationBanner
                    hardwareCard
                    sessionCard(for: simulator)
                    activityCard
                }
                .padding(28).frame(maxWidth: 850, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            ContentUnavailableView("Select a Simulator", systemImage: "iphone")
        }
    }

    private func header(for simulator: Simulator) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(simulator.name).font(.largeTitle.bold())
                Text("\(simulator.runtime) · \(simulator.state.rawValue)").foregroundStyle(.secondary)
            }
            Spacer()
            Label(
                model.selectedSession?.status == .running ? "Bridge active" : "Not connected",
                systemImage: model.selectedSession?.status == .running ? "bolt.horizontal.circle.fill" : "bolt.slash.circle"
            )
            .foregroundStyle(model.selectedSession?.status == .running ? .green : .secondary)
        }
    }

    private var limitationBanner: some View {
        Label {
            Text("Camera and Bluetooth LE passthrough are available through bundled simulator-only compatibility engines. Relaunch simulator apps after enabling a feed.")
                .font(.callout)
        } icon: { Image(systemName: "wrench.and.screwdriver.fill") }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var hardwareCard: some View {
        GroupBox("Hardware bridges") {
            VStack(spacing: 0) {
                hardwareRow(title: "Bluetooth LE", subtitle: "Mac Bluetooth controller · \(model.hardware.bluetoothState)", icon: "antenna.radiowaves.left.and.right", isOn: $model.bluetoothEnabled)
                if model.bluetoothEnabled {
                    SimulatorBluetoothPanel(
                        injector: model.hardware.simulatorBluetooth,
                        toggleAction: { Task { await model.toggleSimulatorBluetooth() } }
                    )
                    .padding(.top, 12)
                }
                Divider().padding(.vertical, 12)
                hardwareRow(title: "Camera", subtitle: cameraSubtitle, icon: "camera.fill", isOn: $model.cameraEnabled)
                if model.cameraEnabled && !model.hardware.cameras.isEmpty {
                    Picker("Camera source", selection: $model.selectedCameraID) {
                        ForEach(model.hardware.cameras) { camera in Text(camera.name).tag(Optional(camera.id)) }
                    }
                    .padding(.top, 12)
                    CameraConnectionPanel(
                        capture: model.hardware.cameraCapture,
                        connectAction: { Task { await model.toggleCameraConnection() } }
                    )
                    .padding(.top, 12)
                    .onChange(of: model.selectedCameraID) { _, _ in
                        if model.hardware.cameraCapture.state == .connected {
                            Task { await model.toggleCameraConnection(); await model.toggleCameraConnection() }
                        }
                    }
                    Divider().padding(.vertical, 12)
                    SimulatorCameraPanel(
                        injector: model.hardware.simulatorCamera,
                        toggleAction: { Task { await model.toggleSimulatorCamera() } }
                    )
                }
            }
            .padding(10)
        }
    }

    private var cameraSubtitle: String {
        let connection = model.hardware.cameraCapture.state
        if connection != .idle { return connection.label }
        let count = model.hardware.cameras.count
        return count == 0 ? "No camera detected" : "\(count) camera source\(count == 1 ? "" : "s") available"
    }

    private func hardwareRow(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).frame(width: 30).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
    }

    private func sessionCard(for simulator: Simulator) -> some View {
        GroupBox("Session") {
            VStack(alignment: .leading, spacing: 14) {
                if let session = model.selectedSession {
                    LabeledContent("Control endpoint", value: session.endpoint).textSelection(.enabled)
                    LabeledContent("Started", value: session.startedAt.formatted())
                } else {
                    Text(simulator.state == .booted ? "Ready to create an isolated control session for this simulator." : "Boot this simulator before starting a bridge.")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button { Task { await model.toggleBridge() } } label: {
                        Label(model.selectedSession == nil ? "Start Bridge" : "Stop Bridge", systemImage: model.selectedSession == nil ? "play.fill" : "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(model.selectedSession == nil ? .accentColor : .red)
                    .disabled(simulator.state != .booted || (!model.bluetoothEnabled && !model.cameraEnabled))
                }
            }
            .padding(10)
        }
    }

    private var activityCard: some View {
        GroupBox("Activity") {
            if model.activity.isEmpty {
                Text("Activity will appear here.").foregroundStyle(.secondary).padding(10)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(model.activity.prefix(8).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
        }
    }
}

private struct SimulatorBluetoothPanel: View {
    @ObservedObject var injector: SimulatorBluetoothInjectionController
    let toggleAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(injector.state.label, systemImage: injector.state == .running ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right.slash")
                    .font(.caption)
                    .foregroundStyle(injector.state == .running ? .green : .secondary)
                Spacer()
                Button(injector.state == .running ? "Disable Simulator BLE" : "Enable Simulator BLE", action: toggleAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(injector.state == .unavailable || injector.state == .starting)
            }
            Text("Uses the Mac Bluetooth radio for simulator scanning, connections, GATT reads and writes, and notifications. Approve Bluetooth access on first use, then fully relaunch the simulator app.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CameraConnectionPanel: View {
    @ObservedObject var capture: CameraCaptureController
    let connectAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(capture.state.label, systemImage: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                Spacer()
                if capture.state == .permissionDenied {
                    Button("Open Camera Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                    }
                }
                Button(capture.state == .connected ? "Disconnect" : "Connect Camera", action: connectAction)
                    .disabled(capture.state == .connecting || capture.state == .requestingPermission)
            }
            if capture.state == .connected {
                CameraPreviewView(session: capture.session)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(.black, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Live camera preview")
            }
        }
    }

    private var statusIcon: String {
        switch capture.state {
        case .connected: "checkmark.circle.fill"
        case .permissionDenied, .noCamera, .failed: "exclamationmark.triangle.fill"
        case .connecting, .requestingPermission: "hourglass"
        case .idle: "camera"
        }
    }

    private var statusColor: Color {
        switch capture.state {
        case .connected: .green
        case .permissionDenied, .noCamera, .failed: .red
        default: .secondary
        }
    }
}

private struct SimulatorCameraPanel: View {
    @ObservedObject var injector: SimulatorCameraInjectionController
    let toggleAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(injector.state.label, systemImage: injector.state == .running ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                    .font(.caption)
                    .foregroundStyle(injector.state == .running ? .green : .secondary)
                Spacer()
                Button(injector.state == .running ? "Disable Simulator Feed" : "Enable Simulator Feed", action: toggleAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(injector.state == .unavailable || injector.state == .starting)
            }
            Text("The bundled camera engine injects AVFoundation support into apps launched on booted simulators. On first use, click Get Started and choose Camera in its menu-bar panel. Quit or disable it to remove the simulator environment and LLDB hooks.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
