# Building Shoreveil Reverb

The project builds with CMake and JUCE 9.0.5. The release source archive includes JUCE for offline builds.

## Requirements

| | Windows | macOS / Linux |
| --- | --- | --- |
| CMake | 3.22 or newer | 3.22 or newer |
| Compiler | Visual Studio 2022 or newer (Desktop C++ workload) | Xcode 14+ / GCC 11+ / Clang 14+ |
| JUCE | 9.0.5 | 9.0.5 |
| Generator | Visual Studio or Ninja | Ninja or Make |

The plug-in builds in VST® 3 format. Windows installer and ZIP packaging use Python 3.9 or newer.

<img src="docs/vst-compatible.png" width="80" alt="Steinberg VST Compatible">

VST is a registered trademark of Steinberg Media Technologies GmbH.

## Getting JUCE

Configure with `-DRIVAGE_FETCH_JUCE=ON` to download the pinned JUCE archive.
CMake verifies its SHA-256 before extracting it. With a restricted connection,
download the [same archive](https://codeload.github.com/juce-framework/JUCE/zip/d60b7a78030661574a615b586d9325ba7a7fa7dd)
and pass `-DSHOREVEIL_JUCE_ARCHIVE=<path-to-zip>` along with the fetch option.
For an offline source bundle, extract the release source ZIP and build from
its top-level directory. It already contains `JUCE-9.0.5/`.

## Windows

`scripts/build.cmd` finds Visual Studio with `vswhere`, runs `vcvars64.bat`, then
configures and builds with CMake + Ninja. From a normal `cmd.exe` or PowerShell:

```bat
scripts\build.cmd all build Release
```

Arguments are:

```
build.cmd <target> <build-dir> <config> [reconfigure|relink]
```

- `<target>` — `ShoreveilReverb_VST3`, `Analyzer`, `ShoreveilPreview`, or `all`
- `<build-dir>` — usually `build`
- `<config>` — `Release` or `Debug` (single-config generators only read this on
  the *first* configure; use a separate build directory for the other config)
- `reconfigure` or `relink` reruns configuration in the chosen build directory. Use a new build directory for a clean build.

The plug-in ends up at:

```
build\Source\ShoreveilReverb_artefacts\Release\VST3\Shoreveil Reverb.vst3
```

To do it by hand instead:

```bat
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target ShoreveilReverb_VST3
```

`vcvars64.bat` matters on Windows: CMake invokes `cl.exe` through pipes, and without
the environment set up the build hangs instead of failing.

## macOS and Linux

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release -DRIVAGE_FETCH_JUCE=ON
cmake --build build --target ShoreveilReverb_VST3
```

The bundle is written to
`build/Source/ShoreveilReverb_artefacts/Release/VST3/Shoreveil Reverb.vst3`, which is a
bundle directory on macOS and a shared object elsewhere.

## Installing

For users, `dist\ShoreveilReverb-<version>-win64.exe` is the installer (see below).
For a quick local check, or when no administrator rights are available:

```bat
scripts\install-user.cmd
```

This copies the bundle to `%LOCALAPPDATA%\Programs\Common\VST3\WTdusk\Shoreveil Reverb.vst3`
To uninstall, remove only the `Shoreveil Reverb.vst3` bundle.

When upgrading from Rivage Reverb, close the DAW and uninstall the old package
first. For a manual install, move the old `Rivage Reverb.vst3` outside all host
scan folders. The two bundles share the same plug-in ID. Rescan after installing
Shoreveil and check that the old project opens with the expected settings.

## Making the installer

`scripts\package.cmd` builds the VST3 if needed and then compiles
`installer\ShoreveilReverb.iss` into `dist\ShoreveilReverb-<version>-win64.exe`:

```bat
scripts\package.cmd            <-- rebuild the plug-in first (default)
scripts\package.cmd nobuild    <-- package the existing build
```

Use a trusted [Inno Setup 6](https://jrsoftware.org/isdl.php) installation.
If the compiler is installed outside the standard location, set its path:

```bat
set SHOREVEIL_ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
```

The installer works offline. Run the chosen installer directly. Optional
signing uses Windows SDK `signtool.exe` and a code-signing certificate available
to the packaging account. Set `SHOREVEIL_SIGNTOOL` to the tool's full path and
`SHOREVEIL_SIGN_CERT_SHA1` to the certificate thumbprint before running either
packager. Signing and signature verification must succeed when configured.
Keep certificate credentials out of the repository. Timestamping needs a
network connection.

The script passes `AppVersion` and `BundleDir` on the command line, so version
bumps in `CMakeLists.txt` flow through without editing the `.iss`. `ISCC`
prints about a hundred lines of compile log; the script redirects it to
`dist\iscc.log` and prints only the artefact, its size and its SHA-256.

The portable archive that ships next to the installer is built from the same
bundle:

```sh
python scripts/make_zip.py
```

It writes `dist/ShoreveilReverb-<version>-win64-vst3.zip` containing the bundle plus
`LICENSE.txt`, `THIRD-PARTY.txt` inside `Contents\Resources` and an
`INSTALL.txt` at the top level, and prints the size and SHA-256 for the release
notes. Both packagers also create `ShoreveilReverb-<version>-source.zip` from the
project and the JUCE tree recorded by CMake.

For every downloadable EXE or ZIP, place a direct link to its matching
corresponding source beside the binary download, at no extra charge. List the
SHA-256 and signing status. Keep the corresponding source available alongside
each binary that remains downloadable, including earlier releases. Add the
[Steinberg compatibility mark](docs/vst-compatible.png) and attribution to
release pages that advertise VST® compatibility.

Notes on the installer itself:

- It installs the bundle to `<chosen folder>\Shoreveil Reverb.vst3`, and puts
  `LICENSE.txt` and `THIRD-PARTY.txt` inside the bundle's `Contents\Resources`
  so the licence travels with the binary.
- `PrivilegesRequired=admin` by default, because `C:\Program Files` needs it.
  `ISCC /DPrivilegesMode=lowest` produces a per-user build for people who cannot
  elevate; the folder page then defaults to the same path but is editable.
- The uninstall files live in `<chosen folder>\.rivage` rather than loose in the
  shared VST3 folder, and uninstalling removes that folder and the registry
  entry.
- The plug-in links the C runtime statically (`CMAKE_MSVC_RUNTIME_LIBRARY` is
  set to `MultiThreaded` in the top-level `CMakeLists.txt`), so the shipped
  `.vst3` needs no Visual C++ redistributable. `dumpbin /dependents` on a
  release build should list only DLLs that ship with Windows; if `VCRUNTIME140`
  or `MSVCP140` shows up, the runtime setting did not reach every target.
- Inno remembers the previously chosen folder (`UsePreviousAppDir=yes`), so a
  second install defaults to wherever the last one went.
- `installer/ShoreveilReverb.iss` **must stay UTF-8 with a BOM** (`EF BB BF`).
  Without the BOM Inno reads the file as ANSI, so every Chinese string in
  `[CustomMessages]` turns into mojibake on screen while the English text still
  looks fine - an early build shipped that way. Editors that strip the BOM
  silently reintroduce the bug.

## Tests and tools

```sh
bash scripts/smoke.sh                      # 26 renders: 6 algorithms, 2 sample rates, 5 buffer sizes
build/tools/analyzer/Analyzer --help       # scan / render / bench / switchtest
build/tools/preview/"Shoreveil Preview"       # editor in a window, --screenshot for docs
```

`smoke.sh` needs the `Analyzer` target built; it renders 26 impulses and checks every exit code.

## Troubleshooting

**The build hangs on Windows.** CMake is trying to reach `cl.exe` without the MSVC
environment. Use `scripts/build.cmd`, or run `vcvars64.bat` in the same shell
before invoking CMake.

**JUCE 9.0.5 was not found.** Use the matching source ZIP or enable the pinned
download. See [Getting JUCE](#getting-juce) for the local archive option.

**Switching between Release and Debug.** Ninja is a single-config generator: the
`Debug` argument is ignored once `build/` has been configured for `Release`. Use a
second directory, for example `scripts\build.cmd ShoreveilReverb_VST3 build-debug Debug`.

**The plug-in does not show up in the DAW.** VST3 hosts scan
`%LOCALAPPDATA%\Programs\Common\VST3` and `C:\Program Files\Common Files\VST3`.
Either run `scripts\install-user.cmd` or point the host at the build directory.
