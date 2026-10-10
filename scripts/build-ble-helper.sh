#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/.build/ble-injection-src"
OUTPUT_DIR="$ROOT_DIR/.build/ble-injection"
SIMBLE_REPOSITORY="https://github.com/nirapod-labs/simble.git"
SIMBLE_COMMIT="e052a3510f32055553ed3621134403f74675bf5a"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    rm -rf "$SOURCE_DIR"
    git clone "$SIMBLE_REPOSITORY" "$SOURCE_DIR"
fi

if ! git -C "$SOURCE_DIR" cat-file -e "$SIMBLE_COMMIT^{commit}" 2>/dev/null; then
    git -C "$SOURCE_DIR" fetch origin "$SIMBLE_COMMIT"
fi
git -C "$SOURCE_DIR" checkout --detach --force "$SIMBLE_COMMIT"

(cd "$SOURCE_DIR" && SIGN_ID=- bash scripts/build-menubar-app.sh)

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$SOURCE_DIR/dist/SimBLE.app" "$OUTPUT_DIR/SimBLE.app"
codesign --verify --deep --strict "$OUTPUT_DIR/SimBLE.app"
xcrun otool -l "$OUTPUT_DIR/SimBLE.app/Contents/Resources/simble-interpose.dylib" \
    | awk '/LC_BUILD_VERSION/{f=1} f&&/ platform /{if ($2 == 7) ok=1; exit} END{exit !ok}'

echo "Built $OUTPUT_DIR/SimBLE.app from SimBLE $SIMBLE_COMMIT"
