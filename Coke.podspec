#
# Be sure to run `pod lib lint TinySocket.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Coke'
  s.version          = '0.1.0'
  s.summary          = 'Video lib'


  s.description      = <<-DESC
gauss blur video lib
                       DESC

  s.homepage         = 'https://github.com/yinhaoFrancis/TinySocket'

  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'yinhaoFrancis' => '1833918721@qq.com' }
  s.source           = { :git => 'https://github.com/yinhaoFrancis/Coke.git', :tag => s.version.to_s }


  s.ios.deployment_target = '10.0'
  s.source_files = 'Coke/**/*.{swift,c,metal}'
  s.swift_version = '5'
  s.framework  = 'MetalKit'
end
