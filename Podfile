source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def import_pods
    pod 'XCGLogger', '~> 3.3'
    pod 'CryptoSwift', '~> 0.4'
end

target 'lf iOS'  do
    platform :ios, '8.0'
    import_pods
end

target 'lf MacOS' do
    platform :osx, '10.9'
    import_pods
end

target 'Example iOS'  do
    platform :ios, '8.0'
    import_pods
end

target 'Example MacOS' do
    platform :osx, '10.9'
    import_pods
end

target 'Tests' do
    platform :osx, '10.9'
    import_pods
end

