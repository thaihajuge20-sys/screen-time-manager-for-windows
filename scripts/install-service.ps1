param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,
    [string]$LogPath = "$env:ProgramData\ScreenTimeManager\install-service.log"
)

$ErrorActionPreference = "Stop"
$ServiceName = "ScreenTimeManagerService"
$DisplayName = "Screen Time Manager Service"
$LegacyTaskName = "ScreenTimeManager"

$logDirectory = Split-Path -Parent $LogPath
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
Set-Content -Path $LogPath -Value "Screen Time Manager service installation"

function Invoke-ServiceControl {
    param([string[]]$Arguments)

    $output = & sc.exe @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    Add-Content -Path $LogPath -Value @(
        "sc.exe $($Arguments -join ' ')",
        ($output -join "`n"),
        "Exit code: $exitCode"
    )
    if ($exitCode -ne 0) {
        throw "sc.exe $($Arguments[0]) failed with exit code $exitCode."
    }
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Administrator rights are required to install the service."
}

$ExePath = (Resolve-Path $ExePath).Path
$binaryPath = "`"$ExePath`" --service"

$legacyTask = Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
if ($legacyTask) {
    Unregister-ScheduledTask -TaskName $LegacyTaskName -Confirm:$false
}

if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    Invoke-ServiceControl @("stop", $ServiceName)
    Start-Sleep -Seconds 2
    Invoke-ServiceControl @("delete", $ServiceName)
    Start-Sleep -Seconds 1
}

Invoke-ServiceControl @("create", $ServiceName, "binPath=", $binaryPath, "start=", "auto", "obj=", "LocalSystem", "DisplayName=", $DisplayName)
Invoke-ServiceControl @("description", $ServiceName, "Starts and restores the Screen Time Manager user interface.")
Invoke-ServiceControl @("failure", $ServiceName, "reset=", "86400", "actions=", "restart/2000/restart/5000/restart/30000")
Invoke-ServiceControl @("failureflag", $ServiceName, "1")
Invoke-ServiceControl @("start", $ServiceName)
