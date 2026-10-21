#!/bin/bash
set -euo pipefail

# Simulator-only app. No signing credentials or physical-device distribution.
preview_source='build/Build/Products/Debug-iphonesimulator/Letters.app'
preview_output="${RUNNER_TEMP:?RUNNER_TEMP must be set}/letters-download"
preview_folder="$preview_output/Letters-Simulator-Preview"
test -f "$preview_source/Letters"
mkdir -p "$preview_folder"
ditto "$preview_source" "$preview_folder/Letters.app"
cp Docs/SIMULATOR-README.txt "$preview_folder/READ-ME-FIRST.txt"
{
  printf 'Source commit: %s\n' "${GITHUB_SHA:-local}"
  printf '\nXcode:\n'
  xcodebuild -version
  printf '\nSimulator SDK:\n'
  xcrun --sdk iphonesimulator --show-sdk-version
  printf '\nIncluded processor architectures:\n'
  lipo -archs "$preview_folder/Letters.app/Letters"
} > "$preview_folder/BUILD-INFO.txt"
ditto -c -k --sequesterRsrc --keepParent "$preview_folder" "$preview_output/Letters-Simulator-Preview.zip"
(cd "$preview_output" && shasum -a 256 Letters-Simulator-Preview.zip > SHA256SUMS.txt)
