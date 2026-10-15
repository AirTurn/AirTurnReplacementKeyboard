#!/bin/sh
# Runs the AirTurnReplacementKeyboard package's unit tests.
#
# Usage:
#   scripts/test.sh                          # picks an iPhone on the newest iOS runtime
#   scripts/test.sh <simulator-udid>         # runs against a specific simulator
#   scripts/test.sh "platform=iOS Simulator,name=iPhone 16 Pro"   # full destination string
#   scripts/test.sh "" -resultBundlePath /tmp/KeyboardTests.xcresult
# Additional arguments after the destination are forwarded to xcodebuild.

set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_directory=$(CDPATH= cd -- "$script_directory/.." && pwd)
cd "$package_directory"

destination_argument=${1:-}
if [ "$#" -gt 0 ]; then
    shift
fi

if [ -z "$destination_argument" ]; then
    # Use an iPhone on the newest available iOS runtime. Layout tests depend
    # on the runtime: UIHostingController applies safe-area insets
    # differently before iOS 26, and the SDK is calibrated against iOS 26+.
    # On that runtime, prefer a booted iPhone, then iPhone 17 Pro, then the
    # first iPhone listed.
    udid=$(xcrun simctl list devices available | awk '
        /^-- iOS [0-9.]+ --$/ {
            count = split($3, parts, ".")
            version = parts[1] * 10000 + (count > 1 ? parts[2] : 0) * 100 + (count > 2 ? parts[3] : 0)
            next
        }
        /^-- / { version = -1; next }
        version >= 0 && /iPhone/ {
            id = ""
            count = split($0, fields, /[()]/)
            for (i = 1; i <= count; i++) {
                if (fields[i] ~ /^[0-9A-F-]+$/ && length(fields[i]) == 36) id = fields[i]
            }
            if (id == "") next
            rank = /\(Booted\)/ ? 0 : (/iPhone 17 Pro \(/ ? 1 : 2)
            printf "%d\t%d\t%d\t%s\n", version, rank, NR, id
        }' | sort -t "$(printf '\t')" -k1,1nr -k2,2n -k3,3n | awk -F '\t' 'NR == 1 { print $4 }')
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
    -destination "$destination" \
    "$@"
