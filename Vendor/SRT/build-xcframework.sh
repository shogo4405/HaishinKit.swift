#!/bin/bash

if which $(pwd)/OpenSSL >/dev/null; then
  echo ""
else
  git clone git@github.com:krzyzanowskim/OpenSSL.git
fi

if which $(pwd)/srt >/dev/null; then
  echo ""
else
  git clone git@github.com:Haivision/srt.git
  pushd srt
  git checkout refs/tags/v1.5.1
  popd
fi

srt() {
  IOS_OPENSSL=$(pwd)/OpenSSL/$1

  mkdir -p ./build/$2/$3
  pushd ./build/$2/$3
  ../../../srt/configure --cmake-prefix-path=$IOS_OPENSSL --ios-disable-bitcode=1 --ios-platform=$2 --ios-arch=$3 --cmake-toolchain-file=scripts/iOS.cmake --USE_OPENSSL_PC=off
  make
  popd
}

srt_macosx() {
  OPENSSL=$(pwd)/OpenSSL/macosx

  mkdir -p ./build/macosx
  pushd ./build/macosx
  ../../srt/configure --cmake-prefix-path=$OPENSSL --cmake-osx-architectures=arm64;x86_64 --USE_OPENSSL_PC=ON --ssl-include-dir=$OPENSSL/include --ssl-libraries=$OPENSSL/lib/libcrypto.a
  make
  popd
}

# compile
srt_macosx

export IPHONEOS_DEPLOYMENT_TARGET=11.0
SDKVERSION=$(xcrun --sdk iphoneos --show-sdk-version)
srt iphonesimulator SIMULATOR64 x86_64
srt iphonesimulator SIMULATOR64 arm64
srt iphoneos OS arm64

rm -rf ./build/simulator
mkdir ./build/simulator
lipo -create ./build/SIMULATOR64/arm64/libsrt.a ./build/SIMULATOR64/x86_64/libsrt.a -output ./build/simulator/libsrt-lipo.a
libtool -static -o ./build/simulator/libsrt.a ./build/simulator/libsrt-lipo.a ./OpenSSL/iphonesimulator/lib/libcrypto.a ./OpenSSL/iphonesimulator/lib/libssl.a

rm -rf ./build/device
mkdir ./build/device
lipo -create ./build/OS/arm64/libsrt.a -output ./build/device/libsrt-lipo.a
libtool -static -o ./build/device/libsrt.a ./build/device/libsrt-lipo.a ./OpenSSL/iphoneos/lib/libcrypto.a ./OpenSSL/iphoneos/lib/libssl.a

# make libsrt.xcframework
rm -rf libsrt.xcframework
xcodebuild -create-xcframework \
    -library ./build/simulator/libsrt.a -headers Includes \
    -library ./build/device/libsrt.a -headers Includes \
    -library ./build/macosx/libsrt.a -headers Includes \
    -output libsrt.xcframework

