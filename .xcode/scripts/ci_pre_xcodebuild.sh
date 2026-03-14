#!/bin/sh
# Xcode Cloud pre-build hook — generate Makam.xcodeproj from project.yml using XcodeGen.
set -e

echo "--- Installing XcodeGen via Homebrew ---"
brew install xcodegen

echo "--- Generating Makam.xcodeproj ---"
xcodegen generate --spec "$CI_PRIMARY_REPOSITORY_PATH/project.yml" --project "$CI_PRIMARY_REPOSITORY_PATH"

echo "--- Done ---"
