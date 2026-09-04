#!/bin/sh
# Runs the AirTurnReplacementKeyboard package's unit tests.
#
# Usage:
#   scripts/test.sh                          # picks an available iPhone simulator
#   scripts/test.sh <simulator-udid>         # runs against a specific simulator
#   scripts/test.sh "platform=iOS Simulator,name=iPhone 16 Pro"   # full destination string

set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_directory=$(CDPATH= cd -- "$script_directory/.." && pwd)
cd "$package_directory"

destination_argument=${1:-}

if [ -z "$destination_argument" ]; then
    # Prefer a simulator that is already booted; fall back to the first
    # available iPhone runtime otherwise.
    udid=$(xcrun simctl list devices booted | awk -F'[()]' '/iPhone/ {print $2; exit}')
    if [ -z "$udid" ]; then
        udid=$(xcrun simctl list devices available | awk -F'[()]' '/iPhone/ {print $2; exit}')
    fi
    if [ -z "$udid" ]; then
        echo "No iPhone simulator is available. Pass a destination explicitly, e.g.:" >&2
        echo "  scripts/test.sh \"platform=iOS Simulator,name=iPhone 16 Pro\"" >&2
        exit 2
    fi
    destination="platform=iOS Simulator,id=$udid"
elif [ "$destination_argument" != "${destination_argument#platform=}" ]; then
    destination="$destination_argument"
else
    destination="platform=iOS Simulator,id=$destination_argument"
fi

echo "Running AirTurnReplacementKeyboard-Package tests on: $destination"

xcodebuild test \
    -scheme AirTurnReplacementKeyboard-Package \
    -destination "$destination"
