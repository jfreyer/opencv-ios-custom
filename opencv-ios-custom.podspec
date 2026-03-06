Pod::Spec.new do |s|
  s.name             = 'opencv-ios-custom'
  s.version          = '4.10.0-6'
  s.summary          = 'OpenCV 4.10.0 for iOS — SIFT and full stitching pipeline, device + simulator'
  s.homepage         = 'https://github.com/jfreyer/opencv-ios-custom'
  s.license          = { :type => 'Apache 2.0' }
  s.author           = { 'jfreyer' => 'j.freyer@forstify.de' }
  s.source = {
    :http => 'https://github.com/jfreyer/opencv-ios-custom/releases/download/4.10.0-6/opencv2.xcframework.zip',
    :sha256 => 'f56868976edcd270e1149171aa179103c18eb77fa798c5b5002ae9ae3e054cb9'
  }
  s.platform         = :ios, '13.0'
  s.requires_arc     = false
  s.vendored_frameworks = 'opencv2.xcframework'
  s.ios.frameworks = [
    'AssetsLibrary',
    'AVFoundation',
    'CoreGraphics',
    'CoreMedia',
    'CoreVideo',
    'Foundation',
    'QuartzCore',
    'UIKit'
  ]
  s.libraries = 'c++', 'stdc++'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY'           => 'libc++'
  }
end