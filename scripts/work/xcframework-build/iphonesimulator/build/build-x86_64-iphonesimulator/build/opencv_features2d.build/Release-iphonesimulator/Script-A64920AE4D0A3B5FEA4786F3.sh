#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphonesimulator/build/build-x86_64-iphonesimulator/modules/features2d
  /opt/homebrew/bin/cmake -DMODULE_NAME=features2d -DCL_DIR=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/modules/features2d/src/opencl -DOUTPUT=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphonesimulator/build/build-x86_64-iphonesimulator/modules/features2d/opencl_kernels_features2d.cpp -P /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/cmake/cl2cpp.cmake
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphonesimulator/build/build-x86_64-iphonesimulator/modules/features2d
  /opt/homebrew/bin/cmake -DMODULE_NAME=features2d -DCL_DIR=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/modules/features2d/src/opencl -DOUTPUT=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphonesimulator/build/build-x86_64-iphonesimulator/modules/features2d/opencl_kernels_features2d.cpp -P /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/cmake/cl2cpp.cmake
fi

