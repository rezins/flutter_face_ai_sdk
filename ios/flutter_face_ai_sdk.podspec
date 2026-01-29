#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_face_ai_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_face_ai_sdk'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Face AI SDK - Face detection, enrollment, and verification'
  s.description      = <<-DESC
Flutter Face AI SDK provides face detection, enrollment, verification, and liveness detection capabilities.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.resources = ['Resources/**/*']
  s.dependency 'Flutter'

  # Use FaceAISDK_Core (version managed by app's Podfile)
  s.dependency 'FaceAISDK_Core'

  s.platform = :ios, '15.5'
  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 arm64',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO',
    'SWIFT_EMIT_LOC_STRINGS' => 'NO'
  }
  s.user_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO'
  }
  s.swift_version = '5.0'
end
