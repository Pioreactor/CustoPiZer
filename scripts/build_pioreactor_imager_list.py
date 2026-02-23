import hashlib
import json
import os
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from typing import Dict, Iterable, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_REPOSITORY_DIR = SCRIPT_DIR.parent / "data_repository"
RELEASES_PATH = DATA_REPOSITORY_DIR / "list_of_pioreactor_releases.json"
REFERENCE_PATH = DATA_REPOSITORY_DIR / "os_list_pioreactor.json"
OUTPUT_PATH = DATA_REPOSITORY_DIR / "os_list_pioreactor.json"
CACHE_PATH = DATA_REPOSITORY_DIR / "pioreactor_image_cache.json"

ICON_PLACEHOLDER = "https://cdn.shopify.com/s/files/1/0678/1739/files/pioreactor_square_logo.png?v=1674681948"
DEVICE_TAGS = ["pi5-32bit", "pi4-32bit", "pi3-32bit", "pi2-32bit"]
ZIP_ASSETS = {
    "Pioreactor Leader": "pioreactor_leader.zip",
    "Pioreactor Leader + Worker": "pioreactor_leader_worker.zip",
    "Pioreactor Worker": "pioreactor_worker.zip",
}

def load_json(path: Path):
    with path.open() as fh:
        return json.load(fh)


