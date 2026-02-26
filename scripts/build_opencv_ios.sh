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

OPENCV_VERSION="4.10.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
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
log "Using $PARALLEL_JOBS parallel jobs"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# Step 2: Clone OpenCV
# ──────────────────────────────────────────────────────────────────────────────
if [ -d "$OPENCV_SRC" ]; then
    if [ ! -f "${OPENCV_SRC}/platforms/apple/build_xcframework.py" ]; then
        warn "Existing OpenCV source appears incomplete, removing..."
        rm -rf "$OPENCV_SRC"
    else
        log "Using existing OpenCV source at $OPENCV_SRC"
    fi
fi

if [ ! -d "$OPENCV_SRC" ]; then
    log "Cloning OpenCV ${OPENCV_VERSION}..."
    git clone --depth 1 --branch "${OPENCV_VERSION}" \
        https://github.com/opencv/opencv.git "$OPENCV_SRC"
fi

[ -f "${OPENCV_SRC}/platforms/apple/build_xcframework.py" ] \
    || err "build_xcframework.py not found — clone may have failed"

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
# Step 3b: Fix dangling Modules symlinks left by --without objc
#
# When objc is excluded, the build creates a versioned framework with a
# Modules -> Versions/Current/Modules symlink but never populates the
# target directory. This causes cp -r and zip -r to fail when they try
# to follow the dangling symlink. We remove the dangling symlinks and
# recreate proper module maps so the framework is importable in Xcode.
# ──────────────────────────────────────────────────────────────────────────────
log "Fixing module maps in xcframework..."
XCFRAMEWORK=$(find "$BUILD_OUT" -name "opencv2.xcframework" -type d | head -1)
[ -z "$XCFRAMEWORK" ] && err "opencv2.xcframework not found — check ${WORK_DIR}/build.log"

find "$XCFRAMEWORK" -name "opencv2.framework" -type d | while read -r fw; do
    # Remove any dangling Modules symlinks
    if [ -L "${fw}/Modules" ] && [ ! -e "${fw}/Modules" ]; then
        rm "${fw}/Modules"
        echo "  ✓ Removed dangling Modules symlink in $fw"
    fi

    # Determine the real content directory (versioned or flat layout)
    if [ -d "${fw}/Versions/A/Headers" ]; then
        content_dir="${fw}/Versions/A"
    else
        content_dir="${fw}"
    fi

    # Create module map if missing
    if [ ! -d "${content_dir}/Modules" ]; then
        mkdir -p "${content_dir}/Modules"
        cat > "${content_dir}/Modules/module.modulemap" <<'EOF'
framework module opencv2 {
    header "opencv2.h"
    export *
}
EOF
        echo "  ✓ Created Modules/module.modulemap in ${content_dir}"
    fi

    # For versioned layout, ensure top-level Modules symlink exists
    if [ -d "${fw}/Versions" ] && [ ! -e "${fw}/Modules" ]; then
        ln -s "Versions/Current/Modules" "${fw}/Modules"
        echo "  ✓ Created Modules symlink in $fw"
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: Copy XCFramework to output
# ──────────────────────────────────────────────────────────────────────────────
log "Found XCFramework at: $XCFRAMEWORK"

echo "  Actual slices:"
ls "${XCFRAMEWORK}/" | grep -v "Info.plist" | while read -r s; do echo "    - $s"; done

rm -rf "${OUTPUT_DIR}/opencv2.xcframework"
cp -a "$XCFRAMEWORK" "$OUTPUT_DIR/"

# ──────────────────────────────────────────────────────────────────────────────
# Step 5: Zip for GitHub release
# ──────────────────────────────────────────────────────────────────────────────
log "Creating zip for GitHub release..."
cd "$OUTPUT_DIR"
rm -f opencv2.xcframework.zip
zip -ry opencv2.xcframework.zip opencv2.xcframework

CHECKSUM=$(swift package compute-checksum opencv2.xcframework.zip 2>/dev/null \
    || shasum -a 256 opencv2.xcframework.zip | awk '{print $1}')

echo "$CHECKSUM" > opencv2.xcframework.zip.sha256
log "Checksum (save this for the podspec): $CHECKSUM"

log "Done!"
echo ""
echo "Artifacts in ${OUTPUT_DIR}:"
echo "  opencv2.xcframework.zip"
echo "  opencv2.xcframework.zip.sha256"