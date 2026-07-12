param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath
)

$ErrorActionPreference = "Stop"
$ServiceName = "ScreenTimeManagerService"
$DisplayName = "Screen Time Manager Service"
$LegacyTaskName = "ScreenTimeManager"

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
    & sc.exe stop $ServiceName | Out-Null
    Start-Sleep -Seconds 2
    & sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 1
}

& sc.exe create $ServiceName binPath= $binaryPath start= auto obj= LocalSystem DisplayName= $DisplayName | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Could not create $ServiceName."
}

& sc.exe description $ServiceName "Starts and restores the Screen Time Manager user interface." | Out-Null
& sc.exe failure $ServiceName reset= 86400 actions= restart/2000/restart/5000/restart/30000 | Out-Null
& sc.exe failureflag $ServiceName 1 | Out-Null
& sc.exe start $ServiceName | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "The service was installed but could not be started."
}
