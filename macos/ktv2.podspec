Pod::Spec.new do |s|
  s.name             = 'ktv2'
  s.version          = '1.0.0'
  s.summary          = 'A minimal Flutter KTV player with audio channel switching.'
  s.description      = <<-DESC
Flutter KTV player plugin with Android libVLC and macOS VLCKit backends.
                       DESC
  s.homepage         = 'https://example.invalid/ktv2'
  s.license          = { :type => 'MIT' }
  s.author           = { 'ktv2' => 'devnull@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.dependency 'VLCKit'
  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
