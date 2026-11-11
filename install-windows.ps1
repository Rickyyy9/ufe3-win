#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a native Windows build of Ultraman Fighting Evolution 3 from a disc
    image you own.

.DESCRIPTION
    The installer never downloads game data. It fetches the pinned open-source
    recompiler at fixed commits, verifies the disc image you select is the
    Japanese SLPS-25441 release, extracts it locally, recompiles the game code,
    and creates a "play.cmd" launcher plus a desktop shortcut.

    Expect 30-90 minutes for the recompilation on a modern laptop.

.PARAMETER Iso
    Path to your own disc image (.iso). Omit to pick it with a file dialog.

.PARAMETER InstallPrereqs
    Install missing build prerequisites with winget without asking.

.PARAMETER AcceptOwnership
    Skip the "this is your own disc dump" confirmation prompt.

.PARAMETER ForceExtract
    Extract the disc image again even if deps\ufe3-recomp\disc is populated.

.PARAMETER NoShortcut
    Do not create the desktop shortcut.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install-windows.ps1 -Iso D:\games\ufe3.iso
#>
[CmdletBinding()]
param(
    [string]$Iso = "",
    [switch]$InstallPrereqs,
    [switch]$AcceptOwnership,
    [switch]$ForceExtract,
    [switch]$NoShortcut
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Log = Join-Path $Root "install.log"
$Tar = Join-Path $env:SystemRoot "System32\tar.exe"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Test-Tool {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user;$env:Path"
}

function Find-GitBash {
    $candidates = @()
    $found = Get-Command "bash.exe" -ErrorAction SilentlyContinue
    if ($found) { $candidates += $found.Source }
    $candidates += "C:\Program Files\Git\bin\bash.exe"
    $candidates += "C:\Program Files\Git\usr\bin\bash.exe"
    $candidates += "C:\Program Files (x86)\Git\bin\bash.exe"

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path $candidate)) { continue }
        $uname = & $candidate -c "uname -s" 2>$null
        if ($uname -match "MINGW|MSYS") { return $candidate }
    }
    return $null
}

function Get-MingwGpp {
    $candidate = Get-Command "g++" -ErrorAction SilentlyContinue
    if (-not $candidate) { return $null }
    $target = & $candidate.Source -dumpmachine 2>$null
    if ($target -notmatch "mingw") { return $null }
    return $candidate.Source
}

function Invoke-BashScript {
    param(
        [string]$Bash,
        [string]$ScriptName,
        [string[]]$Arguments = @()
    )
    $scriptPath = (Join-Path $Root $ScriptName).Replace("\", "/")
    & $Bash $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptName failed with exit code $LASTEXITCODE"
    }
}

function Select-IsoFile {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select your Ultraman Fighting Evolution 3 disc image"
    $dialog.Filter = "Disc images (*.iso)|*.iso|All files (*.*)|*.*"
    $dialog.CheckFileExists = $true
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }
    return $dialog.FileName
}

function Get-IsoEntry {
    param(
        [string[]]$Entries,
        [string]$LeafName
    )
    $pattern = "(?i)(^|/)${LeafName}(;1)?\s*$"
    return $Entries | Where-Object { $_ -match $pattern } | Select-Object -First 1
}

function Test-IsoImage {
    param([string]$Path)

    if (-not (Test-Path $Tar)) {
        throw "Windows tar.exe not found at $Tar (requires Windows 10 1803 or newer)."
    }

    $entries = & $Tar -tf $Path 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $entries) {
        throw "Could not read $Path as an ISO image. Use an .iso dump; raw .bin images must be converted first."
    }

    $mainEntry = Get-IsoEntry -Entries $entries -LeafName "SLPS_254\.41"
    if (-not $mainEntry) {
        throw "This image does not contain SLPS_254.41. It is not the Japanese release of Ultraman Fighting Evolution 3."
    }

    $cnfEntry = Get-IsoEntry -Entries $entries -LeafName "SYSTEM\.CNF"
    if ($cnfEntry) {
        $cnf = & $Tar -xOf $Path $cnfEntry 2>$null
        if ($cnf -and -not ($cnf -match "(?i)BOOT2\s*=\s*cdrom0:\\SLPS_254\.41")) {
            throw "SYSTEM.CNF does not boot SLPS_254.41; this is a different disc revision."
        }
    }

    return $true
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

