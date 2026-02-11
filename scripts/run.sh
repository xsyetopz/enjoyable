#!/bin/bash

set -e

echo "Building Enjoyable..."
swift build

echo "Signing binary..."
codesign -s - .build/debug/enjoyable

echo "Running..."
./.build/debug/enjoyable "$@"
