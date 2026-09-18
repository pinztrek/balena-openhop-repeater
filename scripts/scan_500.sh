#!/bin/bash
# scan_500.sh - LoRa-clean 500 kHz slot survey using openHOP's own radio config.
#
# Resolves the SX1262 wiring from openhop_repeater's config.yaml (the same
# file the running daemon reads) via lorascan's openhop auto-resolver, runs
# a multi-bandwidth survey with a 500 kHz CAD grid, and reports the cleanest
# MeshCore-500-aligned 500 kHz channel.
#
# openhop-repeater must NOT be running (or holding the radio) while this
# scans -- there is only one SPI device. openhop-repeater runs here as a
# plain background process (see docker-entrypoint.sh), not a systemd unit,
# so `lorascan auto`'s systemctl-based stop/restore does not apply in this
# container; stop the daemon by hand first.
set -euo pipefail

CONFIG="${OPENHOP_CONFIG:-/etc/openhop_repeater/config.yaml}"
DB="/var/lib/openhop_repeater/lorascan/scan_500-$(date +%Y%m%d-%H%M%S).db"
DURATION="${LORASCAN_DURATION:-12h}"
PROFILE="/var/lib/openhop_repeater/lorascan/auto-openhop.yaml"

# Leading non-option argument (if any) overrides the default DB path, as
# before. Anything else -- leading options, or options after the DB path --
# is passed straight through to `lorascan scan survey`, appended after our
# defaults so it can override them (argparse takes the last value given).
if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
    DB="$1"
    shift
fi

REPORT="${DB%.db}.html"

if pgrep -x openhop-repeater >/dev/null 2>&1; then
    echo "scan_500: openhop-repeater is running and holds the radio -- stop it first" >&2
    exit 1
fi

mkdir -p "$(dirname "$DB")"

echo "scan_500: resolving radio profile from $CONFIG"
python3 - "$CONFIG" "$PROFILE" <<'PY'
import sys
from lorascan import autoconf
from lorascan.profile import dump_profile

config, out = sys.argv[1], sys.argv[2]
r = autoconf.resolve("openhop", config=config)
with open(out, "w") as f:
    f.write(dump_profile(r.profile, "auto-configured from openhop config by scan_500.sh"))
print(f"[scan_500] radio: {r.profile.bus_type} {r.profile.bus_dev}")
for n in r.notes:
    print(f"[scan_500] note: {n}")
PY

echo "scan_500: running $DURATION 500 kHz slot survey -> $DB"
lorascan scan survey --profile "$PROFILE" --db "$DB" \
    --bw 62,125,250,500 --cad-grid 500000 --sfs 7,9,11 --bws 125,250,500 \
    --duration "$DURATION" "$@"

echo "scan_500: report -> $REPORT"
lorascan report --db "$DB" --out "$REPORT" --slot 500000 --recommend-grid
