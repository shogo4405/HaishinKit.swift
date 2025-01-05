#!/bin/bash

# Copyright (c) shogo4405 and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD 3-Clause License found in the
# LICENSE file in the root directory of this source tree.

cp module.modulemap Includes/module.modulemap
cp ./build/ios/OS/version.h Includes/version.h

rm -rf libsrt.xcframework
xcodebuild -create-xcframework \
    -library ./build/ios/_SIMULATOR64/libsrt.a -headers Includes \
    -library ./build/ios/_OS/libsrt.a -headers Includes \
    -library ./build/visionos/_SIMULATOR/libsrt.a -headers Includes \
    -library ./build/visionos/_OS/libsrt.a -headers Includes \
    -library ./build/tvos/_SIMULATOR/libsrt.a -headers Includes \
    -library ./build/tvos/_OS/libsrt.a -headers Includes \
    -library ./build/macosx/libsrt.a -headers Includes \
    -output libsrt.xcframework

