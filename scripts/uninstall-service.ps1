$ErrorActionPreference = "Stop"
$ServiceName = "ScreenTimeManagerService"
$LegacyTaskName = "ScreenTimeManager"

if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    & sc.exe stop $ServiceName | Out-Null
    Start-Sleep -Seconds 2
    & sc.exe delete $ServiceName | Out-Null
}

$legacyTask = Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
if ($legacyTask) {
    Unregister-ScheduledTask -TaskName $LegacyTaskName -Confirm:$false
}

$deadline = (Get-Date).AddSeconds(10)
while ((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
}

Remove-Item "$env:ProgramData\ScreenTimeManager" -Recurse -Force -ErrorAction SilentlyContinue
