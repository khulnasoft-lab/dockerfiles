#!/bin/bash

set -exo pipefail

PG_FLEX_VERSION="$1"
PG_FLEX_CHECKSUM="$2"
PG_BISON_VERSION="$3"
PG_BISON_CHECKSUM="$4"

# Install bison and flex.
# Note: Pre PostgreSQL 17 the PostgreSQL source archive provided pre-generated files.
## Download Flex
flex_archive="flex-${PG_FLEX_VERSION}.tar.gz"
curl -OLf --retry 6 "https://github.com/westes/flex/releases/download/v${PG_FLEX_VERSION}/${flex_archive}"
sha256sum -c <<< "${PG_FLEX_CHECKSUM} $flex_archive"
tar -xzf "$flex_archive"

## Build flex
pushd "flex-${PG_FLEX_VERSION}"
./configure --prefix=/usr/local
make install
popd

## Download bison
bison_archive="bison-${PG_BISON_VERSION}.tar.gz"
curl -OLf --retry 6 "https://ftp.gnu.org/gnu/bison/${bison_archive}"
sha256sum -c <<< "${PG_BISON_CHECKSUM} $bison_archive"
tar -xzf "$bison_archive"

## Build bison
pushd "bison-${PG_BISON_VERSION}"
./configure --prefix=/usr/local
make install
popd
