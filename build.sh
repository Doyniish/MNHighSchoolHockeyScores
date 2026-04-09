#!/bin/bash
# Build script with proper SDK configuration for macOS
SDK=$(xcrun --sdk macosx --show-sdk-path)

# Check if first argument is "run" - if so, build first then run
if [ "$1" = "run" ]; then
    swift build -Xcc -isysroot -Xcc "$SDK" -Xcc -I -Xcc "$SDK/usr/include/c++/v1" && \
    ./.build/debug/HockeyScoresAPI
else
    swift build -Xcc -isysroot -Xcc "$SDK" -Xcc -I -Xcc "$SDK/usr/include/c++/v1" "$@"
fi
