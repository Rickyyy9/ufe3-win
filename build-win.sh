#!/usr/bin/env bash
# Recompile the game ELF and rebuild the Windows runner.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
deps=${UFE3_DEPS:-$root/deps}
ufe3=$deps/ufe3-recomp
tools=$deps/PS2Recomp

export PS2X_TOOLS=$tools
export PS2X_RECOMP=$tools/build/ps2xRecomp/ps2_recomp.exe
export PS2X_RUNNER=$tools/build/ps2xRuntime/ps2EntryRunner.exe
export PATH="$root/shims:$PATH"

[ -f "$PS2X_RECOMP" ] || { echo "Recompiler not built. Run setup-win.sh first." >&2; exit 1; }
[ -f "$ufe3/disc/SLPS_254.41" ] || {
    echo "Missing $ufe3/disc/SLPS_254.41." >&2
    echo "Extract a disc image you own, for example:" >&2
    echo "  /c/Windows/System32/tar.exe -xf your.iso -C \"$ufe3/disc\"" >&2
    exit 1
}

if [ ! -f "$ufe3/erx/out/manifest.json" ] || ! compgen -G "$ufe3/erx/out/*.bin" > /dev/null; then
    python3 "$ufe3/erx/erx_prelink.py" --root "$ufe3"
fi

cd "$ufe3"
./rebuild.sh
echo "Runner: $PS2X_RUNNER"
