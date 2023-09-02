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
  OPENSSL=$(pwd)/OpenSSL/$1

  mkdir -p ./build/$1/$2
  pushd ./build/$1/$2
  ../../../srt/configure --cmake-prefix-path=$OPENSSL --cmake-osx-architectures=$2 --USE_OPENSSL_PC=ON --ssl-include-dir=$OPENSSL/include --ssl-libraries=$OPENSSL/lib/libcrypto.a
  make
  popd
}

# macOS
srt_macosx macosx arm64
srt_macosx macosx x86_64
rm -f ./build/macosx/libsrt-lipo.a
lipo -create ./build/macosx/arm64/libsrt.a ./build/macosx/x86_64/libsrt.a -output ./build/macosx/libsrt-lipo.a
libtool -static -o ./build/macosx/libsrt.a ./build/macosx/libsrt-lipo.a ./OpenSSL/macosx/lib/libcrypto.a ./OpenSSL/macosx/lib/libssl.a

# iOS
export IPHONEOS_DEPLOYMENT_TARGET=11.0
SDKVERSION=$(xcrun --sdk iphoneos --show-sdk-version)
srt iphonesimulator SIMULATOR64 x86_64
srt iphonesimulator SIMULATOR64 arm64
srt iphoneos OS arm64

rm -f ./build/SIMULATOR64/libsrt-lipo.a
lipo -create ./build/SIMULATOR64/arm64/libsrt.a ./build/SIMULATOR64/x86_64/libsrt.a -output ./build/SIMULATOR64/libsrt-lipo.a
libtool -static -o ./build/SIMULATOR64/libsrt.a ./build/SIMULATOR64/libsrt-lipo.a ./OpenSSL/iphonesimulator/lib/libcrypto.a ./OpenSSL/iphonesimulator/lib/libssl.a

rm -f ./build/OS/libsrt-lipo.a
lipo -create ./build/OS/arm64/libsrt.a -output ./build/OS/libsrt-lipo.a
libtool -static -o ./build/OS/libsrt.a ./build/OS/libsrt-lipo.a ./OpenSSL/iphoneos/lib/libcrypto.a ./OpenSSL/iphoneos/lib/libssl.a

# make libsrt.xcframework
rm -rf libsrt.xcframework
xcodebuild -create-xcframework \
    -library ./build/SIMULATOR64/libsrt.a -headers Includes \
    -library ./build/OS/libsrt.a -headers Includes \
    -library ./build/macosx/libsrt.a -headers Includes \
    -output libsrt.xcframework

