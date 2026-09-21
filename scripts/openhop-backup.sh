#!/bin/bash
# openhop-backup.sh - dump live state back out to the config volume.
# Runs as ExecStopPost= on openhop-repeater.service, so it fires on every
# stop/restart (RECYCLE timer, `systemctl restart`, crash) the same way the
# old docker-entrypoint.sh did right after the app process exited.
set -uo pipefail
echo "openhop-backup.sh started"

LIB_DIR="/var/lib/openhop_repeater"
CONFIG_DIR="/etc/openhop_repeater"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
MQTT_BROKER_FILE="$CONFIG_DIR/mqtt_broker.yaml"
MQTT_SECRET_FILE="$CONFIG_DIR/mqtt_secret.yaml"
REGIONS_FILE="$CONFIG_DIR/regions.yaml"

echo "backing up $LIB_DIR to $CONFIG_DIR/backup"
mkdir -p "$CONFIG_DIR/backup"
cp "$LIB_DIR"/rep* "$CONFIG_DIR/backup/" 2>/dev/null

echo "Refreshing $MQTT_BROKER_FILE from current config.yaml brokers"
if [ -f "$MQTT_BROKER_FILE" ]; then
    cp "$MQTT_BROKER_FILE" "$CONFIG_DIR/backup/mqtt_broker.yaml"
fi
# Exclude any brokers sourced from mqtt_secret.yaml so their credentials never
# get written into mqtt_broker.yaml - that file is user-editable/shareable and
# is not meant to hold secrets.
BROKER_DUMP_SRC="$CONFIG_FILE"
if [ -f "$MQTT_SECRET_FILE" ]; then
    BROKER_DUMP_SRC="$CONFIG_DIR/.broker_dump.yaml"
    cp "$CONFIG_FILE" "$BROKER_DUMP_SRC"
    while IFS= read -r NAME; do
        [ -z "$NAME" ] && continue
        export NAME
        yq -i 'del(.mqtt_brokers.brokers[] | select(.name == strenv(NAME)))' "$BROKER_DUMP_SRC"
    done < <(yq '.[].name' "$MQTT_SECRET_FILE")
fi
yq '.mqtt_brokers.brokers' "$BROKER_DUMP_SRC" > "$MQTT_BROKER_FILE"
[ "$BROKER_DUMP_SRC" != "$CONFIG_FILE" ] && rm -f "$BROKER_DUMP_SRC"
sudo chown repeater:repeater "$MQTT_BROKER_FILE"

if [[ "${REGIONS:-}" ]]; then
    echo "Saving current regions to $REGIONS_FILE"
    dump-regions -o "$REGIONS_FILE"
fi

echo "openhop-backup.sh done"
