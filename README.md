# ufe3-win

Windows (**MinGW-w64**) build path for the static recompilation of *Ultraman Fighting Evolution 3*
(PS2, `SLPS-25441`), built on [idiazraz/ufe3-recomp](https://github.com/idiazraz/ufe3-recomp)
and [ran-j/PS2Recomp](https://github.com/ran-j/PS2Recomp).

This repo contains **no game data** and no PS2Recomp sources; `setup-win.sh` fetches everything
at pinned commits.

## Status

| Area | Status |
| --- | --- |
| Windows build (`ps2_recomp`, `ps2_analyzer`, `ps2EntryRunner`) | working |
| ELF + 62 ERX modules recompiled | working when a disc image is present |
| Fully playable | **not yet** — upstream is still *early, not playable* |

Current upstream progress: boot, memory-card check, health warning, opening FMV, title screen
accepts input, and one Story-mode fight renders in 3D — running at roughly 1/5 real time before
it stalls ahead of scene 7. Details in
[docs/NOTES.md](https://github.com/idiazraz/ufe3-recomp/blob/main/docs/NOTES.md) and
[work/mimo_title.md](https://github.com/idiazraz/ufe3-recomp/blob/main/work/mimo_title.md).

## Requirements

- Windows 10/11 x64 with AVX2 (x86-64-v3)
- Git Bash
- MinGW-w64 GCC (UCRT) with `g++`, `ninja`, and `cmake` on `PATH`
- Python 3 (`python` on `PATH`)
- Your own disc dump, Japanese region `SLPS-25441`

Visual Studio, WSL, and Linux are not required.

## Installer (recommended)

`install.cmd` runs the whole flow: toolchain check, pinned source fetch, disc
verification and extraction, build, and a `play.cmd` launcher plus desktop
shortcut.

1. Download this repository (Code → Download ZIP) and extract it, or clone it.
2. Keep your own Japanese disc dump (`.iso`) somewhere local.
3. Double-click `install.cmd`, or run it from a terminal.

```bat
install.cmd
```

If build tools are missing, the installer prints the winget commands and offers
to run them. Expect 30-90 minutes for the recompilation.

Non-interactive example:

```powershell
powershell -ExecutionPolicy Bypass -File install-windows.ps1 -Iso D:\dump\ufe3.iso -AcceptOwnership
```

`-ForceExtract` extracts the disc again; `-NoShortcut` skips the desktop shortcut.
The installer never downloads game data and does not ship an executable: every
build is generated locally from your own disc.

## Usage

```bash
git clone https://github.com/Rickyyy9/ufe3-win.git
cd ufe3-win
./setup-win.sh
```

Extract your own disc dump into `deps/ufe3-recomp/disc`:

```bash
/c/Windows/System32/tar.exe -xf your.iso -C deps/ufe3-recomp/disc
```

Then:

```bash
./build-win.sh
./run-win.sh
```

`build-win.sh` runs upstream's `rebuild.sh` (C++ and ERX code generation) and rebuilds the
runner. `run-win.sh` starts `ps2EntryRunner.exe` from the `disc` folder.

To reuse an existing checkout, point `UFE3_DEPS` at a directory that contains `ufe3-recomp/`
and `PS2Recomp/`.

## Windows fixes

`windows/ufe3-windows-fixes.patch` (game project) does two things:

1. `erx_wrap.py` emits TOML paths with forward slashes, because TOML treats `\` as an escape.
2. `rebuild.sh` regenerates `erx/step2/out/erx_bindings.json` before step 3. The pinned tree
   skips it, so a clean build fails with `FileNotFoundError` in `erx_tables.py`.

`windows/windows-build-fixes.patch` is applied after upstream's `patches/ps2recomp.patch`:

1. `ps2_runtime.cpp` — the SIGPROF profiler (`prctl`, `ucontext`, `dladdr`) is now guarded by `#if defined(__linux__)`.
2. `IPU.h` — adds the missing `extern tIPU_BP g_BP;` declaration.
3. `IPU_Fifo.cpp` — includes `IPU.h` instead of the invalid `ipu_core.h`/`ipu_dma.h`.
4. `ipu_core.h` — removes an `#ifdef _MSC_VER` without `#endif` left over from the PCSX2 port.

Note: fix 1 is platform-specific; 2–4 are port bugs that also break a clean Linux build.

## Limitations

- FFmpeg is disabled at configure time (`PS2X_ENABLE_FFMPEG=OFF`) because its prebuilt binaries
  are MSVC-only; video decoding falls back to stub frames.
- SPU2/IPU audio is still partial, and ERX plus VU1/GS performance are unfinished.
- This is not an emulator and it ships no game. Use it only with a disc you own.

## License

GPL-3.0, matching ufe3-recomp and PS2Recomp. The IPU code is derived from PCSX2 (GPL-3.0+).
Ultraman and the game are trademarks and copyrights of their owners; this project is not
affiliated with them.
