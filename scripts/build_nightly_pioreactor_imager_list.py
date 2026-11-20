#!/usr/bin/env python3

"""Build a Raspberry Pi Imager catalog from locally hosted nightly images."""

import argparse
import hashlib
import json
import os
import re
import tempfile
import zipfile
from datetime import date
from pathlib import Path


REFERENCE_PATH = Path(__file__).resolve().parent.parent / "data_repository" / "os_list_pioreactor.json"
ICON_URL = "https://cdn.shopify.com/s/files/1/0678/1739/files/pioreactor_square_logo.png?v=1674681948"
IMAGE_TYPES = {
    "leader_worker": ("Pioreactor Leader + Worker", ["pi5-32bit", "pi4-32bit", "pi3-32bit", "pi2-32bit"]),
    "worker": ("Pioreactor Worker", ["pi5-32bit", "pi4-32bit", "pi3-32bit", "pi2-32bit"]),
    "leader": ("Pioreactor Leader", ["pi5-32bit", "pi4-32bit", "pi3-32bit", "pi2-32bit"]),
}
DEVICES_64BIT = ["pi5-64bit", "pi4-64bit", "pi3-64bit"]
IMAGE_NAME = re.compile(
    r"^pioreactor_(leader_worker|worker|leader)_(\d{4}-\d{2}-\d{2})(_64)?\.img\.zip$"
)


def image_metadata(zip_path: Path) -> tuple[int, str]:
    with zipfile.ZipFile(zip_path) as archive:
        members = [member for member in archive.infolist() if member.filename.endswith(".img")]
        if len(members) != 1:
            raise ValueError(f"Expected exactly one .img in {zip_path}; found {len(members)}")

        digest = hashlib.sha256()
        with archive.open(members[0]) as image:
            for chunk in iter(lambda: image.read(8 * 1024 * 1024), b""):
                digest.update(chunk)
        return members[0].file_size, digest.hexdigest()


def image_entry(zip_path: Path, nightly_root: Path, base_url: str) -> tuple[str, str, bool, dict]:
    match = IMAGE_NAME.fullmatch(zip_path.name)
    if match is None or zip_path.parent != nightly_root / match.group(1):
        raise ValueError(f"Unrecognized nightly image path: {zip_path}")

    role, build_date, suffix = match.groups()
    date.fromisoformat(build_date)

    role_name, devices = IMAGE_TYPES[role]
    if suffix:
        devices = DEVICES_64BIT
    architecture = "64-bit" if suffix else "32-bit"
    extract_size, extract_sha256 = image_metadata(zip_path)
    relative_path = zip_path.relative_to(nightly_root.parent)

    return build_date, role, bool(suffix), {
        "name": f"{role_name} ({architecture})",
        "description": f"Nightly {architecture} {role_name} image from {build_date}.",
        "icon": ICON_URL,
        "url": f"{base_url.rstrip('/')}/{relative_path.as_posix()}",
        "image_download_size": zip_path.stat().st_size,
        "release_date": build_date,
        "init_format": "systemd",
        "devices": devices,
        "extract_size": extract_size,
        "extract_sha256": extract_sha256,
    }


def build_output(nightly_root: Path, reference: dict, base_url: str) -> dict:
    images_by_date: dict[str, list[tuple[int, bool, dict]]] = {}
    # Only known role directories are published; anything else under nightly_root (e.g. retired roles) is ignored.
    zip_paths = sorted(path for role in IMAGE_TYPES for path in (nightly_root / role).glob("*.img.zip"))
    for zip_path in zip_paths:
        build_date, role, is_64bit, entry = image_entry(zip_path, nightly_root, base_url)
        images_by_date.setdefault(build_date, []).append(
            (list(IMAGE_TYPES).index(role), is_64bit, entry)
        )

    if not images_by_date:
        raise ValueError(f"No nightly images found under {nightly_root}")

    date_entries = []
    for build_date in sorted(images_by_date, reverse=True):
        entries = [entry for _, _, entry in sorted(images_by_date[build_date])]
        parsed_date = date.fromisoformat(build_date)
        date_entries.append({
            "name": f"Pioreactor Nightly {build_date}" + (" (latest)" if not date_entries else ""),
            "description": f"Nightly Pioreactor images built on {parsed_date.strftime('%B')} {parsed_date.day}, {parsed_date.year}.",
            "icon": ICON_URL,
            "random": False,
            "devices": sorted({device for entry in entries for device in entry["devices"]}),
            "subitems": entries,
        })

    return {
        "imager": reference["imager"],
        "os_list": [{
            "name": "Pioreactor Nightly",
            "description": "Nightly Pioreactor images for leader and worker roles.",
            "icon": ICON_URL,
            "random": False,
            "devices": sorted({device for group in date_entries for device in group["devices"]}),
            "subitems": date_entries,
        }],
    }


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as output:
            temp_path = Path(output.name)
            json.dump(data, output, indent=2)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
            os.chmod(temp_path, 0o644)
        os.replace(temp_path, path)
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nightly-root", type=Path, default=Path("/var/www/nightlies/nightly"))
    parser.add_argument("--output-path", type=Path, default=Path("/var/www/nightlies/os_list_pioreactor_nightly.json"))
    parser.add_argument("--reference-path", type=Path, default=REFERENCE_PATH)
    parser.add_argument("--base-url", default="https://nightly.pioreactor.com")
    args = parser.parse_args()

    with args.reference_path.open(encoding="utf-8") as reference_file:
        reference = json.load(reference_file)
    output = build_output(args.nightly_root, reference, args.base_url)
    save_json(args.output_path, output)
    print(f"Wrote {args.output_path}")


if __name__ == "__main__":
    main()