def save_json(path: Path, data) -> None:
    with path.open("w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


def ensure_cache() -> Dict[str, Dict[str, int]]:
    if CACHE_PATH.exists():
        with CACHE_PATH.open() as fh:
            return json.load(fh)
    return {}


def write_cache(cache: Dict[str, Dict[str, int]]) -> None:
    with CACHE_PATH.open("w") as fh:
        json.dump(cache, fh, indent=2)
        fh.write("\n")


def download_to_temp(url: str) -> str:
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        temp_path = tmp.name
    try:
        with urllib.request.urlopen(url) as response, open(temp_path, "wb") as fh:
            while True:
                chunk = response.read(8 * 1024 * 1024)
                if not chunk:
                    break
                fh.write(chunk)
    except Exception:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise
    return temp_path


def compute_uncompressed_metadata(zip_path: str) -> Tuple[int, str]:
    with zipfile.ZipFile(zip_path) as archive:
        image_name = locate_image_member(archive, zip_path)
        digest = hashlib.sha256()
        total = 0
        with archive.open(image_name) as image_file:
            for chunk in iter(lambda: image_file.read(8 * 1024 * 1024), b""):
                if not chunk:
                    break
                digest.update(chunk)
                total += len(chunk)
        return total, digest.hexdigest()


def locate_image_member(archive: zipfile.ZipFile, zip_path: str) -> str:
    members = [name for name in archive.namelist() if name.endswith(".img")]
    if not members:
        raise ValueError(f"No .img file found in archive: {zip_path}")
    if len(members) > 1:
        members.sort()
    return members[0]


def image_size_from_zip(zip_path: str) -> int:
    with zipfile.ZipFile(zip_path) as archive:
        return archive.getinfo(locate_image_member(archive, zip_path)).file_size


def parse_checksum_body(body: str) -> str:
    # Expect format: "<sha256>  filename"
    return body.split()[0]


def fetch_checksum(checksum_url: str) -> str:
    with urllib.request.urlopen(checksum_url) as response:
        body = response.read().decode().strip()
    return parse_checksum_body(body)


def load_precomputed_sizes(size_asset: dict | None) -> Dict[str, int]:
    if not size_asset:
        return {}
    url = size_asset.get("browser_download_url")
    if not url:
        return {}
    try:
        with urllib.request.urlopen(url) as response:
            payload = json.load(response)
    except Exception as exc:
        print(f"    failed to load precomputed sizes from {url}: {exc}")
        return {}

    size_map: Dict[str, int] = {}
    for entry in payload.values():
        zip_name = entry.get("zip")
        size_bytes = entry.get("size_bytes")
        if zip_name and isinstance(size_bytes, int):
            size_map[zip_name] = size_bytes
    if size_map:
        print(f"    loaded precomputed sizes from {url}")
    return size_map


def fetch_asset_metadata(
    asset_url: str,
    checksum_url: str | None,
    cache: Dict[str, Dict[str, int]],
    compressed_size: int | None,
    compute_extract_size: bool,
    precomputed_extract_size: int | None = None,
    precomputed_sha256: str | None = None,
) -> Tuple[int, str]:
    cached = cache.get(asset_url, {})
    extract_size = precomputed_extract_size or cached.get("extract_size")
    extract_sha256 = precomputed_sha256 or cached.get("extract_sha256")
    updated_cache = False

    if not extract_sha256 and checksum_url:
        try:
            extract_sha256 = fetch_checksum(checksum_url)
            print(f"    checksum from {checksum_url}")
            updated_cache = True
        except Exception as exc:
            print(f"    failed to fetch checksum from {checksum_url}: {exc}")

    needs_size = extract_size is None
    needs_sha = extract_sha256 is None
    if not needs_size and not needs_sha:
        print(f"    cache hit for {asset_url}")
        if updated_cache or asset_url not in cache:
            cache[asset_url] = {
                "extract_size": extract_size,
                "extract_sha256": extract_sha256,
            }
            write_cache(cache)
        return extract_size, extract_sha256

    must_download_for_sha = needs_sha and not checksum_url and not precomputed_sha256
    must_download_for_size = needs_size and compute_extract_size

    if needs_size and not (must_download_for_size or must_download_for_sha):
        # No path to produce extract_size.
        raise ValueError(
            "extract_size missing and not computed. Add extract_size to release data or rerun with extract size computation."
        )

    if not must_download_for_sha and not must_download_for_size:
        cache[asset_url] = {
            "extract_size": extract_size,
            "extract_sha256": extract_sha256,
        }
        write_cache(cache)
        return extract_size, extract_sha256

    print(f"    downloading {asset_url}")
    temp_path = download_to_temp(asset_url)
    try:
        if needs_sha and (must_download_for_sha or not checksum_url):
            computed_size, extract_sha256 = compute_uncompressed_metadata(temp_path)
            extract_size = extract_size or computed_size
            print(f"    computed sha256 {extract_sha256}")
        if must_download_for_size and extract_size is None:
            extract_size = image_size_from_zip(temp_path)
        if extract_size is not None:
            print(f"    extracted size {extract_size} bytes")
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    cache[asset_url] = {
        "extract_size": extract_size,
        "extract_sha256": extract_sha256,
    }
    write_cache(cache)
    return extract_size, extract_sha256


def iso_date(published_at: str) -> str:
    if not published_at:
        return ""
    return published_at.split("T", 1)[0]


def parse_filter() -> Iterable[str] | None:
    value = os.environ.get("PIOREACTOR_RELEASE_FILTER", "").strip()
    if not value:
        return None
    tokens = [token.strip() for token in value.split(",") if token.strip()]
    return set(tokens) if tokens else None


def latest_release_date(entry: dict) -> str:
    return max(
        (
            subitem.get("release_date", "")
            for subitem in entry.get("subitems", [])
            if subitem.get("release_date")
        ),
        default="",
    )


def mark_latest(entries: list[dict]) -> None:
    suffix = " (latest)"
    for entry in entries:
        name = entry.get("name", "")
        entry["name"] = name[:-len(suffix)] if name.endswith(suffix) else name
    if entries:
        entries[0]["name"] = f"{entries[0]['name']}{suffix}"


def checksum_name_for_zip(zip_name: str) -> str:
    base = zip_name[:-4] if zip_name.endswith(".zip") else zip_name
    return f"{base}.img.sha256"


def build_release_subitems(
    version: str,
    release_date: str,
    assets_by_name: Dict[str, dict],
    cache: Dict[str, Dict[str, int]],
    compute_extract_size: bool = True,
) -> list[dict]:
    positions = {
        "Pioreactor Leader + Worker": 0,
        "Pioreactor Worker": 1,
        "Pioreactor Leader": 2,
    }
    size_asset = assets_by_name.get("image-sizes.json")
    precomputed_sizes = load_precomputed_sizes(size_asset)
    ordered: list[dict | None] = [None, None, None]
    for label, filename in ZIP_ASSETS.items():
        asset = assets_by_name.get(filename)
        if not asset:
            print(f"  missing asset {filename}, skipping")
            continue

        url = asset["browser_download_url"]
        checksum_asset = assets_by_name.get(checksum_name_for_zip(filename))
        checksum_url = checksum_asset["browser_download_url"] if checksum_asset else None
        extract_size, extract_sha256 = fetch_asset_metadata(
            url,
            checksum_url,
            cache,
            compressed_size=asset.get("size"),
            compute_extract_size=compute_extract_size,
            precomputed_extract_size=precomputed_sizes.get(filename),
            precomputed_sha256=asset.get("extract_sha256"),
        )

        entry = {
            "name": label,
            "description": f"{label} image for Pioreactor {version}",
            "icon": ICON_PLACEHOLDER,
            "url": url,
            "image_download_size": asset.get("size"),
            "release_date": release_date,
            "init_format": "systemd",
            "devices": DEVICE_TAGS,
            "extract_size": extract_size,
            "extract_sha256": extract_sha256,
        }

        position = positions.get(label, len(ordered))
        if position >= len(ordered):
            ordered.append(entry)
        else:
            ordered[position] = entry
    return [item for item in ordered if item]


def build_release_entry(
    release: dict, cache: Dict[str, Dict[str, int]], compute_extract_size: bool = True
) -> dict | None:
    version = release.get("tag_name")
    if not version:
        print("  release missing tag_name, skipping")
        return None

    print(f"Processing release {version}")
    release_date = iso_date(release.get("published_at", ""))

    assets_by_name = {asset["name"]: asset for asset in release.get("assets", [])}
    subitems = build_release_subitems(
        version, release_date, assets_by_name, cache, compute_extract_size=compute_extract_size
    )
    if not subitems:
        print(f"  no downloadable assets located for {version}, skipping release")
        return None

    return {
        "name": f"Pioreactor {version}",
        "description": f"Leader & worker images for {version}.",
        "icon": ICON_PLACEHOLDER,
        "random": False,
        "devices": DEVICE_TAGS,
        "subitems": subitems,
    }


def build_entries(
    releases: Iterable[dict],
    release_filter: Iterable[str] | None,
    cache: Dict[str, Dict[str, int]],
    compute_extract_size: bool = True,
) -> list[dict]:
    entries = []
    for release in releases:
        version = release.get("tag_name")
        if release_filter and version not in release_filter:
            continue
        if release.get("draft") or release.get("prerelease"):
            continue

        entry = build_release_entry(release, cache, compute_extract_size=compute_extract_size)
        if entry:
            entries.append(entry)

    entries.sort(key=latest_release_date, reverse=True)
    return entries


def build_output(
    releases: Iterable[dict],
    reference: dict,
    cache: Dict[str, Dict[str, int]],
    release_filter: Iterable[str] | None = None,
    apply_latest_label: bool = False,
    compute_extract_size: bool = True,
) -> dict | None:
    entries = build_entries(
        releases,
        release_filter,
        cache,
        compute_extract_size=compute_extract_size,
    )
    if not entries:
        return None

    if apply_latest_label:
        mark_latest(entries)

    return {
        "imager": reference.get("imager", {}),
        "os_list": [
            {
                "name": "Pioreactor",
                "description": "Pioreactor images for leader and worker roles.",
                "icon": ICON_PLACEHOLDER,
                "random": False,
                "devices": DEVICE_TAGS,
                "subitems": entries,
            }
        ],
    }


def main() -> None:
    releases = load_json(RELEASES_PATH)
    reference = load_json(REFERENCE_PATH)
    cache = ensure_cache()
    release_filter = parse_filter()

    print(f"Loaded {len(releases)} releases")
    output = build_output(
        releases,
        reference,
        cache,
        release_filter=release_filter,
        apply_latest_label=True,
        compute_extract_size=True,
    )

    if not output:
        if release_filter:
            print("Filter applied and no matching releases produced output; cache updated.")
            write_cache(cache)
        return

    save_json(OUTPUT_PATH, output)
    print(f"Wrote {OUTPUT_PATH}")
    write_cache(cache)
    print(f"Updated cache {CACHE_PATH}")


if __name__ == "__main__":
    main()
