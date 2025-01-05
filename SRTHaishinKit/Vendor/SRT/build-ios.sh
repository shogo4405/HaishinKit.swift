#!/bin/bash

# Copyright (c) shogo4405 and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD 3-Clause License found in the
# LICENSE file in the root directory of this source tree.

srt_ios() {
  IOS_OPENSSL=$(pwd)/OpenSSL/$1

  mkdir -p ./build/ios/$2
  pushd ./build/ios/$2
  ../../../srt/configure --cmake-prefix-path=$IOS_OPENSSL --ios-disable-bitcode=1 --ios-platform=$2 --ios-arch=arm64 --cmake-toolchain-file=scripts/iOS.cmake --USE_OPENSSL_PC=off
  make
  popd
}

# iOS
export IPHONEOS_DEPLOYMENT_TARGET=13.0
SDKVERSION=$(xcrun --sdk iphoneos --show-sdk-version)
srt_ios iphonesimulator SIMULATOR64
srt_ios iphoneos OS
mkdir -p ./build/ios/_SIMULATOR64
libtool -static -o ./build/ios/_SIMULATOR64/libsrt.a ./build/ios/SIMULATOR64/libsrt.a ./OpenSSL/iphonesimulator/lib/libcrypto.a ./OpenSSL/iphonesimulator/lib/libssl.a
mkdir -p ./build/ios/_OS
libtool -static -o ./build/ios/_OS/libsrt.a ./build/ios/OS/libsrt.a ./OpenSSL/iphoneos/lib/libcrypto.a ./OpenSSL/iphoneos/lib/libssl.a

