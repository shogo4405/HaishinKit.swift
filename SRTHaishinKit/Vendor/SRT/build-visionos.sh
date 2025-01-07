#!/bin/bash

# Copyright (c) shogo4405 and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD 3-Clause License found in the
# LICENSE file in the root directory of this source tree.

srt_visionos() {
  VISION_OPENSSL=$(pwd)/OpenSSL/$1

  mkdir -p ./build/visionos/$2
  pushd ./build/visionos/$2
  ../../../srt/configure --cmake-prefix-path=$VISION_OPENSSL --visionos-platform=$2 --visionos-arch=arm64 --cmake-toolchain-file=scripts/visionOS.cmake --USE_OPENSSL_PC=off
  make
  popd
}

# visionOS
export XROS_DEPLOYMENT_TARGET=1.0
srt_visionos visionsimulator SIMULATOR
srt_visionos visionos OS
mkdir -p ./build/visionos/_SIMULATOR
libtool -static -o ./build/visionos/_SIMULATOR/libsrt.a ./build/visionos/SIMULATOR/libsrt.a ./OpenSSL/visionsimulator/lib/libcrypto.a ./OpenSSL/visionsimulator/lib/libssl.a
mkdir -p ./build/visionos/_OS
libtool -static -o ./build/visionos/_OS/libsrt.a ./build/visionos/OS/libsrt.a ./OpenSSL/visionos/lib/libcrypto.a ./OpenSSL/visionos/lib/libssl.a

