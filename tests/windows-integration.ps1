param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath
)

$ErrorActionPreference = "Stop"
$ServiceName = "ScreenTimeManagerService"
$InstallDir = Join-Path $env:ProgramFiles "Screen Time Manager"
$InstallLog = Join-Path $env:TEMP "screen-time-manager-install.log"
$UninstallLog = Join-Path $env:TEMP "screen-time-manager-uninstall.log"
$failure = $null

function Get-UserInterfaceProcess {
    Get-CimInstance Win32_Process -Filter "Name='screen-time-manager.exe'" |
        Where-Object { $_.CommandLine -notmatch '--service' } |
        Select-Object -First 1
}

try {
    $installer = (Resolve-Path $InstallerPath).Path
    $install = Start-Process -FilePath $installer -ArgumentList @(
        "/VERYSILENT",
        "/SUPPRESSMSGBOXES",
        "/NORESTART",
        "/LOG=$InstallLog"
    ) -Wait -PassThru
    if ($install.ExitCode -ne 0) {
        throw "Installer exited with code $($install.ExitCode)."
    }

    $service = Get-Service -Name $ServiceName
    if ($service.Status -ne "Running") {
        throw "$ServiceName is not running."
    }
    if ($service.StartType -ne "Automatic") {
        throw "$ServiceName is not configured for automatic startup."
    }

    $serviceConfig = (& sc.exe qc $ServiceName) -join "`n"
    if ($serviceConfig -notmatch 'LocalSystem') {
        throw "$ServiceName is not running as LocalSystem."
    }
    if ($serviceConfig -notmatch '--service') {
        throw "$ServiceName binary path does not contain --service."
    }

    $deadline = (Get-Date).AddSeconds(30)
    do {
        $firstUi = Get-UserInterfaceProcess
        if (-not $firstUi) {
            Start-Sleep -Milliseconds 500
        }
    } until ($firstUi -or (Get-Date) -ge $deadline)
    if (-not $firstUi) {
        throw "The service did not start the user interface."
    }

    $firstProcessId = $firstUi.ProcessId
    Stop-Process -Id $firstProcessId -Force

    $deadline = (Get-Date).AddSeconds(45)
    do {
        $replacementUi = Get-UserInterfaceProcess
        if (-not $replacementUi -or $replacementUi.ProcessId -eq $firstProcessId) {
            $replacementUi = $null
            Start-Sleep -Milliseconds 500
        }
    } until ($replacementUi -or (Get-Date) -ge $deadline)
    if (-not $replacementUi) {
        throw "The service did not restore the user interface after Task Manager termination."
    }
}
catch {
    $failure = $_
}
finally {
    $uninstaller = Join-Path $InstallDir "unins000.exe"
    if (Test-Path $uninstaller) {
        $uninstall = Start-Process -FilePath $uninstaller -ArgumentList @(
            "/VERYSILENT",
            "/SUPPRESSMSGBOXES",
            "/NORESTART",
            "/LOG=$UninstallLog"
        ) -Wait -PassThru
        if ($uninstall.ExitCode -ne 0 -and -not $failure) {
            $failure = "Uninstaller exited with code $($uninstall.ExitCode)."
        }
    }
}

if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    throw "$ServiceName still exists after uninstall."
}
if (Test-Path $InstallDir) {
    throw "$InstallDir still exists after uninstall."
}
if ($failure) {
    throw $failure
}

Write-Host "Windows installer integration verification passed."
