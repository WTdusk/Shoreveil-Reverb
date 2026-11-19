"""Collect release notices and the corresponding source from a configured build."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
BUNDLE_NAME = "Shoreveil Reverb.vst3"


def project_version() -> str:
    cmake = (ROOT / "CMakeLists.txt").read_text(encoding="utf-8")
    return re.search(r"project\(ShoreveilReverb VERSION ([\d.]+)", cmake).group(1)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def release_bundle(build: Path, version: str) -> Path:
    bundle = build / "Source/ShoreveilReverb_artefacts/Release/VST3" / BUNDLE_NAME
    metadata = bundle / "Contents/Resources/moduleinfo.json"
    if not (bundle / "Contents/x86_64-win" / BUNDLE_NAME).is_file() or not metadata.is_file():
        raise SystemExit(f"No Release VST3 build at {bundle}.")
    # The Steinberg manifest helper allows trailing commas in its output.
    manifest = metadata.read_text(encoding="utf-8")
    info = json.loads(re.sub(r",(?=\s*[}\]])", "", manifest))
    if info["Version"] != version or info["Name"] != "Shoreveil Reverb":
        raise SystemExit(f"Rebuild Shoreveil Reverb {version} before packaging.")
    return bundle


def juce_source(build: Path) -> Path:
    marker = build / "shoreveil-juce-source.txt"
    if not marker.is_file():
        raise SystemExit(f"Missing CMake dependency record at {marker}.")
    source = Path(marker.read_text(encoding="utf-8").strip())
    if not (source / "JUCE.spdx.json").is_file():
        raise SystemExit(f"JUCE source or SBOM is missing at {source}.")
    return source


def upstream_licences(juce: Path):
    yield from (juce / name for name in ("LICENSE.md", "JUCE.spdx.json"))
    for path in sorted((juce / "modules").rglob("*")):
        if path.is_file() and (
            re.search(r"\b(?:licen[cs]e|copying|copyright|notice|patents)\b",
                      path.stem.replace("_", " "), re.IGNORECASE)
            or path.relative_to(juce).as_posix() == "modules/juce_graphics/image_formats/jpglib/README"
        ):
            yield path


def stage_notices(build: Path, juce: Path) -> Path:
    notices = build / "release-notices"
    notices.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "LICENSE", notices / "LICENSE.txt")
    shutil.copyfile(ROOT / "THIRD-PARTY.md", notices / "THIRD-PARTY.txt")
    installer_licence = (ROOT / "LICENSE").read_text(encoding="utf-8") + "\n\n"
    installer_licence += (ROOT / "installer/ChineseSimplified.LICENSE.txt").read_text(encoding="utf-8-sig")
    (build / "installer-license.txt").write_text(installer_licence, encoding="utf-8-sig")
    third_party = notices / "ThirdParty"
    third_party.mkdir(exist_ok=True)
    shutil.copyfile(ROOT / "docs/vst-compatible.png", third_party / "VST-Compatible.png")
    for path in upstream_licences(juce):
        destination = notices / "ThirdParty/JUCE" / path.relative_to(juce)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, destination)
    return notices


def project_files():
    roots = (".gitattributes", ".gitignore", "CMakeLists.txt", "LICENSE", "*.md",
             ".github/workflows/*.yml", ".github/ISSUE_TEMPLATE/*.yml",
             "Source/**/*", "assets/*.jpg", "installer/*", "scripts/*",
             "tools/analyzer/*", "tools/preview/*", "tools/analysis/*",
             "docs/*.png", "docs/*.jpg", "docs/figures/*.png",
             "docs/BEHAVIOUR_FIXES.md", "docs/OPTIMIZATION.md")
    suffixes = {"", ".cmake", ".cpp", ".h", ".txt", ".md", ".jpg", ".png", ".isl",
                ".iss", ".yml", ".cmd", ".py", ".sh", ".gitattributes", ".gitignore"}
    paths = {path for pattern in roots for path in ROOT.glob(pattern)
             if path.is_file() and not path.is_symlink() and path.suffix in suffixes}
    yield from sorted(paths)


def make_source_archive(out_dir: Path, version: str, juce: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    name = f"ShoreveilReverb-{version}-source"
    archive = out_dir / f"{name}.zip"
    temporary = archive.with_suffix(".zip.tmp")
    dependency_dir = f"JUCE-{juce_version()}"
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as package:
            for path in project_files():
                package.write(path, f"{name}/{path.relative_to(ROOT).as_posix()}")
            for path in sorted(juce.rglob("*")):
                relative = path.relative_to(juce)
                if ".git" not in relative.parts and path.is_file() and not path.is_symlink():
                    package.write(path, f"{name}/{dependency_dir}/{relative.as_posix()}")
        temporary.replace(archive)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"source  : {archive}")
    print(f"sha256  : {sha256(archive)}")
    return archive


def juce_version() -> str:
    cmake = (ROOT / "CMakeLists.txt").read_text(encoding="utf-8")
    return re.search(r'set\(SHOREVEIL_JUCE_VERSION "([\d.]+)"\)', cmake).group(1)


def sign_windows_file(path: Path) -> None:
    tool = os.environ.get("SHOREVEIL_SIGNTOOL")
    thumbprint = os.environ.get("SHOREVEIL_SIGN_CERT_SHA1")
    if not tool and not thumbprint:
        return
    if not tool or not thumbprint or not re.fullmatch(r"[0-9a-fA-F]{40}", thumbprint):
        raise SystemExit("Set SHOREVEIL_SIGNTOOL and a valid SHOREVEIL_SIGN_CERT_SHA1 together.")
    subprocess.run([tool, "sign", "/sha1", thumbprint, "/fd", "SHA256",
                    "/tr", "http://timestamp.digicert.com", "/td", "SHA256", str(path)], check=True)
    subprocess.run([tool, "verify", "/pa", str(path)], check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-dir", default="build")
    parser.add_argument("--out", default="dist")
    parser.add_argument("--sign", type=Path)
    args = parser.parse_args()
    if args.sign is not None:
        sign_windows_file(args.sign)
        return

    build = ROOT / args.build_dir
    version = project_version()
    bundle = release_bundle(build, version)
    juce = juce_source(build)
    stage_notices(build, juce)
    make_source_archive(ROOT / args.out, version, juce)
    sign_windows_file(bundle / "Contents/x86_64-win" / BUNDLE_NAME)


if __name__ == "__main__":
    main()
