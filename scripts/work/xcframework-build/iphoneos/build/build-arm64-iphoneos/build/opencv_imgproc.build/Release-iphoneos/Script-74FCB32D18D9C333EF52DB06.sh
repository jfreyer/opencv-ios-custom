#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphoneos/build/build-arm64-iphoneos/modules/imgproc
  /opt/homebrew/bin/cmake -DMODULE_NAME=imgproc -DCL_DIR=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/modules/imgproc/src/opencl -DOUTPUT=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphoneos/build/build-arm64-iphoneos/modules/imgproc/opencl_kernels_imgproc.cpp -P /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/cmake/cl2cpp.cmake
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphoneos/build/build-arm64-iphoneos/modules/imgproc
  /opt/homebrew/bin/cmake -DMODULE_NAME=imgproc -DCL_DIR=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/modules/imgproc/src/opencl -DOUTPUT=/Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphoneos/build/build-arm64-iphoneos/modules/imgproc/opencl_kernels_imgproc.cpp -P /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/opencv-4.10.0/cmake/cl2cpp.cmake
fi

