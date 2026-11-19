@echo off
rem Installs Shoreveil Reverb into the per-user VST3 folder, which needs no
rem administrator rights and cannot touch any other plug-in installation.
rem
rem   %LOCALAPPDATA%\Programs\Common\VST3\WTdusk\Shoreveil Reverb.vst3
rem
rem Undo: remove only the Shoreveil Reverb.vst3 bundle.

setlocal enableextensions

set "SRC=%~dp0..\build\Source\ShoreveilReverb_artefacts\Release\VST3\Shoreveil Reverb.vst3"
set "DEST=%LOCALAPPDATA%\Programs\Common\VST3\WTdusk"
set "BUNDLE=%DEST%\Shoreveil Reverb.vst3"

if not exist "%SRC%\Contents\x86_64-win\Shoreveil Reverb.vst3" (
    echo ERROR: build the plugin first:
    echo        scripts\build.cmd ShoreveilReverb_VST3 build Release
    exit /b 1
)

if not exist "%DEST%" mkdir "%DEST%" 2>nul

for %%D in ("%DEST%" "%DEST%\.." "%CommonProgramW6432%\VST3") do (
    if exist "%%~D\Rivage Reverb.vst3" (
        echo Close the DAW and uninstall the previous Rivage Reverb bundle at:
        echo %%~D\Rivage Reverb.vst3
        exit /b 1
    )
)

xcopy "%SRC%" "%BUNDLE%\" /e /i /y /q >nul
if errorlevel 1 (
    echo ERROR: copy failed
    exit /b 1
)

echo Installed: "%BUNDLE%"
exit /b 0
