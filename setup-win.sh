#!/usr/bin/env bash
# Windows build setup: fetch pinned sources, apply patches, build PS2Recomp tools + runner.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
deps=${UFE3_DEPS:-$root/deps}
ufe3=$deps/ufe3-recomp
tools=$deps/PS2Recomp
ufe3_commit=3b7515ebd5a1e21981d4d9eb31b0b9a0d85b5b2a
ps2recomp_commit=c5a9d02573410a2085a4b4b831b0b68ba3515440

fetch_only=0
for arg in "$@"; do
    case "$arg" in
        --fetch-only) fetch_only=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

mkdir -p "$deps" "$root/shims"
printf '#!/usr/bin/env bash\nexec python "$@"\n' > "$root/shims/python3"
chmod +x "$root/shims/python3"
export PATH="$root/shims:$PATH"

if [ ! -d "$ufe3/.git" ]; then
    git clone https://github.com/idiazraz/ufe3-recomp "$ufe3"
fi
git -C "$ufe3" checkout --quiet "$ufe3_commit"
git -C "$ufe3" config core.autocrlf false
git -C "$ufe3" config core.eol lf
find "$ufe3" \( -name '*.sh' -o -name '*.py' \) -not -path '*/tools/*' -exec sed -i 's/\r$//' {} +
if git -C "$ufe3" apply --check "$root/windows/ufe3-windows-fixes.patch" 2>/dev/null; then
    git -C "$ufe3" apply "$root/windows/ufe3-windows-fixes.patch"
else
    echo "ufe3 windows fixes already applied; leaving sources as is" >&2
fi

if [ ! -d "$tools/.git" ]; then
    git clone https://github.com/ran-j/PS2Recomp "$tools"
fi
git -C "$tools" checkout --quiet "$ps2recomp_commit"

if git -C "$tools" apply --check "$ufe3/patches/ps2recomp.patch" 2>/dev/null; then
    git -C "$tools" apply "$ufe3/patches/ps2recomp.patch"
else
    echo "ufe3 patch already applied; leaving sources as is" >&2
fi
if git -C "$tools" apply --check "$root/windows/windows-build-fixes.patch" 2>/dev/null; then
    git -C "$tools" apply "$root/windows/windows-build-fixes.patch"
else
    echo "windows fixes already applied; leaving sources as is" >&2
fi

if [ "$fetch_only" = 1 ]; then
    echo "Sources fetched and patched: $ufe3, $tools"
    echo "Extract your own disc image into $ufe3/disc, then run ./setup-win.sh again."
    exit 0
fi

cmake -S "$tools" -B "$tools/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_CXX_FLAGS=-march=x86-64-v3 \
    -DPS2X_ENABLE_AGRESSIVE_LOGS=OFF \
    -DPS2X_ENABLE_FFMPEG=OFF \
    -DPS2X_SHOW_WINDOWS_CONSOLE=ON \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5

cmake --build "$tools/build" --target ps2_recomp ps2_analyzer ps2EntryRunner -j "$(nproc)"

mingwbin=$(dirname "$(command -v g++)")
for dir in ps2xRecomp ps2xAnalyzer ps2xRuntime; do
    for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
        [ -f "$mingwbin/$dll" ] && cp -f "$mingwbin/$dll" "$tools/build/$dir/"
    done
done

mkdir -p "$ufe3/disc"
echo "Build OK. Extract a disc image you own into: $ufe3/disc"
echo "Then run: ./build-win.sh"
