#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIGURATION=${CONFIGURATION:-release}
APP_DIR="$ROOT_DIR/dist/SimBridge.app"
CONTENTS="$APP_DIR/Contents"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"
BIN_DIR=$(swift build -c "$CONFIGURATION" --show-bin-path)
"$ROOT_DIR/scripts/build-camera-helper.sh"
"$ROOT_DIR/scripts/build-ble-helper.sh"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources/ThirdPartyNotices" "$CONTENTS/Helpers"
cp "$BIN_DIR/SimBridge" "$CONTENTS/MacOS/SimBridge"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp -R "$ROOT_DIR/.build/camera-injection/SimBridgeCamera.app" "$CONTENTS/Helpers/SimBridgeCamera.app"
cp -R "$ROOT_DIR/.build/ble-injection/SimBLE.app" "$CONTENTS/Helpers/SimBLE.app"
cp "$ROOT_DIR/Resources/FauxCam-LICENSE" "$CONTENTS/Resources/ThirdPartyNotices/FauxCam-LICENSE.txt"
cp "$ROOT_DIR/.build/ble-injection-src/LICENSE" "$CONTENTS/Resources/ThirdPartyNotices/SimBLE-LICENSE.txt"
cp "$ROOT_DIR/.build/ble-injection-src/NOTICE" "$CONTENTS/Resources/ThirdPartyNotices/SimBLE-NOTICE.txt"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built $APP_DIR"
