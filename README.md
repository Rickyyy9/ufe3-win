# ufe3-win

Jalur build **Windows (MinGW-w64)** untuk static recompilation *Ultraman Fighting Evolution 3*
(PS2, `SLPS-25441`) berbasis [idiazraz/ufe3-recomp](https://github.com/idiazraz/ufe3-recomp)
dan [ran-j/PS2Recomp](https://github.com/ran-j/PS2Recomp).

Repo ini **tidak memuat data game** dan tidak memuat sumber PS2Recomp; semuanya diambil
oleh `setup-win.sh` pada commit yang dipin.

## Status

| Bagian | Status |
| --- | --- |
| Build Windows (`ps2_recomp`, `ps2_analyzer`, `ps2EntryRunner`) | berhasil |
| Recompile ELF + 62 modul ERX | berhasil bila disc tersedia |
| Game bisa dimainkan penuh | **belum** — upstream masih *early, not playable* |

Progres upstream saat ini: boot, cek memory card, health warning, opening FMV, title screen
menerima input, dan satu pertarungan Story mode sudah ter-render 3D — berjalan sekitar
1/5 real-time lalu macet sebelum scene 7. Detail ada di
[docs/NOTES.md](https://github.com/idiazraz/ufe3-recomp/blob/main/docs/NOTES.md) dan
[work/mimo_title.md](https://github.com/idiazraz/ufe3-recomp/blob/main/work/mimo_title.md).

## Kebutuhan

- Windows 10/11 x64 dengan CPU AVX2 (x86-64-v3)
- Git Bash
- MinGW-w64 GCC (UCRT) dengan `g++`, `ninja`, `cmake` di `PATH`
- Python 3 (`python` di `PATH`)
- Disc/ISO milik sendiri, region Jepang `SLPS-25441`

Tidak perlu Visual Studio, WSL, atau Linux.

## Pemakaian

```bash
git clone https://github.com/Rickyyy9/ufe3-win.git
cd ufe3-win
./setup-win.sh
```

Ekstrak dump disc milikmu ke `deps/ufe3-recomp/disc`:

```bash
/c/Windows/System32/tar.exe -xf your.iso -C deps/ufe3-recomp/disc
```

Lalu:

```bash
./build-win.sh
./run-win.sh
```

`build-win.sh` menjalankan `rebuild.sh` milik upstream (generate kode C++ + ERX) dan
membangun ulang runner. `run-win.sh` menjalankan `ps2EntryRunner.exe` dari folder `disc`.

Untuk memakai checkout yang sudah ada, set `UFE3_DEPS` ke direktori yang berisi
`ufe3-recomp/` dan `PS2Recomp/`.

## Perbaikan Windows

`windows/windows-build-fixes.patch` diterapkan setelah `patches/ps2recomp.patch` upstream:

1. `ps2_runtime.cpp` — profiler SIGPROF (`prctl`, `ucontext`, `dladdr`) dibatasi `#if defined(__linux__)`.
2. `IPU.h` — menambahkan deklarasi `extern tIPU_BP g_BP;` yang hilang.
3. `IPU_Fifo.cpp` — include diarahkan ke `IPU.h` (menggantikan `ipu_core.h`/`ipu_dma.h` yang tidak valid).
4. `ipu_core.h` — menghapus `#ifdef _MSC_VER` tanpa `#endif` sisa port PCSX2.

Catatan: 1 hanya soal platform. 2–4 adalah bug port yang juga menggagalkan build bersih di Linux.

## Batasan

- FFmpeg dimatikan saat configure (`PS2X_ENABLE_FFMPEG=OFF`) karena prebuilt-nya MSVC;
  decoding video memakai jalur stub.
- Audio SPU2/IPU masih parsial, ERX dan performa VU1/GS belum selesai.
- Repo ini bukan emulator dan tidak menyertakan game. Gunakan hanya dengan disc yang kamu miliki.

## Lisensi

GPL-3.0, mengikuti ufe3-recomp dan PS2Recomp. Kode IPU berasal dari PCSX2 (GPL-3.0+).
Ultraman dan game terkait adalah merek dagang pemiliknya; proyek ini tidak berafiliasi.
