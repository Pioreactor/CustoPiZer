import argparse
import json
import sys
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from build_pioreactor_imager_list import (  # noqa: E402
    CACHE_PATH,
    OUTPUT_PATH,
    REFERENCE_PATH,
    RELEASES_PATH,
    build_output,
    ensure_cache,
    load_json,
    parse_filter,
    save_json,
    write_cache,
)


def fetch_release_blob(source: str) -> dict:
    if source.startswith("http://") or source.startswith("https://"):
        with urllib.request.urlopen(source) as response:
            return json.load(response)

    path = Path(source).expanduser()
    with path.open() as fh:
        return json.load(fh)


def upsert_release(releases: list[dict], new_release: dict) -> list[dict]:
    tag = new_release.get("tag_name")
    release_id = new_release.get("id")

    updated = []
    for release in releases:
        if tag and release.get("tag_name") == tag:
            continue
        if release_id and release.get("id") == release_id:
            continue
        updated.append(release)

    updated.append(new_release)
    return updated


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Fetch a Pioreactor release JSON and rebuild os_list_pioreactor.json."
    )
    parser.add_argument(
        "source",
        help="GitHub release API url or path to a saved release JSON blob.",
    )
    parser.add_argument(
        "--no-latest",
        action="store_true",
        help="Do not append '(latest)' to the newest entry.",
    )
    parser.add_argument(
        "--releases-path",
        type=Path,
        default=RELEASES_PATH,
        help="Path to list_of_pioreactor_releases.json.",
    )
    parser.add_argument(
        "--output-path",
        type=Path,
        default=OUTPUT_PATH,
        help="Path to write os_list_pioreactor.json.",
    )
    parser.add_argument(
        "--reference-path",
        type=Path,
        default=REFERENCE_PATH,
        help="Path to the base imager JSON to copy shared metadata from.",
    )
    parser.add_argument(
        "--skip-extract-size",
        action="store_false",
        dest="compute_extract_size",
        help="Skip computing extract_size from ZIPs (requires extract_size already present in release data or cache).",
    )
    parser.set_defaults(compute_extract_size=True)
    args = parser.parse_args()

    release_blob = fetch_release_blob(args.source)

    releases = load_json(args.releases_path)
    releases = upsert_release(releases, release_blob)
    save_json(args.releases_path, releases)
    print(f"Updated release list at {args.releases_path}")

    cache = ensure_cache()
    reference = load_json(args.reference_path)
    output = build_output(
        releases,
        reference,
        cache,
        release_filter=parse_filter(),
        apply_latest_label=not args.no_latest,
        compute_extract_size=args.compute_extract_size,
    )

    if not output:
        print("No matching releases produced output; os_list_pioreactor.json not written.")
        write_cache(cache)
        return

    save_json(args.output_path, output)
    print(f"Wrote {args.output_path}")
    write_cache(cache)
    print(f"Updated cache {CACHE_PATH}")


if __name__ == "__main__":
    main()
