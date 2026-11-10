#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint syphon_server.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'syphon_server'
  s.version          = '0.0.3'
  s.summary          = 'Flutter macOS plugin that publishes widgets as a Syphon Metal server.'
  s.description      = <<-DESC
macOS Flutter plugin that publishes widget frames as a Syphon Metal server
for real-time sharing with Syphon clients.
                       DESC
  s.homepage         = 'https://github.com/GavinFu7/syphon_server'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Gavin Fu' => 'https://github.com/GavinFu7' }

  s.source           = { :path => '.' }
  s.source_files = 'syphon_server/Sources/syphon_server/**/*.{swift,h,m,mm}'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'syphon_server_privacy' => ['syphon_server/Sources/syphon_server/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'
  s.vendored_frameworks = 'Frameworks/Syphon.xcframework'
  s.frameworks = 'Metal', 'IOSurface', 'OpenGL', 'AppKit'

  s.platform = :osx, '14.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
