#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphoneos/build/build-arm64-iphoneos
  make -f /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphoneos/build/build-arm64-iphoneos/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphoneos/build/build-arm64-iphoneos
  make -f /Users/j.freyer/Desktop/opencv-ios-custom/scripts/work/xcframework-build/iphoneos/build/build-arm64-iphoneos/CMakeScripts/ReRunCMake.make
fi

