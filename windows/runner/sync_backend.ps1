# sync_backend.ps1
# Called by CMake POST_BUILD — copies backend source files next to the exe.
# Never exits non-zero so MSBuild never sees a build failure from this script.
param(
    [string]$Src,
    [string]$Dst
)

# Normalize paths (CMake passes forward slashes on Windows)
$Src = $Src.Replace('/', '\').TrimEnd('\')
$Dst = [System.IO.Path]::Combine($Dst.Replace('/', '\').TrimEnd('\'), 'backend')

try {
    if (-not (Test-Path $Src)) {
        Write-Host "[Cyborg] WARNING: Backend source not found: $Src"
        exit 0
    }

    # Dirs to exclude from copy
    $excludeDirs = @('.venv', '__pycache__', 'logs', 'cache', 'checkpoints')

    # Preserve existing .venv if present
    $venvDst = Join-Path $Dst '.venv'
    $venvTmp = Join-Path $env:TEMP 'cyborg_venv_tmp'
    $hadVenv = Test-Path $venvDst

    if ($hadVenv) {
        Write-Host "[Cyborg] Preserving .venv during sync..."
        if (Test-Path $venvTmp) { Remove-Item $venvTmp -Recurse -Force }
        Move-Item $venvDst $venvTmp
    }

    # Robocopy: /E=include subdirs, /XD=exclude dirs, /XF=exclude files
    # /NFL/NDL/NJH/NJS = quiet, /is = include same files (re-copy changed)
    $excludeDirArgs = $excludeDirs | ForEach-Object { $_ }
    & robocopy $Src $Dst /E /XD @excludeDirArgs /XF '*.pyc' '*.pyo' /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

    # Restore .venv
    if ($hadVenv -and (Test-Path $venvTmp)) {
        if (-not (Test-Path $venvDst)) { New-Item -ItemType Directory -Path $venvDst -Force | Out-Null }
        Move-Item $venvTmp $venvDst -Force
        Write-Host "[Cyborg] .venv restored."
    }

    Write-Host "[Cyborg] Backend synced: $Src -> $Dst"
} catch {
    Write-Host "[Cyborg] WARNING: Backend sync error (non-fatal): $_"
}

# Always exit 0 — never block the build
exit 0
