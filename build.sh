#!/bin/bash
set -e

APP_NAME="LockBar"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

swiftc main.swift \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macosx12.0 \
    -sdk $(xcrun --sdk macosx --show-sdk-path)

cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp LockBar.icns "$APP_BUNDLE/Contents/Resources/LockBar.icns"

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Done! App bundle created at $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
