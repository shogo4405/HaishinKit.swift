#!/bin/bash

# Copyright (c) shogo4405 and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD 3-Clause License found in the
# LICENSE file in the root directory of this source tree.

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
  git checkout refs/tags/v1.5.4
  popd
fi

