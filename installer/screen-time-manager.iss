#ifndef MyAppVersion
  #define MyAppVersion "1.0.40"
#endif

[Setup]
AppId={{B5F3B829-47DD-45A5-8D6D-D38F6AB49BE8}
AppName=Screen Time Manager
AppVersion={#MyAppVersion}
AppPublisher=Shadow
DefaultDirName={autopf}\Screen Time Manager
DefaultGroupName=Screen Time Manager
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=ScreenTimeManager-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\screen-time-manager.exe
LicenseFile=..\LICENSE

[Files]
Source: "..\target\x86_64-pc-windows-msvc\release\screen-time-manager.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\scripts\install-service.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\scripts\uninstall-service.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Screen Time Manager"; Filename: "{app}\screen-time-manager.exe"
Name: "{group}\Uninstall Screen Time Manager"; Filename: "{uninstallexe}"

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\install-service.ps1"" -ExePath ""{app}\screen-time-manager.exe"""; Flags: runhidden waituntilterminated

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\uninstall-service.ps1"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveScreenTimeManagerService"

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop ScreenTimeManagerService', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
  Sleep(1500);
  Result := '';
end;
