#!/bin/bash
# openhop-lorascan-boot.sh - boot-time lorascan survey, run once via
# openhop-lorascan-boot.service (ExecCondition already gates this on
# LORASCAN being set/true/<minutes> -- see the .service file). Same recipe
# as scripts/scan500. On success, uploads the DB via `lorascan share`.
set -uo pipefail
echo "openhop-lorascan-boot.sh started"

CONFIG_DIR="/etc/openhop_repeater"
LIB_DIR="/var/lib/openhop_repeater"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

run_lorascan() {
    echo "+ $*"
    "$@"
}

LORASCAN_DEFAULT_MINUTES=10
if [[ "$LORASCAN" =~ ^[0-9]+$ ]] && [ "$LORASCAN" -gt 1 ]; then
    LORASCAN_MINUTES="$LORASCAN"
else
    LORASCAN_MINUTES="$LORASCAN_DEFAULT_MINUTES"
fi

# lorascan's config, board profiles, network table and share token live under
# the config volume alongside openhop's own config.yaml. Only scan databases
# go under the data volume -- keep --db pointed there explicitly rather than
# relying on --data-dir's default file placement.
export LORASCAN_DIR="${LORASCAN_DIR:-$CONFIG_DIR/lorascan}"
LORASCAN_DB_DIR="${LORASCAN_DB_DIR:-$LIB_DIR/lorascan}"
LORASCAN_DB="$LORASCAN_DB_DIR/entrypoint-$(date +%Y%m%d-%H%M%S).db"
mkdir -p "$LORASCAN_DIR" "$LORASCAN_DB_DIR"

# --from openhop already pulls the antenna location out of config.yaml on
# its own, but pass --cell explicitly so it's never left to an internal
# default if that changes.
LORASCAN_LAT=$(yq '.repeater.latitude // ""' "$CONFIG_FILE")
LORASCAN_LON=$(yq '.repeater.longitude // ""' "$CONFIG_FILE")
LORASCAN_CELL_ARGS=()
if [[ -n "$LORASCAN_LAT" && "$LORASCAN_LAT" != "null" && -n "$LORASCAN_LON" && "$LORASCAN_LON" != "null" ]]; then
    LORASCAN_CELL_ARGS=(--cell "${LORASCAN_LAT},${LORASCAN_LON}")
fi

echo "LORASCAN set: running non-interactive setup from $CONFIG_FILE"
run_lorascan lorascan setup --non-interactive --from openhop --config "$CONFIG_FILE" "${LORASCAN_CELL_ARGS[@]}" \
    || echo "LORASCAN setup failed (continuing anyway)"

echo "LORASCAN set: running ${LORASCAN_MINUTES}m lorascan survey -> $LORASCAN_DB"
if run_lorascan lorascan scan survey --profile auto-openhop --db "$LORASCAN_DB" \
    --bw 62,125,250,500 --cad-grid 500000 --sfs 7,9,11 --bws 125,250,500 \
    --duration "${LORASCAN_MINUTES}m" \
    ${LORASCAN_OPT:-}
then
    echo "LORASCAN set: uploading share for $LORASCAN_DB"
    run_lorascan lorascan share --db "$LORASCAN_DB" --to https://share.lorascan.app \
        || echo "LORASCAN share failed (continuing anyway)"
else
    echo "LORASCAN survey failed (continuing to start openhop-repeater)"
fi

# Keep only the last 3 survey DBs
ls -1t "$LORASCAN_DB_DIR"/entrypoint-*.db 2>/dev/null | tail -n +4 | xargs -r rm -f

echo "openhop-lorascan-boot.sh done"
