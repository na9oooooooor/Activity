#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/Screenshots/Generated"
TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$OUTPUT_DIR"

python3 - "$OUTPUT_DIR" "$TEMP_DIR" <<'PY'
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

output = Path(sys.argv[1])
temporary = Path(sys.argv[2])

derived_data = (
    Path.home()
    / "Library/Developer/Xcode/DerivedData"
)

results = sorted(
    derived_data.glob(
        "Activity-*/Logs/Test/*.xcresult"
    ),
    key=lambda path: path.stat().st_mtime,
    reverse=True
)[:12]

environment = os.environ.copy()
environment["DEVELOPER_DIR"] = (
    "/Applications/Xcode.app/Contents/Developer"
)

written = set()

for index, result in enumerate(results):
    export_directory = temporary / f"result-{index}"
    export_directory.mkdir()

    subprocess.run(
        [
            "xcrun",
            "xcresulttool",
            "export",
            "attachments",
            "--path",
            str(result),
            "--output-path",
            str(export_directory),
            "--filter",
            "*.png"
        ],
        env=environment,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    manifest = export_directory / "manifest.json"

    if not manifest.exists():
        continue

    records = json.loads(
        manifest.read_text()
    )

    for record in records:
        for attachment in record.get(
            "attachments",
            []
        ):
            suggested = attachment.get(
                "suggestedHumanReadableName",
                ""
            )

            if not re.match(
    r"^(?:\d{2}-|Marketing-)",
    suggested
):
                continue

            clean_name = re.sub(
                r"_\d+_[0-9A-Fa-f-]+(?=\.[^.]+$)",
                "",
                suggested
            )

            if clean_name in written:
                continue

            source = (
                export_directory
                / attachment["exportedFileName"]
            )

            if source.exists():
                shutil.copy2(
                    source,
                    output / clean_name
                )
                written.add(clean_name)
                print(f"Exported {clean_name}")

print(f"\nScreenshots: {output}")
PY

open "$OUTPUT_DIR"