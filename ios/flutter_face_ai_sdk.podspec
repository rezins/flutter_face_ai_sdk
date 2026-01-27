#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_face_ai_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_face_ai_sdk'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Face AI SDK'
  s.description      = <<-DESC
Flutter Face AI SDK
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'FaceAISDK_Core', :git => 'https://github.com/FaceAISDK/FaceAISDK_Core.git', :tag => '2026.01.04'
  s.platform = :ios, '15.0'

  # Required frameworks
  s.frameworks = 'SwiftUI', 'AVFoundation', 'Photos'

  # Resource bundles (includes assets and privacy manifest)
  s.resource_bundles = {
    'flutter_face_ai_sdk' => ['Resources/**/*.{png,xcassets,xcstrings,xcprivacy}']
  }

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
