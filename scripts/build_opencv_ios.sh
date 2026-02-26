#!/usr/bin/env bash
#
# build_opencv_ios.sh
#
# Builds OpenCV for iOS as a static XCFramework
#   - arm64 device
#   - arm64 + x86_64 simulator
#   - SIFT, imread/imwrite, full stitching pipeline
#   - No Java bindings
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load version from version.env
VERSION_FILE="${PROJECT_ROOT}/version.env"
if [ ! -f "$VERSION_FILE" ]; then
    echo "ERR: version.env not found at $VERSION_FILE" >&2
    exit 1
fi
source "$VERSION_FILE"

# OPENCV_VERSION and RELEASE_TAG are now set from version.env

WORK_DIR="${SCRIPT_DIR}/work"
OPENCV_SRC="${WORK_DIR}/opencv-${OPENCV_VERSION}"
OUTPUT_DIR="${PROJECT_ROOT}/output"

log()  { echo -e "\n\033[1;32m>>> $*\033[0m"; }
warn() { echo -e "\n\033[1;33m!!! $*\033[0m"; }
err()  { echo -e "\n\033[1;31mERR $*\033[0m" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────
# Step 1: Check dependencies
# ──────────────────────────────────────────────────────────────────────────────
log "Checking dependencies..."
for cmd in cmake python3 git xcodebuild; do
    command -v "$cmd" &>/dev/null || err "Missing: $cmd — install via brew install $cmd"
done
xcodebuild -version &>/dev/null || err "Xcode not configured. Run: sudo xcode-select --switch /Applications/Xcode.app"

PARALLEL_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
log "Building OpenCV ${OPENCV_VERSION} (release ${RELEASE_TAG}) with $PARALLEL_JOBS parallel jobs"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# Step 2: Clone OpenCV
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -d "$OPENCV_SRC" ]; then
    log "Cloning OpenCV ${OPENCV_VERSION}..."
    git clone --depth 1 --branch "${OPENCV_VERSION}" \
        https://github.com/opencv/opencv.git "$OPENCV_SRC"
else
    log "Using existing OpenCV source at $OPENCV_SRC"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 3: Build XCFramework (device + simulator)
# ──────────────────────────────────────────────────────────────────────────────
log "Building OpenCV XCFramework for iOS (arm64 device + arm64/x86_64 simulator)..."
log "Note: This builds 3 slices and will take ~2x longer than device-only."

BUILD_OUT="${WORK_DIR}/xcframework-build"
rm -rf "$BUILD_OUT"

python3 "${OPENCV_SRC}/platforms/apple/build_xcframework.py" \
    --out "$BUILD_OUT" \
    --iphoneos_archs arm64 \
    --iphonesimulator_archs arm64,x86_64 \
    --iphoneos_deployment_target 13.0 \
    --disable-bitcode \
    --build_only_specified_archs \
    --enable_nonfree \
    --without dnn \
    --without gapi \
    --without highgui \
    --without java \
    --without js \
    --without ml \
    --without objc \
    --without objdetect \
    --without python \
    --without ts \
    --without video \
    --without world \
    2>&1 | tee "${WORK_DIR}/build.log"

# ──────────────────────────────────────────────────────────────────────────────
# Step 3b: Fix missing Modules (--without objc skips modulemap generation)
#
# The xcframework has already been assembled by build_xcframework.py at this
# point, so we patch the frameworks *inside* the xcframework bundle rather
# than the intermediate per-platform directories (which may no longer exist).
# ──────────────────────────────────────────────────────────────────────────────
XCFRAMEWORK="${BUILD_OUT}/opencv2.xcframework"
[ ! -d "$XCFRAMEWORK" ] && err "opencv2.xcframework not found at $XCFRAMEWORK — check ${WORK_DIR}/build.log"

log "Ensuring module maps exist in xcframework..."
find "$XCFRAMEWORK" -name "opencv2.framework" -type d | while read -r fw; do
    if [ ! -d "${fw}/Modules" ]; then
        mkdir -p "${fw}/Modules"
        cat > "${fw}/Modules/module.modulemap" <<'EOF'
framework module opencv2 {
    header "opencv2.h"
    export *
}
EOF
        echo "  ✓ Created Modules in $fw"
    else
        echo "  ✓ Modules already exists in $fw"
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: Verify and copy XCFramework
# ──────────────────────────────────────────────────────────────────────────────
log "Found XCFramework at: $XCFRAMEWORK"

# List actual slices present in the xcframework
echo "  Slices:"
ls "$XCFRAMEWORK" | grep -v "Info.plist" | while read -r s; do echo "    - $s"; done

rm -rf "${OUTPUT_DIR}/opencv2.xcframework"
cp -r "$XCFRAMEWORK" "$OUTPUT_DIR/"

# ──────────────────────────────────────────────────────────────────────────────
# Step 5: Zip for GitHub release
# ──────────────────────────────────────────────────────────────────────────────
log "Creating zip for GitHub release..."
cd "$OUTPUT_DIR"
rm -f opencv2.xcframework.zip
zip -r opencv2.xcframework.zip opencv2.xcframework

CHECKSUM=$(swift package compute-checksum opencv2.xcframework.zip 2>/dev/null \
    || shasum -a 256 opencv2.xcframework.zip | awk '{print $1}')

echo "$CHECKSUM" > opencv2.xcframework.zip.sha256
log "Checksum (save this for the podspec): $CHECKSUM"

log "Done!"
echo ""
echo "Artifacts in ${OUTPUT_DIR}:"
echo "  opencv2.xcframework.zip"
echo "  opencv2.xcframework.zip.sha256"
echo ""
echo "Next steps:"
echo "  1. Create GitHub release tagged '${RELEASE_TAG}'"
echo "  2. Upload opencv2.xcframework.zip as release asset"
echo "  3. Update podspec with the new checksum: $CHECKSUM"