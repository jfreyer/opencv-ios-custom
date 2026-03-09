#!/usr/bin/env bash
#
# build_opencv_ios.sh
#
# Builds OpenCV for iOS as a static XCFramework using CMake + Ninja
# (bypasses the broken Xcode generator in OpenCV's build_xcframework.py)
#
# Slices:
#   - arm64 device        (iphoneos)
#   - arm64 + x86_64 sim  (iphonesimulator, lipo'd into a fat binary)
#
# Modules: core, imgproc, imgcodecs, features2d, flann, calib3d, stitching, photo
# Includes SIFT (nonfree) and full stitching pipeline.
#
# Usage:
#   ./build_opencv_ios.sh
#   DEBUG_SYMBOLS=1 ./build_opencv_ios.sh   # include dSYMs for crash symbolication
#
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────
OPENCV_VERSION="4.10.0"
IOS_DEPLOYMENT_TARGET="13.0"

# Debug symbols: set DEBUG_SYMBOLS=1 to build with debug info and generate
# dSYM bundles for crash symbolication (e.g. Firebase Crashlytics).
DEBUG_SYMBOLS="${DEBUG_SYMBOLS:-0}"

# Modules to build (comma-separated for BUILD_LIST)
OPENCV_MODULES="core,imgproc,imgcodecs,features2d,flann,calib3d,stitching,photo"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="${SCRIPT_DIR}/work"
OPENCV_SRC="${WORK_DIR}/opencv-${OPENCV_VERSION}"
OUTPUT_DIR="${PROJECT_ROOT}/output"
DEBUG_SYMBOLS_DIR="${OUTPUT_DIR}/debug-symbols"

PARALLEL_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

# The three slices we build separately, then combine
SLICES=(
    "arm64|iphoneos"
    "arm64|iphonesimulator"
    "x86_64|iphonesimulator"
)

# Resolve build type based on debug flag
if [ "$DEBUG_SYMBOLS" = "1" ]; then
    CMAKE_BUILD_TYPE="RelWithDebInfo"
else
    CMAKE_BUILD_TYPE="Release"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────
log()  { echo -e "\n\033[1;32m>>> $*\033[0m"; }
warn() { echo -e "\n\033[1;33m!!! $*\033[0m"; }
err()  { echo -e "\n\033[1;31mERR $*\033[0m" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────
# Step 1: Check dependencies
# ──────────────────────────────────────────────────────────────────────────────
log "Checking dependencies..."
for cmd in cmake ninja python3 git xcodebuild lipo libtool dsymutil; do
    command -v "$cmd" &>/dev/null || err "Missing: $cmd"
done
xcodebuild -version &>/dev/null || err "Xcode not configured. Run: sudo xcode-select --switch /Applications/Xcode.app"

log "Using $PARALLEL_JOBS parallel jobs"
log "Build type: ${CMAKE_BUILD_TYPE}"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# Step 2: Clone OpenCV
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -d "$OPENCV_SRC" ]; then
    log "Downloading OpenCV ${OPENCV_VERSION} source..."
    TARBALL="${WORK_DIR}/opencv-${OPENCV_VERSION}.tar.gz"
    curl -L -o "$TARBALL" \
        "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz"
    tar xzf "$TARBALL" -C "$WORK_DIR"
    rm -f "$TARBALL"
fi

[ -f "${OPENCV_SRC}/CMakeLists.txt" ] || err "CMakeLists.txt not found in ${OPENCV_SRC}"

# ──────────────────────────────────────────────────────────────────────────────
# Step 3: Build each slice with CMake + Ninja
# ──────────────────────────────────────────────────────────────────────────────

# Resolve SDK paths once
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONESIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
log "iPhoneOS SDK:        $IPHONEOS_SDK"
log "iPhoneSimulator SDK: $IPHONESIMULATOR_SDK"

