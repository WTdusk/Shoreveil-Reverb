; ---------------------------------------------------------------------------
; Shoreveil Reverb - VST3 installer (Inno Setup 6)
;
; Build with scripts\package.cmd after building the plug-in:
;   scripts\package.cmd nobuild
;
; The installer is fully offline: it only copies files out of the compiled
; bundle. No download step, no runtime check-in.
; ---------------------------------------------------------------------------

#ifndef AppVersion
  #define AppVersion "0.3.2"
#endif

#ifndef BundleDir
  #define BundleDir "..\build\Source\ShoreveilReverb_artefacts\Release\VST3\Shoreveil Reverb.vst3"
#endif

#define AppName "Shoreveil Reverb"
#define AppPublisher "WTdusk"
#define PluginFolder "Shoreveil Reverb.vst3"
#define LegacyPluginFolder "Rivage Reverb.vst3"

[Setup]
; A stable AppId keeps upgrades in place; changing it makes a second install.
AppId={{5F1B7C24-9E36-4B0A-8F51-2D7A4C1E93B8}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
#ifdef AppRepoURL
AppPublisherURL={#AppRepoURL}
AppSupportURL={#AppRepoURL}/issues
AppUpdatesURL={#AppRepoURL}/releases
#endif
VersionInfoVersion={#AppVersion}
DefaultDirName={commonpf}\Common Files\VST3
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=no
LicenseFile=..\build\installer-license.txt
OutputDir=..\dist
OutputBaseFilename=ShoreveilReverb-{#AppVersion}-win64
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
#ifdef PrivilegesMode
PrivilegesRequired={#PrivilegesMode}
#else
PrivilegesRequired=admin
#endif
DirExistsWarning=no
UsePreviousAppDir=yes
CloseApplications=no
AllowNoIcons=yes
SetupLogging=yes
UninstallDisplayName={#AppName} {#AppVersion}
; Keep the uninstaller out of the shared VST3 root: one folder of our own.
UninstallFilesDir={app}\.rivage
UninstallDisplayIcon={app}\{#PluginFolder}\Contents\x86_64-win\{#PluginFolder}
ShowLanguageDialog=auto

[Languages]
Name: "cn"; MessagesFile: "ChineseSimplified.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
cn.TargetLine=将安装到：
cn.HintStandard=这是 DAW 默认扫描的标准目录，装完直接打开 DAW 即可。
cn.HintCustom=注意：这不是标准 VST3 目录。Reaper / Bitwig 可以在设置里添加扫描路径，Cubase / Studio One 不支持自定义目录，可能扫不到这个插件。
cn.WrongDir=这里要选“存放”插件的文件夹，而不是 Shoreveil Reverb.vst3 本身。
cn.RunOpenFolder=打开安装目录
cn.LegacyDetected=发现旧版 Rivage Reverb：%1%n%n请关闭 DAW，卸载旧版或将该插件移出扫描目录，再安装岸雾混响。两个版本使用同一个插件标识。
cn.SourceInfo=对应源码与本安装程序一起提供：ShoreveilReverb-{#AppVersion}-source.zip。
en.TargetLine=Will install to:
en.HintStandard=This is the folder most DAWs scan by default; just open your DAW after setup.
en.HintCustom=Note: this is not the standard VST3 folder. Reaper and Bitwig can add scan paths; Cubase and Studio One cannot, so they may not see the plug-in.
en.WrongDir=Choose the folder that will contain the plug-in, not Shoreveil Reverb.vst3 itself.
en.RunOpenFolder=Open the install folder
en.LegacyDetected=An older Rivage Reverb bundle was found at %1.%n%nClose your DAW and uninstall it or move it out of the scan folder before installing Shoreveil Reverb. Both bundles use the same plug-in ID.
en.SourceInfo=Corresponding source is available alongside this installer as ShoreveilReverb-{#AppVersion}-source.zip.

[Files]
; The whole VST3 bundle, preserving its internal layout (DLL + moduleinfo.json).
Source: "{#BundleDir}\*"; DestDir: "{app}\{#PluginFolder}"; Flags: ignoreversion recursesubdirs createallsubdirs
; The release script stages licences from the configured build.
Source: "..\build\release-notices\*"; DestDir: "{app}\{#PluginFolder}\Contents\Resources"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "ChineseSimplified.LICENSE.txt"; DestDir: "{app}\{#PluginFolder}\Contents\Resources\ThirdParty"; Flags: ignoreversion

[Run]
Filename: "{app}"; Description: "{cm:RunOpenFolder}"; Flags: postinstall shellexec nowait unchecked

[Code]
var
  PathHint: TNewStaticText;
  StandardDir: String;

procedure UpdateHint(const Dir: String);
var
  Target: String;
begin
  Target := AddBackslash(Dir) + '{#PluginFolder}';

  if CompareText(RemoveBackslashUnlessRoot(Dir), RemoveBackslashUnlessRoot(StandardDir)) = 0 then
    PathHint.Caption := ExpandConstant('{cm:TargetLine}') + #13#10 + Target + #13#10#13#10 +
                        ExpandConstant('{cm:HintStandard}') + #13#10 + ExpandConstant('{cm:SourceInfo}')
  else
    PathHint.Caption := ExpandConstant('{cm:TargetLine}') + #13#10 + Target + #13#10#13#10 +
                        ExpandConstant('{cm:HintCustom}') + #13#10 + ExpandConstant('{cm:SourceInfo}');
end;

procedure InitializeWizard;
begin
  StandardDir := ExpandConstant('{commonpf}\Common Files\VST3');

  PathHint := TNewStaticText.Create(WizardForm);
  PathHint.Parent := WizardForm.SelectDirPage;
  PathHint.Left := WizardForm.DirEdit.Left;
  PathHint.Top := WizardForm.DirEdit.Top + WizardForm.DirEdit.Height + ScaleY(12);
  PathHint.Width := WizardForm.DirEdit.Width + WizardForm.DirBrowseButton.Width;
  PathHint.Height := ScaleY(96);
  PathHint.WordWrap := True;
  PathHint.AutoSize := False;
  UpdateHint(WizardForm.DirEdit.Text);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpSelectDir then
    UpdateHint(WizardForm.DirEdit.Text);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Dir: String;
begin
  Result := True;

  if CurPageID = wpSelectDir then
  begin
    Dir := RemoveBackslashUnlessRoot(WizardForm.DirEdit.Text);

    // The page asks for the container folder; pointing it at the bundle itself
    // would nest ".../Shoreveil Reverb.vst3/Shoreveil Reverb.vst3".
    if (CompareText(ExtractFileName(Dir), '{#PluginFolder}') = 0) or
       (CompareText(ExtractFileName(Dir), '{#LegacyPluginFolder}') = 0) then
    begin
      MsgBox(ExpandConstant('{cm:WrongDir}'), mbError, MB_OK);
      Result := False;
      Exit;
    end;

    UpdateHint(Dir);
  end;
end;

function LegacyBundleIn(const Dir: String): String;
begin
  Result := AddBackslash(Dir) + '{#LegacyPluginFolder}';
  if not DirExists(Result) and not FileExists(Result) then
    Result := '';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Legacy: String;
begin
  Legacy := LegacyBundleIn(ExpandConstant('{app}'));
  if Legacy = '' then
    Legacy := LegacyBundleIn(StandardDir);
  if Legacy = '' then
    Legacy := LegacyBundleIn(ExpandConstant('{localappdata}\Programs\Common\VST3'));
  if Legacy = '' then
    Legacy := LegacyBundleIn(ExpandConstant('{localappdata}\Programs\Common\VST3\WTdusk'));

  Result := '';
  if Legacy <> '' then
    Result := FmtMessage(CustomMessage('LegacyDetected'), [Legacy]);
end;
