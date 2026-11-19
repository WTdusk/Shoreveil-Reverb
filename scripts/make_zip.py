"""Build the portable Windows VST3 and its corresponding source archive."""

import argparse
import zipfile

from release_support import (
    BUNDLE_NAME, ROOT, juce_source, make_source_archive, project_version,
    release_bundle, sha256, sign_windows_file, stage_notices,
)

INSTALL_TEXT = """Shoreveil Reverb {version} - Windows x64 VST3

Portable package. Nothing is written outside the folder you copy.

  1. Close the DAW. Uninstall the previous Rivage Reverb installer or move
     its .vst3 bundle out of your DAW's scan folders if installed manually.
     The old and new bundles use the same plug-in ID.
     Unpack this archive.
  2. Copy the whole "{bundle}" folder into the VST3 folder your host scans,
     usually

         C:\\Program Files\\Common Files\\VST3

     or the per-user

         %LOCALAPPDATA%\\Programs\\Common\\VST3

  3. Start (or rescan in) your host and look for "Shoreveil Reverb" under WTdusk.
  4. To uninstall, delete the "{bundle}" folder.

The bundle contains a 64-bit Windows VST3 only: no VST2, AU or AAX builds, and
no other platform. The release page lists the archive SHA-256 and signing status.

Licence: AGPL-3.0-or-later, see LICENSE.txt inside Contents\\Resources.
Corresponding source: download ShoreveilReverb-{version}-source.zip alongside
this binary at the location from which this binary was distributed.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--build-dir', default='build')
    parser.add_argument('--out', default='dist')
    args = parser.parse_args()

    version = project_version()
    build = ROOT / args.build_dir
    bundle = release_bundle(build, version)
    juce = juce_source(build)
    out_dir = ROOT / args.out
    notices = stage_notices(build, juce)
    make_source_archive(out_dir, version, juce)
    sign_windows_file(bundle / "Contents/x86_64-win" / BUNDLE_NAME)

    archive = out_dir / f'ShoreveilReverb-{version}-win64-vst3.zip'
    install = INSTALL_TEXT.format(version=version, bundle=BUNDLE_NAME)
    notice_files = {path.relative_to(notices).as_posix(): path
                    for path in notices.rglob('*') if path.is_file()}

    temporary = archive.with_suffix(".zip.tmp")
    try:
        with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            for path in sorted(bundle.rglob('*')):
                relative = path.relative_to(bundle).as_posix()
                if path.is_file() and (
                    not relative.startswith('Contents/Resources/')
                    or relative.removeprefix('Contents/Resources/') not in notice_files
                ):
                    zf.write(path, f'{BUNDLE_NAME}/{relative}')
            for relative, path in sorted(notice_files.items()):
                zf.write(path, f'{BUNDLE_NAME}/Contents/Resources/{relative}')
            zf.writestr('INSTALL.txt', install)
        temporary.replace(archive)
    finally:
        temporary.unlink(missing_ok=True)

    print(f'zip     : {archive}')
    print(f'size    : {archive.stat().st_size} bytes')
    print(f'sha256  : {sha256(archive)}')
    with zipfile.ZipFile(archive) as zf:
        for info in zf.infolist():
            print(f'  {info.file_size:>8}  {info.filename}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
