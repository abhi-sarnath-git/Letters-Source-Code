#!/bin/bash
set -euo pipefail

# Runs only the fictional, offline portfolio preview on a hosted simulator.
preview_device=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
phones = [d for group in devices.values() for d in group if d["name"].startswith("iPhone")]
if not phones:
    sys.exit("No available iPhone simulator")
print(next((d for d in phones if d["state"] == "Booted"), phones[0])["udid"])
')
if ! xcrun simctl list devices booted | grep -q "$preview_device"; then
  xcrun simctl boot "$preview_device"
fi
xcrun simctl bootstatus "$preview_device" -b
xcrun simctl ui "$preview_device" appearance dark
xcrun simctl status_bar "$preview_device" override --time '9:41' --batteryState charged --batteryLevel 100
xcrun simctl install "$preview_device" build/Build/Products/Debug-iphonesimulator/Letters.app
xcrun simctl launch "$preview_device" com.example.letters
sleep 4
xcrun simctl spawn "$preview_device" launchctl list | grep com.example.letters
mkdir -p "$RUNNER_TEMP/letters-preview"
xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-home.png"

xcrun simctl terminate "$preview_device" com.example.letters
xcrun simctl launch "$preview_device" com.example.letters --preview-alert-all
sleep 3
xcrun simctl spawn "$preview_device" launchctl list | grep com.example.letters
xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-alert-all.png"
