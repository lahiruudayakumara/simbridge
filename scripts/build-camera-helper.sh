#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/.build/camera-injection-src"
OUTPUT_DIR="$ROOT_DIR/.build/camera-injection"
HELPER_APP="$OUTPUT_DIR/SimBridgeCamera.app"
FAUXCAM_REPOSITORY="https://github.com/mkemalgokce/fauxcam.git"
FAUXCAM_COMMIT="aaa152ed0c07f79dff14945bcd38ddb25dbe5ed9"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    rm -rf "$SOURCE_DIR"
    git clone "$FAUXCAM_REPOSITORY" "$SOURCE_DIR"
fi

if ! git -C "$SOURCE_DIR" cat-file -e "$FAUXCAM_COMMIT^{commit}" 2>/dev/null; then
    git -C "$SOURCE_DIR" fetch origin "$FAUXCAM_COMMIT"
fi
git -C "$SOURCE_DIR" checkout --detach --force "$FAUXCAM_COMMIT"
git -C "$SOURCE_DIR" apply --check "$ROOT_DIR/Patches/fauxcam-coexistence.patch"
git -C "$SOURCE_DIR" apply "$ROOT_DIR/Patches/fauxcam-coexistence.patch"

"$SOURCE_DIR/Scripts/build-icons.sh"
"$SOURCE_DIR/Scripts/build-dylib.sh"
swift build -c release --product FauxCamApp --package-path "$SOURCE_DIR"
BIN_DIR="$(swift build -c release --product FauxCamApp --package-path "$SOURCE_DIR" --show-bin-path)"

rm -rf "$OUTPUT_DIR"
mkdir -p "$HELPER_APP/Contents/MacOS" "$HELPER_APP/Contents/Resources"
cp "$BIN_DIR/FauxCamApp" "$HELPER_APP/Contents/MacOS/FauxCam"
cp "$SOURCE_DIR/dist/libFaux.dylib" "$HELPER_APP/Contents/Resources/libFaux.dylib"
cp "$SOURCE_DIR/dist/FauxCam.icns" "$HELPER_APP/Contents/Resources/FauxCam.icns"
cp "$SOURCE_DIR/Modules/Presentation/Presentation/Resources/"*.png "$HELPER_APP/Contents/Resources/"
cp -R "$BIN_DIR/FauxCam_Presentation.bundle" "$HELPER_APP/Contents/Resources/FauxCam_Presentation.bundle"
cp "$ROOT_DIR/Resources/CameraHelper-Info.plist" "$HELPER_APP/Contents/Info.plist"
cp "$ROOT_DIR/Resources/FauxCam-LICENSE" "$HELPER_APP/Contents/Resources/LICENSE.txt"

xattr -cr "$HELPER_APP"
codesign --force --options runtime --sign - "$HELPER_APP/Contents/Resources/libFaux.dylib"
codesign --force --options runtime --entitlements "$ROOT_DIR/Resources/CameraHelper.entitlements" --sign - "$HELPER_APP"
codesign --verify --deep --strict "$HELPER_APP"
/usr/libexec/PlistBuddy -c 'Print :NSCameraUsageDescription' "$HELPER_APP/Contents/Info.plist" >/dev/null
xcrun lipo -info "$HELPER_APP/Contents/Resources/libFaux.dylib" | grep -qw arm64
xcrun lipo -info "$HELPER_APP/Contents/Resources/libFaux.dylib" | grep -qw x86_64

echo "Built $HELPER_APP from FauxCam $FAUXCAM_COMMIT"
