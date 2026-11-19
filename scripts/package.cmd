@echo off
rem ---------------------------------------------------------------- package.cmd
rem Builds the VST3 and wraps it in the Inno Setup installer.
rem
rem   scripts\package.cmd                 build (incremental) + compile installer
rem   scripts\package.cmd nobuild         reuse the existing build tree
rem   scripts\package.cmd reconfigure     reconfigure and rebuild
rem
rem Output: dist\ShoreveilReverb-<version>-win64.exe
rem ----------------------------------------------------------------
setlocal enabledelayedexpansion

set "ROOT=%~dp0.."
pushd "%ROOT%" || exit /b 1
set "ROOT=%CD%"

set "MODE=%~1"
if "%MODE%"=="" set "MODE=incremental"

rem ------------------------------------------------------------------ version
set "APPVER="
for /f "delims=" %%v in ('python -c "import sys;sys.path.insert(0,r'scripts');from release_support import project_version;print(project_version())"') do set "APPVER=%%v"
if not defined APPVER goto :fail
echo [package] version %APPVER%

rem -------------------------------------------------------------------- build
if /I not "%MODE%"=="nobuild" (
    set "RCARG="
    if /I "%MODE%"=="reconfigure" set "RCARG=reconfigure"
    call "%ROOT%\scripts\build.cmd" ShoreveilReverb_VST3 build Release !RCARG!
    if errorlevel 1 goto :fail
)

set "BUNDLE=%ROOT%\build\Source\ShoreveilReverb_artefacts\Release\VST3\Shoreveil Reverb.vst3"
if not exist "%BUNDLE%\Contents\x86_64-win\Shoreveil Reverb.vst3" (
    echo [package] bundle not found: "%BUNDLE%"
    goto :fail
)

rem ------------------------------------------------------------------ compile
set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if defined RIVAGE_ISCC set "ISCC=%RIVAGE_ISCC%"
if defined SHOREVEIL_ISCC set "ISCC=%SHOREVEIL_ISCC%"
if not exist "%ISCC%" (
    echo [package] Inno Setup compiler missing: "%ISCC%"
    echo [package] set SHOREVEIL_ISCC to ISCC.exe or see BUILDING.md
    goto :fail
)

python scripts\release_support.py
if errorlevel 1 goto :fail

echo [package] compiler: "%ISCC%"
echo [package] compiling installer...
"%ISCC%" /Q "/DAppVersion=%APPVER%" "/DBundleDir=%BUNDLE%" "%ROOT%\installer\ShoreveilReverb.iss" > "%ROOT%\dist\iscc.log" 2>&1
if errorlevel 1 (
    echo [package] compiler output:
    type "%ROOT%\dist\iscc.log"
    goto :fail
)

set "OUT=%ROOT%\dist\ShoreveilReverb-%APPVER%-win64.exe"
if not exist "%OUT%" (
    echo [package] expected output missing: "%OUT%"
    goto :fail
)

python scripts\release_support.py --sign "%OUT%"
if errorlevel 1 goto :fail

echo.
echo [package] done: "%OUT%"
python -c "import hashlib,os,sys;p=sys.argv[1];print('[package] size:',os.path.getsize(p),'bytes');print('[package] sha256:',hashlib.sha256(open(p,'rb').read()).hexdigest())" "%OUT%"
popd
exit /b 0

:fail
echo [package] FAILED
popd
exit /b 1
