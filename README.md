# SimBridge

SimBridge is an experimental native macOS bridge for connecting Mac hardware to iOS Simulator apps. It supports the Xcode 27 simulator inventory used by Device Hub, discovers Mac cameras and Bluetooth availability, manages an isolated session for each booted simulator, and includes simulator-only AVFoundation and CoreBluetooth compatibility engines.

> Camera and Bluetooth LE injection are supported for simulator apps without project source changes. These are experimental development tools; final hardware validation should still use a physical iPhone or iPad. See [the architecture](docs/architecture.md).

## Requirements

- macOS 14 or newer
- Xcode 27 with at least one iOS Simulator runtime (older versions continue to work through `simctl`)
- Swift 6 toolchain
- CMake 3.24 or newer (for the BLE simulator interposer)

## Run from source

```sh
swift run SimBridge
```

Build a standalone ad-hoc signed application:

```sh
./scripts/build-app.sh
open dist/SimBridge.app
```

Camera capture requires the packaged application because macOS privacy authorization uses its bundle identifier and `NSCameraUsageDescription`. In SimBridge, choose a camera and click **Connect Camera** to verify the host preview. To make the camera appear inside simulator apps, click **Enable Simulator Feed**. On first use, complete the camera engine's short setup and choose **Camera** from its menu-bar panel. No SDK or source-code change is required in the simulator app. Disabling the feed or quitting the helper removes its simulator environment and LLDB hooks.

The camera engine is built from the MIT-licensed [FauxCam](https://github.com/mkemalgokce/fauxcam) project at pinned commit `aaa152ed0c07f79dff14945bcd38ddb25dbe5ed9`. Its license is included in the application bundle.

For Bluetooth LE, click **Enable Simulator BLE** and approve the macOS Bluetooth prompt. The bundled helper automatically arms every booted iOS simulator. Completely terminate and relaunch the simulator app after enabling the feed; its existing `CBCentralManager` and `CBPeripheral` calls then use the Mac radio for scanning, connection, GATT reads/writes, and notifications. The BLE engine is built from Apache-2.0-licensed [SimBLE](https://github.com/nirapod-labs/simble) v1.1.0 at pinned commit `e052a3510f32055553ed3621134403f74675bf5a`; its license and notice are included in the application bundle.

## Xcode 27 and Device Hub

Simulator discovery merges two public command-line sources:

- `simctl` supplies the complete installed simulator inventory.
- Xcode 27 `devicectl` supplies the active Device Hub/CoreDevice view.

If either service is temporarily unavailable, SimBridge uses the other. A **Device Hub** badge marks simulators confirmed by CoreDevice. The active Xcode selected by `xcode-select` determines which runtimes appear.

Verify discovery without opening the app:

```sh
swift run simbridge-diagnose
swift run simbridge-diagnose --json
```

## Test

```sh
./scripts/test.sh
```

## Roadmap

1. Integrate camera-engine onboarding directly into the main SimBridge window.
2. Surface camera and BLE helper health directly in the main SimBridge window.
3. Add controlled app launching and per-app compatibility reporting.
4. Add multi-simulator radio resource arbitration and richer traffic diagnostics.
5. Extend automated live-hardware coverage across supported Xcode/Simulator releases.

Bluetooth Classic is not implied by BLE support. Runtime injection remains experimental and compatibility will vary by Xcode version, simulator runtime, framework, and app security configuration.
