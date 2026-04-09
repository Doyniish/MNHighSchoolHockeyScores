#!/bin/bash
# Build script with proper SDK configuration for macOS
SDK=$(xcrun --sdk macosx --show-sdk-path)
swift build -Xcc -isysroot -Xcc "$SDK" -Xcc -I -Xcc "$SDK/usr/include/c++/v1" "$@"
