#!/usr/bin/env python3
"""Dump the transport_keys table ("regions") from repeater.db to YAML.

Run inside the container, e.g.:
    dump-regions -o /etc/openhop_repeater/regions.yaml
"""
import argparse
import sys
from pathlib import Path

import yaml

from repeater.data_acquisition.sqlite_handler import SQLiteHandler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-d",
        "--storage-dir",
        default="/var/lib/openhop_repeater",
        help="Directory containing repeater.db (default: %(default)s)",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="-",
        help="Output YAML file, or '-' for stdout (default: stdout)",
    )
    args = parser.parse_args()

    handler = SQLiteHandler(Path(args.storage_dir))
    keys = handler.get_transport_keys()
    id_to_name = {k["id"]: k["name"] for k in keys}

    regions = []
    for k in keys:
        entry = {
            "name": k["name"],
            "flood_policy": k["flood_policy"],
            "transport_key": k["transport_key"],
        }
        if k["parent_id"] is not None:
            entry["parent_name"] = id_to_name.get(k["parent_id"])
        regions.append(entry)

    text = yaml.safe_dump(regions, sort_keys=False, default_flow_style=False)
    if args.output == "-":
        sys.stdout.write(text)
    else:
        Path(args.output).write_text(text)
        print(f"Wrote {len(regions)} region(s) to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
