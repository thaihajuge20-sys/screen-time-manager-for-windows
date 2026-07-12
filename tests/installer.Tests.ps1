Describe "Screen Time Manager installer" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        $Installer = Get-Content (Join-Path $RepoRoot "installer/screen-time-manager.iss") -Raw
        $InstallService = Get-Content (Join-Path $RepoRoot "scripts/install-service.ps1") -Raw
        $UninstallService = Get-Content (Join-Path $RepoRoot "scripts/uninstall-service.ps1") -Raw
        $InstallerWorkflow = Get-Content (Join-Path $RepoRoot ".github/workflows/installer-ci.yml") -Raw
    }

    It "requires administrator rights and installs under Program Files" {
        $Installer | Should -Match "PrivilegesRequired=admin"
        $Installer | Should -Match "DefaultDirName=\{autopf\}\\Screen Time Manager"
    }

    It "packages the executable produced by a native Windows release build" {
        $Installer | Should -Match 'target\\release\\screen-time-manager\.exe'
    }

    It "registers the service with the stable identity and automatic startup" {
        $InstallService | Should -Match 'ScreenTimeManagerService'
        $InstallService | Should -Match 'binPath='
        $InstallService | Should -Match '\-\-service'
        $InstallService | Should -Match '"start=", "auto"'
    }

    It "configures service recovery and starts the service" {
        $InstallService | Should -Match 'failure.*restart'
        $InstallService | Should -Match 'Invoke-ServiceControl @\("start"'
    }

    It "removes the legacy scheduled task to prevent duplicate startup" {
        $InstallService | Should -Match 'Unregister-ScheduledTask'
        $InstallService | Should -Match 'ScreenTimeManager'
    }

    It "stops and deletes the service during uninstall" {
        $UninstallService | Should -Match 'sc\.exe stop'
        $UninstallService | Should -Match 'sc\.exe delete'
    }

    It "checks service setup after files are installed and cleans up before removal" {
        $Installer | Should -Match 'AfterInstall: InstallService'
        $Installer | Should -Match 'RaiseException'
        $Installer | Should -Match 'install-service\.ps1'
        $Installer | Should -Match '\[UninstallRun\]'
        $Installer | Should -Match 'uninstall-service\.ps1'
    }

    It "verifies tests, release build, Pester, Inno Setup, and installer artifact in Windows CI" {
        $InstallerWorkflow | Should -Match 'windows-latest'
        $InstallerWorkflow | Should -Match 'cargo test'
        $InstallerWorkflow | Should -Match 'cargo build --release'
        $InstallerWorkflow | Should -Match 'Invoke-Pester'
        $InstallerWorkflow | Should -Match 'iscc'
        $InstallerWorkflow | Should -Match 'upload-artifact'
        $InstallerWorkflow | Should -Match 'windows-integration\.ps1'
    }
}