$transcript = $null
try {
    try {
        $transcript = Start-Transcript -Path $Log -Append
    } catch {
        $transcript = $null
    }

    Write-Host "Ultraman Fighting Evolution 3 - Windows builder" -ForegroundColor Green
    Write-Host "Project directory: $Root"

    # 1. ownership confirmation --------------------------------------------
    if (-not $AcceptOwnership) {
        Write-Host ""
        Write-Host "This script recompiles the game from a disc image YOU own."
        Write-Host "It does not download or redistribute any game data."
        $answer = Read-Host "Type YES to confirm this is your own disc dump"
        if ($answer -ne "YES") {
            Write-Host "Cancelled."
            return
        }
    }

    # 2. prerequisites ------------------------------------------------------
    Write-Step "Checking build prerequisites"

    $missing = @()
    if (-not (Test-Tool "git")) { $missing += "git" }
    $bash = Find-GitBash
    if (-not $bash) { $missing += "git-bash" }
    $gpp = Get-MingwGpp
    if (-not $gpp) { $missing += "mingw-g++" }
    if (-not (Test-Tool "cmake")) { $missing += "cmake" }
    if (-not (Test-Tool "ninja")) { $missing += "ninja" }
    if (-not (Test-Tool "python")) { $missing += "python" }

    if ($missing.Count -gt 0) {
        Write-Host "Missing: $($missing -join ', ')" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "winget packages:"
        Write-Host "  winget install -e --id Git.Git"
        Write-Host "  winget install -e --id BrechtSanders.WinLibs.POSIX.UCRT"
        Write-Host "  winget install -e --id Kitware.CMake"
        Write-Host "  winget install -e --id Ninja-build.Ninja"
        Write-Host "  winget install -e --id Python.Python.3.12"

        if (-not $InstallPrereqs) {
            $answer = Read-Host "Install the missing packages with winget now? [y/N]"
            if ($answer -match "^(y|yes)$") { $InstallPrereqs = $true }
        }
        if (-not $InstallPrereqs) {
            throw "Install the packages listed above, open a new terminal, then run this script again."
        }
        if (-not (Test-Tool "winget")) {
            throw "winget is not available. Install the packages listed above manually."
        }

        $packages = @()
        if (($missing -contains "git") -or ($missing -contains "git-bash")) {
            $packages += "Git.Git"
        }
        if ($missing -contains "mingw-g++") {
            $packages += "BrechtSanders.WinLibs.POSIX.UCRT"
        }
        if ($missing -contains "cmake") { $packages += "Kitware.CMake" }
        if ($missing -contains "ninja") { $packages += "Ninja-build.Ninja" }
        if ($missing -contains "python") { $packages += "Python.Python.3.12" }

        foreach ($packageId in $packages) {
            Write-Host "Installing $packageId ..."
            & winget install --id $packageId -e --silent `
                --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "winget failed for $packageId; install it manually and rerun."
            }
        }
        Refresh-Path

        $bash = Find-GitBash
        $gpp = Get-MingwGpp
        foreach ($item in @("git", "cmake", "ninja", "python")) {
            if (-not (Test-Tool $item)) { throw "$item is still not on PATH. Open a new terminal and rerun." }
        }
        if (-not $bash) { throw "Git Bash is still not available. Open a new terminal and rerun." }
        if (-not $gpp) { throw "MinGW g++ is still not on PATH. Open a new terminal and rerun." }
    }

    Write-Host "git     : $((Get-Command git).Source)"
    Write-Host "bash    : $bash"
    Write-Host "g++     : $gpp"
    Write-Host "cmake   : $((Get-Command cmake).Source)"
    Write-Host "ninja   : $((Get-Command ninja).Source)"
    Write-Host "python  : $((Get-Command python).Source)"

    # 3. fetch pinned sources ----------------------------------------------
    Write-Step "Fetching pinned sources (ufe3-recomp + PS2Recomp)"
    Invoke-BashScript -Bash $bash -ScriptName "setup-win.sh" -Arguments @("--fetch-only")

    # 4. disc image ---------------------------------------------------------
    Write-Step "Preparing disc image"

    $discDir = Join-Path $Root "deps\ufe3-recomp\disc"
    $mainElf = Join-Path $discDir "SLPS_254.41"
    $erxDir = Join-Path $discDir "ERX"

    if ((Test-Path $mainElf) -and (Test-Path $erxDir) -and -not $ForceExtract) {
        Write-Host "Reusing existing disc extraction: $discDir"
    }
    else {
        if (-not $Iso) {
            if ($env:UFE3_ISO) {
                $Iso = $env:UFE3_ISO
            } else {
                $Iso = Select-IsoFile
            }
        }
        if (-not $Iso) {
            throw "No disc image selected. Pass -Iso <path.iso> or set UFE3_ISO."
        }
        if (-not (Test-Path $Iso)) {
            throw "Disc image not found: $Iso"
        }
        $Iso = (Resolve-Path $Iso).Path
        Write-Host "Checking $Iso ..."
        Test-IsoImage -Path $Iso | Out-Null

        if (Test-Path $discDir) {
            Remove-Item -Path $discDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $discDir -Force | Out-Null

        Write-Host "Extracting disc image (this can take a few minutes) ..."
        & $Tar -xf $Iso -C $discDir
        if ($LASTEXITCODE -ne 0) {
            throw "Disc extraction failed (tar exit $LASTEXITCODE)."
        }
        if (-not (Test-Path $mainElf)) {
            throw "Extraction finished but SLPS_254.41 is missing. The image layout is not supported."
        }
        if (-not (Test-Path $erxDir)) {
            throw "Extraction finished but the ERX folder is missing. The image layout is not supported."
        }
        Write-Host "Disc extracted to $discDir"
    }

    # 5. build tools --------------------------------------------------------
    Write-Step "Building the recompiler and runtime (5-15 minutes)"
    Invoke-BashScript -Bash $bash -ScriptName "setup-win.sh"

    # 6. recompile the game -------------------------------------------------
    Write-Step "Recompiling the game (30-90 minutes)"
    Write-Host "Progress is written to deps\ufe3-recomp\erx\step2\recomp_erx.log and recomp.log."
    Invoke-BashScript -Bash $bash -ScriptName "build-win.sh"

    # 7. launcher -----------------------------------------------------------
    Write-Step "Creating launcher"

    $playCmd = Join-Path $Root "play.cmd"
    $playLines = @(
        "@echo off",
        "setlocal",
        'set "ROOT=%~dp0"',
        'set "RUNNER=%ROOT%deps\PS2Recomp\build\ps2xRuntime\ps2EntryRunner.exe"',
        'set "GAME=%ROOT%deps\ufe3-recomp\disc"',
        "if not exist ""%RUNNER%"" (",
        "  echo Runner not built. Run install.cmd first.",
        "  pause",
        "  exit /b 1",
        ")",
        "if not exist ""%GAME%\SLPS_254.41"" (",
        "  echo Game files missing. Run install.cmd to extract your own disc image.",
        "  pause",
        "  exit /b 1",
        ")",
        'cd /d "%GAME%"',
        '"%RUNNER%" .\SLPS_254.41',
        "if errorlevel 1 pause"
    )
    Set-Content -Path $playCmd -Value $playLines -Encoding ASCII
    Write-Host "Created $playCmd"

    if (-not $NoShortcut) {
        $desktop = [Environment]::GetFolderPath("Desktop")
        if (Test-Path $desktop) {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcutPath = Join-Path $desktop "Ultraman Fighting Evolution 3.lnk"
                $shortcut = $shell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $playCmd
                $shortcut.WorkingDirectory = $Root
                $shortcut.Description = "Ultraman Fighting Evolution 3 (native Windows build)"
                $shortcut.Save()
                Write-Host "Desktop shortcut: $shortcutPath"
            } catch {
                Write-Warn "Could not create the desktop shortcut: $($_.Exception.Message)"
            }
        }
    }

    Write-Host ""
    Write-Host "Done." -ForegroundColor Green
    Write-Host "Start the game with play.cmd or the desktop shortcut."
    Write-Host "Current upstream state: boots, plays the opening and one Story fight, not yet complete."
}
catch {
    Write-Host ""
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($transcript) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}
