param(
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $ExePath) {
    $candidates = @(
        (Join-Path $scriptDir "screen-time-manager.exe"),
        (Join-Path $scriptDir "target\release\screen-time-manager.exe"),
        (Join-Path $scriptDir "target\x86_64-pc-windows-msvc\release\screen-time-manager.exe")
    )
    $ExePath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $ExePath) {
    throw "screen-time-manager.exe was not found. Use the Setup.exe installer or pass -ExePath."
}

& (Join-Path $scriptDir "scripts\install-service.ps1") -ExePath $ExePath
Write-Host "Screen Time Manager service installed and started." -ForegroundColor Green
