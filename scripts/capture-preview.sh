#!/bin/bash
# Trace simulator operations for diagnostics; this script carries fictional data only.
set -euxo pipefail

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
xcrun simctl launch "$preview_device" com.example.letters --preview-world-pulse
sleep 4
xcrun simctl spawn "$preview_device" launchctl list | grep com.example.letters
mkdir -p "$RUNNER_TEMP/letters-preview"
xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-home.png"

xcrun simctl terminate "$preview_device" com.example.letters
xcrun simctl launch "$preview_device" com.example.letters --preview-alert-all
sleep 3
xcrun simctl spawn "$preview_device" launchctl list | grep com.example.letters
xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-alert-all.png"

xcrun simctl terminate "$preview_device" com.example.letters
xcrun simctl launch "$preview_device" com.example.letters --preview-letterbox
sleep 3
xcrun simctl spawn "$preview_device" launchctl list | grep com.example.letters
xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-letterbox.png"
swift scripts/verify-letterbox-qr.swift "$RUNNER_TEMP/letters-preview/letters-letterbox.png"

# The new Markets capture uses labelled fictional values, never archived live quotes.
xcrun simctl terminate "$preview_device" com.example.letters
xcrun simctl launch "$preview_device" com.example.letters --preview-markets --preview-world-pulse
sleep 4
xcrun simctl spawn "$preview_device" launchctl list | grep com.example.letters
xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-markets.png"

# Exercise the real provider separately from portfolio fixtures. These diagnostic
# captures are inspected for availability; they are not published as current prices.
for market_topic in stocks indexes oil bitcoin; do
  xcrun simctl terminate "$preview_device" com.example.letters
  xcrun simctl launch "$preview_device" com.example.letters --check-market-quotes --preview-world-pulse "--market-$market_topic"
  sleep 15
  xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-markets-live-$market_topic.png"
done

# A second labelled portfolio capture shows index points, not currency prices.
xcrun simctl terminate "$preview_device" com.example.letters
xcrun simctl launch "$preview_device" com.example.letters --preview-markets --preview-world-pulse --market-indexes
sleep 4
xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-market-indexes.png"

# Separate actual-native portfolio captures for every new media surface and existing unique feature.
# All media fixtures, account numbers and news/market values are visibly fictional.
for media_kind in voiceNote image gif video file; do
  xcrun simctl terminate "$preview_device" com.example.letters || true
  xcrun simctl launch "$preview_device" com.example.letters --preview-world-pulse "--preview-media=$media_kind"
  sleep 4
  xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-media-$media_kind.png"
done
for account_screen in registration passkey calls stickers timer chat-timer destruct-now; do
  xcrun simctl terminate "$preview_device" com.example.letters || true
  xcrun simctl launch "$preview_device" com.example.letters --preview-world-pulse "--preview-$account_screen"
  sleep 4
  xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-$account_screen.png"
done
for news_topic in stocks oil crypto; do
  xcrun simctl terminate "$preview_device" com.example.letters || true
  xcrun simctl launch "$preview_device" com.example.letters --preview-world-pulse "--preview-news=$news_topic"
  sleep 4
  xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-news-$news_topic.png"
done
for market_topic in oil bitcoin; do
  xcrun simctl terminate "$preview_device" com.example.letters || true
  xcrun simctl launch "$preview_device" com.example.letters --preview-world-pulse --preview-markets "--market-$market_topic"
  sleep 4
  xcrun simctl io "$preview_device" screenshot "$RUNNER_TEMP/letters-preview/letters-market-$market_topic-sample.png"
done
