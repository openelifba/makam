#!/bin/sh
# Xcode Cloud post-clone hook — generate Makam.xcodeproj from project.yml using XcodeGen.
# This must run before package resolution, which is why post-clone is used (not pre-xcodebuild).
set -e

echo "--- Installing XcodeGen via Homebrew ---"
brew install xcodegen

echo "--- Generating Makam.xcodeproj ---"
xcodegen generate --spec "$CI_PRIMARY_REPOSITORY_PATH/project.yml" --project "$CI_PRIMARY_REPOSITORY_PATH"

echo "--- Done ---"
