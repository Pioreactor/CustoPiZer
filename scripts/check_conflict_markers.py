#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


CONFLICT_MARKER_RE = re.compile(r"^(<{7} |>{7} |\|{7} |={7}$)")


def path_has_conflict_marker(path: Path) -> list[tuple[int, str]]:
    matches: list[tuple[int, str]] = []

    try:
        with path.open("rb") as file:
            for line_number, raw_line in enumerate(file, start=1):
                if b"\0" in raw_line:
                    return []

                line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
                if CONFLICT_MARKER_RE.match(line):
                    matches.append((line_number, line))
    except OSError as exc:
        print(f"{path}: failed to read file: {exc}", file=sys.stderr)
        return [(0, "read error")]

    return matches


def main() -> int:
    parser = argparse.ArgumentParser(description="Fail if files contain Git conflict markers.")
    parser.add_argument("paths", nargs="*", help="Files to scan.")
    args = parser.parse_args()

    failed = False
    for path_text in args.paths:
        path = Path(path_text)
        if not path.is_file():
            continue

        matches = path_has_conflict_marker(path)
        for line_number, marker in matches:
            failed = True
            location = f"{path}:{line_number}" if line_number else str(path)
            print(f"{location}: unresolved Git conflict marker: {marker}", file=sys.stderr)

    if failed:
        print("Remove conflict markers before committing.", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
