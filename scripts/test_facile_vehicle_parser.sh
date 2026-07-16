#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

xcrun swiftc \
  "$ROOT/TyreVibes/Core/Helper/FacileVehicleResponseParser.swift" \
  "$ROOT/TyreVibes/Core/Helper/FacileWebFlow.swift" \
  "$ROOT/TyreVibesTests/FacileVehicleResponseParserRegression.swift" \
  -o "$BUILD_DIR/facile-vehicle-parser-tests"

"$BUILD_DIR/facile-vehicle-parser-tests"
