Describe "Screen Time Manager installer" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        $Installer = Get-Content (Join-Path $RepoRoot "installer/screen-time-manager.iss") -Raw
        $InstallService = Get-Content (Join-Path $RepoRoot "scripts/install-service.ps1") -Raw
        $UninstallService = Get-Content (Join-Path $RepoRoot "scripts/uninstall-service.ps1") -Raw
    }

    It "requires administrator rights and installs under Program Files" {
        $Installer | Should -Match "PrivilegesRequired=admin"
        $Installer | Should -Match "DefaultDirName=\{autopf\}\\Screen Time Manager"
    }

    It "registers the service with the stable identity and automatic startup" {
        $InstallService | Should -Match 'ScreenTimeManagerService'
        $InstallService | Should -Match 'binPath='
        $InstallService | Should -Match '\-\-service'
        $InstallService | Should -Match 'start= auto'
    }

    It "configures service recovery and starts the service" {
        $InstallService | Should -Match 'failure.*restart'
        $InstallService | Should -Match 'sc\.exe start'
    }

    It "removes the legacy scheduled task to prevent duplicate startup" {
        $InstallService | Should -Match 'Unregister-ScheduledTask'
        $InstallService | Should -Match 'ScreenTimeManager'
    }

    It "stops and deletes the service during uninstall" {
        $UninstallService | Should -Match 'sc\.exe stop'
        $UninstallService | Should -Match 'sc\.exe delete'
    }

    It "runs service setup after files are installed and cleanup before removal" {
        $Installer | Should -Match '\[Run\]'
        $Installer | Should -Match 'install-service\.ps1'
        $Installer | Should -Match '\[UninstallRun\]'
        $Installer | Should -Match 'uninstall-service\.ps1'
    }
}
