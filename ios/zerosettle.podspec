#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zerosettle.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zerosettle'
  s.version          = '0.4.0'
  s.summary          = 'Flutter plugin for ZeroSettleKit — Merchant of Record web checkout.'
  s.description      = <<-DESC
    Flutter wrapper for ZeroSettleKit. Provides web checkout, entitlements,
    and compliance via the ZeroSettle Merchant of Record platform.
  DESC
  s.homepage         = 'https://zerosettle.io'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ZeroSettle, Inc.' => 'support@zerosettle.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'ZeroSettleKit', '~> 0.8.0'
  s.platform         = :ios, '17.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