build_slice() {
    local ARCH="$1"
    local PLATFORM="$2"   # iphoneos or iphonesimulator

    local BUILD_DIR="${WORK_DIR}/build-${PLATFORM}-${ARCH}"
    local INSTALL_DIR="${WORK_DIR}/install-${PLATFORM}-${ARCH}"

    if [ "$PLATFORM" = "iphoneos" ]; then
        local SDK_PATH="$IPHONEOS_SDK"
        local CMAKE_SYSTEM_NAME="iOS"
    else
        local SDK_PATH="$IPHONESIMULATOR_SDK"
        local CMAKE_SYSTEM_NAME="iOS"
    fi

    # Debug symbols: extra CMake flags
    local DEBUG_CMAKE_FLAGS=()
    if [ "$DEBUG_SYMBOLS" = "1" ]; then
        DEBUG_CMAKE_FLAGS+=(
            -DCMAKE_C_FLAGS_RELWITHDEBINFO="-O2 -g -DNDEBUG"
            -DCMAKE_CXX_FLAGS_RELWITHDEBINFO="-O2 -g -DNDEBUG"
        )
    fi

    log "Configuring: ${ARCH} / ${PLATFORM} (${CMAKE_BUILD_TYPE})"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    cmake -S "$OPENCV_SRC" -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_SYSTEM_NAME="${CMAKE_SYSTEM_NAME}" \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_SYSROOT="${SDK_PATH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET}" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
        -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
        \
        -DENABLE_BITCODE=OFF \
        -DENABLE_ARC=ON \
        -DENABLE_VISIBILITY=OFF \
        \
        -DAPPLE_FRAMEWORK=ON \
        -DBUILD_LIST="${OPENCV_MODULES}" \
        \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_DOCS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_PERF_TESTS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_opencv_apps=OFF \
        -DBUILD_opencv_world=OFF \
        -DBUILD_opencv_highgui=OFF \
        -DBUILD_JAVA=OFF \
        -DBUILD_opencv_python2=OFF \
        -DBUILD_opencv_python3=OFF \
        \
        -DOPENCV_ENABLE_NONFREE=ON \
        \
        -DBUILD_ZLIB=ON \
        -DBUILD_PNG=ON \
        -DBUILD_JPEG=ON \
        -DBUILD_WEBP=ON \
        -DBUILD_TIFF=ON \
        -DBUILD_OPENJPEG=ON \
        \
        -DWITH_OPENCL=OFF \
        -DWITH_IPP=OFF \
        -DWITH_TBB=OFF \
        -DWITH_PTHREADS_PF=ON \
        \
        "${DEBUG_CMAKE_FLAGS[@]}" \
        \
        2>&1 | tee "${BUILD_DIR}/cmake_configure.log"

    log "Building: ${ARCH} / ${PLATFORM}"
    cmake --build "$BUILD_DIR" --config "${CMAKE_BUILD_TYPE}" -j "$PARALLEL_JOBS" \
        2>&1 | tee "${BUILD_DIR}/build.log"

    cmake --install "$BUILD_DIR" --config "${CMAKE_BUILD_TYPE}" \
        2>&1 | tee "${BUILD_DIR}/install.log"

    log "✓ ${ARCH} / ${PLATFORM} done"
}

for slice in "${SLICES[@]}"; do
    IFS='|' read -r ARCH PLATFORM <<< "$slice"
    build_slice "$ARCH" "$PLATFORM"
done

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: Collect static libraries and create fat simulator lib
# ──────────────────────────────────────────────────────────────────────────────
log "Collecting static libraries..."

# Each install dir has: lib/opencv4/3rdparty/*.a and lib/*.a
# We'll merge all .a files per slice into one fat .a using libtool

