#!/usr/bin/env bash
# Copyright (c) 2026 kotetsu0000
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  build-essential \
  cmake \
  autoconf \
  automake \
  libtool \
  pkg-config \
  flex \
  bison \
  gperf \
  texinfo \
  xz-utils \
  curl \
  git
