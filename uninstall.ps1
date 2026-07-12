$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

& (Join-Path $scriptDir "scripts\uninstall-service.ps1")
Write-Host "Screen Time Manager service removed. User data was kept." -ForegroundColor Green
