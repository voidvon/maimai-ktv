Pod::Spec.new do |s|
  s.name             = 'ktv2'
  s.version          = '1.0.0'
  s.summary          = 'A minimal Flutter KTV player with audio channel switching.'
  s.description      = <<-DESC
Flutter KTV player plugin with Android libVLC, iOS MobileVLCKit, macOS VLCKit, and Windows libVLC backends.
                       DESC
  s.homepage         = 'https://github.com/voidvon/ktv-player'
  s.license          = { :type => 'MIT' }
  s.author           = { 'voidvon' => 'voidvon@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'MobileVLCKit'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
