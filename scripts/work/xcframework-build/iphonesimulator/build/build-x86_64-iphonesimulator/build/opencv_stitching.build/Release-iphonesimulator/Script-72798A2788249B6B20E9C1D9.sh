#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphonesimulator/build/build-x86_64-iphonesimulator/modules/stitching
  /opt/homebrew/bin/cmake -DMODULE_NAME=stitching -DCL_DIR=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/modules/stitching/src/opencl -DOUTPUT=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphonesimulator/build/build-x86_64-iphonesimulator/modules/stitching/opencl_kernels_stitching.cpp -P /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/cmake/cl2cpp.cmake
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphonesimulator/build/build-x86_64-iphonesimulator/modules/stitching
  /opt/homebrew/bin/cmake -DMODULE_NAME=stitching -DCL_DIR=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/modules/stitching/src/opencl -DOUTPUT=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphonesimulator/build/build-x86_64-iphonesimulator/modules/stitching/opencl_kernels_stitching.cpp -P /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/cmake/cl2cpp.cmake
fi

