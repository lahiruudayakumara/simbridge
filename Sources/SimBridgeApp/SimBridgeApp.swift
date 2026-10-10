import SwiftUI

@main
struct SimBridgeApplication: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup { ContentView().environmentObject(model) }
            .windowStyle(.titleBar)
            .defaultSize(width: 1060, height: 700)

        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("SimBridge").font(.title2.bold())
                Text("Experimental hardware bridge for the iOS Simulator.")
                Text("Simulator-only camera and Bluetooth compatibility engines are included.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24).frame(width: 430)
        }
    }
}
