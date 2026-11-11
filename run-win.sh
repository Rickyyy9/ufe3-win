#!/usr/bin/env bash
# Run the recompiled game from its extracted disc folder.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
deps=${UFE3_DEPS:-$root/deps}
ufe3=$deps/ufe3-recomp
export PS2X_RUNNER=${PS2X_RUNNER:-$deps/PS2Recomp/build/ps2xRuntime/ps2EntryRunner.exe}

[ -f "$ufe3/disc/SLPS_254.41" ] || { echo "Missing $ufe3/disc/SLPS_254.41. Extract your own disc image first." >&2; exit 1; }
[ -f "$PS2X_RUNNER" ] || { echo "Runner not built. Run setup-win.sh." >&2; exit 1; }

cd "$ufe3/disc"
exec "$PS2X_RUNNER" ./SLPS_254.41
