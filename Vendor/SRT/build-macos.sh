#!/bin/bash

srt_macos() {
  MACOS_OPENSSL=$(pwd)/OpenSSL/$1

  mkdir -p ./build/$1/$2
  pushd ./build/$1/$2
  ../../../srt/configure --cmake-osx-architectures=$2 --OPENSSL_INCLUDE_DIR=$MACOS_OPENSSL/include --OPENSSL_LIBRARIES=$OPENSSL_INCLUDE_DIR/lib/libcrypto.a
  make
  popd
}

# macOS
srt_macos macosx arm64
libtool -static -o ./build/macosx/libsrt.a ./build/macosx/arm64/libsrt.a ./OpenSSL/macosx/lib/libcrypto.a ./OpenSSL/macosx/lib/libssl.a

