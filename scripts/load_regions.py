#!/usr/bin/env python3
"""Load a YAML region/transport-key file into repeater.db's transport_keys table.

Performs a full replace via SQLiteHandler.sync_transport_keys: every existing
transport key is removed and replaced with the entries from the YAML file.
Omit transport_key on an entry to have one derived from its name automatically
(same MeshCore-compatible derivation the app uses).

Run inside the container, e.g.:
    load-regions /etc/openhop_repeater/regions.yaml
"""
import argparse
import sys
from pathlib import Path

import yaml

from repeater.data_acquisition.sqlite_handler import SQLiteHandler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("yaml_file", help="YAML file of region/transport-key entries")
    parser.add_argument(
        "-d",
        "--storage-dir",
        default="/var/lib/openhop_repeater",
        help="Directory containing repeater.db (default: %(default)s)",
    )
    args = parser.parse_args()

    entries = yaml.safe_load(Path(args.yaml_file).read_text()) or []
    if not isinstance(entries, list):
        sys.exit("YAML file must contain a list of region entries")

    payload = []
    for entry in entries:
        name = entry.get("name")
        if not name:
            sys.exit(f"Region entry missing 'name': {entry}")
        payload.append(
            {
                "node_id": name,
                "name": name,
                "flood_policy": entry.get("flood_policy", "allow"),
                "transport_key": entry.get("transport_key"),
                "parent_node_id": entry.get("parent_name"),
            }
        )

    handler = SQLiteHandler(Path(args.storage_dir))
    result = handler.sync_transport_keys(payload)
    print(f"Applied {len(payload)} region(s): {result}")


if __name__ == "__main__":
    main()
