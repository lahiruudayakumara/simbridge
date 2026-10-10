# Architecture

SimBridge 0.1 is an experimental macOS hardware bridge for iOS Simulator.

```text
SwiftUI app
  ├─ SimctlSimulatorDiscovery ── xcrun simctl + Xcode 27 devicectl
  ├─ HardwareCatalog ────────── CoreBluetooth + AVFoundation
  ├─ Camera helper ────────── capture + Unix sockets + bounded LLDB injection
  │                                   └─ simulator-only AVFoundation compatibility dylib
  ├─ BLE helper ───────────── CoreBluetooth + authenticated loopback transport
  │                                   └─ simulator-only CoreBluetooth interposer
  └─ BridgeSessionRegistry ──── per-simulator JSON manifests
```

## Current milestone

- Merges the complete CoreSimulator inventory with Xcode 27's Device Hub/CoreDevice inventory and prioritizes booted devices.
- Discovers Mac cameras, requests macOS camera authorization, opens a real AVFoundation capture session, and displays a live preview.
- Packages an isolated camera helper that streams frames and injects a simulator-only AVFoundation compatibility library into apps launched on booted simulators.
- Packages an isolated BLE helper that drives the Mac radio, automatically arms booted simulators, and proxies central/peripheral CoreBluetooth operations over an authenticated loopback channel.
- Creates isolated bridge-session manifests keyed by simulator UDID.
- Presents explicit status, validation, activity logs, and multi-simulator session state.
- Packages as an ad-hoc signed `.app` with camera and Bluetooth usage descriptions.

The main-window camera preview proves that AVFoundation can capture from the selected Mac device. **Enable Simulator Feed** launches the bundled camera helper, which owns the camera data plane, Unix sockets, simulator launch environment, and bounded LLDB hooks. **Enable Simulator BLE** launches the BLE helper, which owns the Mac CoreBluetooth managers, an authenticated loopback listener, and its CoreBluetooth interposer. Both helpers compose `DYLD_INSERT_LIBRARIES` and remove only their own entries during graceful termination, so camera and BLE can run together. The `endpoint` in the regular session manifest is retained for future SimBridge-native transports and is not used by either helper.

## Compatibility boundary

Apple does not publish arbitrary camera or Bluetooth passthrough APIs for iOS Simulator. The helpers therefore intercept selected Objective-C AVFoundation and CoreBluetooth entry points and forward operations to macOS processes. These are experimental compatibility layers, pinned and tested against Xcode 27, and may need updates for future Simulator runtimes. They affect apps launched while feeds are enabled; already-running apps should be terminated and relaunched.
