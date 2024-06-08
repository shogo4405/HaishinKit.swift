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
  git checkout refs/tags/v1.5.3
  popd
fi