merge_libs() {
    local INSTALL_DIR="$1"
    local OUTPUT_LIB="$2"

    local ALL_LIBS=()
    while IFS= read -r -d '' lib; do
        ALL_LIBS+=("$lib")
    done < <(find "$INSTALL_DIR" -name "*.a" -print0)

    if [ ${#ALL_LIBS[@]} -eq 0 ]; then
        err "No .a files found in $INSTALL_DIR"
    fi

    log "  Merging ${#ALL_LIBS[@]} static libs -> $(basename "$OUTPUT_LIB")"
    libtool -static -no_warning_for_no_symbols -o "$OUTPUT_LIB" "${ALL_LIBS[@]}"
}

STAGING="${WORK_DIR}/staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"/{device-arm64,sim-arm64,sim-x86_64,sim-fat}

# Merge each slice
merge_libs "${WORK_DIR}/install-iphoneos-arm64"        "${STAGING}/device-arm64/libopencv_all.a"
merge_libs "${WORK_DIR}/install-iphonesimulator-arm64"  "${STAGING}/sim-arm64/libopencv_all.a"
merge_libs "${WORK_DIR}/install-iphonesimulator-x86_64" "${STAGING}/sim-x86_64/libopencv_all.a"

# Lipo the two simulator slices into one fat binary
log "Creating fat simulator library (arm64 + x86_64)..."
lipo -create \
    "${STAGING}/sim-arm64/libopencv_all.a" \
    "${STAGING}/sim-x86_64/libopencv_all.a" \
    -output "${STAGING}/sim-fat/libopencv_all.a"

lipo -info "${STAGING}/sim-fat/libopencv_all.a"

# ──────────────────────────────────────────────────────────────────────────────
# Step 4b: Generate dSYM bundles (if debug symbols enabled)
# ──────────────────────────────────────────────────────────────────────────────
if [ "$DEBUG_SYMBOLS" = "1" ]; then
    log "Generating dSYM bundles..."
    rm -rf "$DEBUG_SYMBOLS_DIR"
    mkdir -p "$DEBUG_SYMBOLS_DIR"

    # Generate dSYMs from each merged static lib that contains debug info
    for slice_dir in device-arm64 sim-fat; do
        LIB="${STAGING}/${slice_dir}/libopencv_all.a"
        DSYM_OUT="${DEBUG_SYMBOLS_DIR}/${slice_dir}"
        mkdir -p "$DSYM_OUT"

        # Copy the unstripped .a (contains DWARF debug info)
        cp "$LIB" "$DSYM_OUT/libopencv_all_unstripped.a"

        # Also extract and keep individual .o debug info via dsymutil
        # For static libs, the debug info lives in the .a itself, so we
        # keep the full unstripped archive for symbolication tools
        log "  Saved unstripped lib: ${slice_dir}/libopencv_all_unstripped.a"
    done

    # Also save per-slice unstripped libs before the fat merge
    for slice in "${SLICES[@]}"; do
        IFS='|' read -r ARCH PLATFORM <<< "$slice"
        SLICE_DIR="${DEBUG_SYMBOLS_DIR}/${PLATFORM}-${ARCH}"
        mkdir -p "$SLICE_DIR"
        cp "${STAGING}/${PLATFORM}-${ARCH}/libopencv_all.a" \
            "${SLICE_DIR}/libopencv_all_unstripped.a" 2>/dev/null || true
    done

    # Strip the staging libs that will go into the XCFramework
    log "Stripping debug info from XCFramework libraries..."
    for lib in "${STAGING}/device-arm64/libopencv_all.a" \
               "${STAGING}/sim-fat/libopencv_all.a"; do
        strip -S "$lib"
        log "  Stripped: $(basename "$(dirname "$lib")")/$(basename "$lib")"
    done

    SYMBOLS_SIZE=$(du -sh "$DEBUG_SYMBOLS_DIR" 2>/dev/null | cut -f1)
    log "Debug symbols saved to: ${DEBUG_SYMBOLS_DIR} (${SYMBOLS_SIZE})"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Step 5: Build the XCFramework
# ──────────────────────────────────────────────────────────────────────────────
log "Assembling XCFramework..."

# Collect headers from any install dir (they're the same across all slices)
HEADER_SRC="${WORK_DIR}/install-iphoneos-arm64/include/opencv4"
[ -d "$HEADER_SRC" ] || HEADER_SRC="${WORK_DIR}/install-iphoneos-arm64/include"
[ -d "$HEADER_SRC" ] || err "Cannot find installed headers"

# Copy headers to staging
HEADERS_DIR="${STAGING}/headers"
rm -rf "$HEADERS_DIR"
cp -a "$HEADER_SRC" "$HEADERS_DIR"

XCFRAMEWORK="${OUTPUT_DIR}/opencv2.xcframework"
rm -rf "$XCFRAMEWORK"

xcodebuild -create-xcframework \
    -library "${STAGING}/device-arm64/libopencv_all.a" \
    -headers "$HEADERS_DIR" \
    -library "${STAGING}/sim-fat/libopencv_all.a" \
    -headers "$HEADERS_DIR" \
    -output "$XCFRAMEWORK"

log "XCFramework created at: $XCFRAMEWORK"

# Show contents
echo "  Slices:"
ls "$XCFRAMEWORK" | grep -v Info.plist | while read -r s; do echo "    - $s"; done

# ──────────────────────────────────────────────────────────────────────────────
# Step 6: Create module map (for Swift / Clang module imports)
# ──────────────────────────────────────────────────────────────────────────────
log "Adding module maps..."
find "$XCFRAMEWORK" -type d -name "Headers" | while read -r hdir; do
    MODULES_DIR="$(dirname "$hdir")/Modules"
    mkdir -p "$MODULES_DIR"
    cat > "${MODULES_DIR}/module.modulemap" <<'EOF'
module opencv2 {
    header "opencv2/opencv.hpp"
    export *
}
EOF
    echo "  ✓ $(dirname "$hdir" | sed "s|$XCFRAMEWORK/||")"
done

# ──────────────────────────────────────────────────────────────────────────────
# Step 7: Zip for distribution
# ──────────────────────────────────────────────────────────────────────────────
log "Creating zip for distribution..."
cd "$OUTPUT_DIR"
rm -f opencv2.xcframework.zip
zip -ry opencv2.xcframework.zip opencv2.xcframework

CHECKSUM=$(swift package compute-checksum opencv2.xcframework.zip 2>/dev/null \
    || shasum -a 256 opencv2.xcframework.zip | awk '{print $1}')

echo "$CHECKSUM" > opencv2.xcframework.zip.sha256
log "Checksum: $CHECKSUM"

# Zip debug symbols too if present
if [ "$DEBUG_SYMBOLS" = "1" ] && [ -d "$DEBUG_SYMBOLS_DIR" ]; then
    log "Zipping debug symbols..."
    cd "$OUTPUT_DIR"
    rm -f debug-symbols.zip
    zip -ry debug-symbols.zip debug-symbols
    log "Debug symbols zip: ${OUTPUT_DIR}/debug-symbols.zip"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────────────────────────────────────
log "Build complete!"
echo ""
echo "Artifacts in ${OUTPUT_DIR}:"
echo "  opencv2.xcframework/"
echo "  opencv2.xcframework.zip"
echo "  opencv2.xcframework.zip.sha256"
if [ "$DEBUG_SYMBOLS" = "1" ]; then
    echo "  debug-symbols/"
    echo "  debug-symbols.zip"
    echo ""
    echo "Upload debug symbols to Crashlytics:"
    echo "  firebase crashlytics:symbols:upload --app=YOUR_APP_ID output/debug-symbols"
fi
echo ""
echo "To use in Xcode: drag opencv2.xcframework into your project,"
echo "or reference it as a Swift Package binary target with the checksum above."