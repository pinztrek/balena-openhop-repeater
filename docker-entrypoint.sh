#!/bin/bash
echo "docker-entrypoint.sh started"

# Change ownership of GPIO devices to the 'gpio' group
# and grant read/write access to that group.
if [ -e /dev/gpiochip0 ]; then
    echo "override gpio groups..."
    sudo chgrp gpio /dev/gpiochip*
    #sudo chmod g+rw /dev/gpiochip*
    # should not need this, but debugging perms
    sudo chmod a+rw /dev/gpiochip*
fi

# Change ownership of SPI devices to the 'gpio' group
# and grant read/write access to that group.
if [ -e /dev/spidev0.0 ]; then
    echo "override spi groups..."
    sudo chgrp gpio /dev/spidev*
    #sudo chmod g+rw /dev/spidev*
    # should not need this, but debugging perms
    sudo chmod a+rw /dev/spi*
fi

# If you also need access to gpiomem
if [ -e /dev/gpiomem ]; then
    echo "override gpiomem groups..."
    sudo chgrp gpio /dev/gpiomem
    #sudo chmod g+rw /dev/gpiomem
    sudo chmod a+rw /dev/gpiomem
fi

ls -al /dev/gpi*

if [[ "$OPENHOP_DEBUG" ]] && [[ ! "$OPENHOP_DELAY" ]]; then
        OPENHOP_DELAY=180
fi

if [[ ! "$OPENHOP_DELAY" ]]; then
        OPENHOP_DELAY=5
fi
echo "delay set to $OPENHOP_DELAY"


# Configuration Paths
LIB_DIR="/var/lib/openhop_repeater"
CONFIG_DIR="/etc/openhop_repeater"
OPT_DIR="/opt/openhop_repeater"
SETTINGS_FILE="$LIB_DIR/radio-settings.json"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

sudo chown -R repeater:repeater $CONFIG_DIR


if [[ "$OPENHOP_CLEAN" ]]; then
        echo "Nuke $LIB_DIR files"
        rm -rf $LIB_DIR/repeat* $LIB_DIR/.config
        OPENHOP_RESET=1
fi

if [[ "$OPENHOP_RESET" ]]; then
        echo "Save Old Config in config.last"
        cp "$CONFIG_FILE" "$CONFIG_DIR/config.last"
        echo "Install default config.yaml"
        cp "$OPT_DIR/config.yaml.example" "$CONFIG_FILE"
fi


# Seed the radio settings if missing
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Install radio files..."
    sudo cp $OPT_DIR/radio* $LIB_DIR
    sudo chown repeater:repeater $LIB_DIR/radio*
fi
# Seed the configuration if missing
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Initializing default configuration..."
    sudo cp $OPT_DIR/config.yaml.example $CONFIG_FILE
    sudo chown repeater:repeater $CONFIG_FILE
fi

# Seed policy.yaml only if POLICY is set and no policy file exists yet
POLICY_FILE="$CONFIG_DIR/policy.yaml"
if [[ "$POLICY" ]] && [ ! -f "$POLICY_FILE" ]; then
    echo "Seeding default policy.yaml..."
    sudo cp "$OPT_DIR/policy.yaml.example" "$POLICY_FILE"
    sudo chown repeater:repeater "$POLICY_FILE"
fi

# make changes to config.yaml as needed
cd $CONFIG_DIR

if [[ "$OWNER" ]]; then
    echo "Set owner_info to $OWNER"
    yq -i '.repeater.owner_info = env(OWNER)' config.yaml
    yq -i '.mqtt_brokers.owner = env(OWNER)' config.yaml
fi

if [[ "$NODE_NAME" ]]; then
    echo "Set node_name to $NODE_NAME"
    CURRENT_NAME=$(yq '.repeater.node_name // ""' config.yaml)
    if [[ "$CURRENT_NAME" != "$NODE_NAME" ]]; then
        yq -i '.repeater.node_name = env(NODE_NAME)' config.yaml
    fi
    CURRENT_SITE=$(yq '.web.site_name // ""' config.yaml)
    if [[ -z "$CURRENT_SITE" || "$CURRENT_SITE" == "null" ]]; then
        SITE_NAME="${NODE_NAME^^}"
        export SITE_NAME
        yq -i '.web.site_name = env(SITE_NAME)' config.yaml
    fi
fi

if [[ "$LAT" ]]; then
    echo "Set LAT to $LAT"
    yq -i '.repeater.latitude = env(LAT)' config.yaml
fi

if [[ "$LON" ]]; then
    echo "Set LON to $LON"
    yq -i '.repeater.longitude = env(LON)' config.yaml
fi

if [ "$US" ]; then
    echo "Set radio to US defaults"
    yq -iP '
      .radio.bandwidth = 62500 |
      .radio.coding_rate = 5 |
      .radio.frequency = 910525000 |
      .radio.implicit_header = false |
      .radio.preamble_length = 17 |
      .radio.spreading_factor = 7 |
      .radio.tx_power = 14 
    ' $CONFIG_FILE 
fi

if [ "$RADIO" ]; then
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "Error: $SETTINGS_FILE not found."
        exit 1
    fi

    # Assume sx1262 for now
    echo "Set radio to sx1262"
    echo '---------------------debug------------'
    yq -iP '
      .radio_type = "sx1262"
    ' $CONFIG_FILE 


    if [ "$RADIO" = "nebra" ]; then
        RADIO="nebrahat"
        echo "Detected 'nebra', updated radio to 'nebrahat'."
    fi


    # Now read the radio presets, and then save into config.yaml
    # Have to do this in two steps due to yq funkiness
    echo Lookup $RADIO and update values into $CONFIG_FILE

    RADIO_JSON=$(jq -c ".hardware.$RADIO | del(.name, .tx_power, .preamble_length)" "$SETTINGS_FILE")
    export RADIO_JSON
    echo "Read JSON: $RADIO_JSON"
    echo "As YAML:"
    echo "$RADIO_JSON" | yq -pj -P '.'
    echo "Writing to $CONFIG_FILE"
    yq -iP '.sx1262 *= (strenv(RADIO_JSON) | from_json)' "$CONFIG_FILE"
fi

# Turn power down on nebrahat
if [ "$RADIO" = "nebrahat" ]; then
    echo "Lower radio power for nebrahats"
    yq -iP "
      .radio.tx_power = 8
    " $CONFIG_FILE
fi

# allow power override though
if [ "$PWR" ]; then
    echo "Set radio power to to $PWR"
    yq -iP "
      .radio.tx_power = $PWR
    " $CONFIG_FILE
fi


if [[ "$KEY_HEX" ]]; then
    echo "Set KEY_HEX to $KEY_HEX"
    #KEY_BASE64=$(python3 -c "import base64, binascii; print(base64.b64encode(binascii.unhexlify('$KEY_HEX')).decode())")

    KEY_BASE64=$(python3 -c "import sys, base64; print(base64.b64encode(bytes.fromhex('$KEY_HEX')).decode())")
    echo "$KEY_HEX"
    echo "$KEY_BASE64"
    export KEY_BASE64
fi

if [[ "$KEY_BASE64" ]]; then
    echo "Set KEY_BASE64 to $KEY_BASE64"
    yq -i '.repeater.identity_key = env(KEY_BASE64) | .repeater.identity_key tag="!!binary"' config.yaml
fi

if [[ "$MAXFLOODHOPS" ]]; then
    echo "Set MAXFLOODHOPS to $MAXFLOODHOPS"
    yq -i '.repeater.max_flood_hops = env(MAXFLOODHOPS)' config.yaml
fi

if [[ "$MAXCLIENTS" ]]; then
    echo "Set MAXCLIENTS to $MAXCLIENTS"
    yq -i '.repeater.security.max_clients = env(MAXCLIENTS)' config.yaml
fi

if [[ "$ADMIN" ]]; then
    echo "Set ADMIN pw to $ADMIN"
    yq -i '.repeater.security.admin_password = env(ADMIN)' config.yaml
fi

if [[ "$GUEST" ]]; then
    echo "Set GUEST pw to $GUEST"
    yq -i '.repeater.security.guest_password = env(GUEST)' config.yaml
fi

if [[ "$READONLY" ]]; then
    echo "Set READONLY to $READONLY"
    yq -i '.repeater.security.allow_read_only = env(READONLY)' config.yaml
fi

if [[ "$ADVERT" ]]; then
    echo "Set ADVERT to $ADVERT"
    yq -i '.repeater.send_advert_interval_hours = env(ADVERT)' config.yaml
fi

if [[ "$ADAPTIVE" ]]; then
    echo "Set ADAPTIVE to $ADAPTIVE"
    yq -i '.repeater.advert_adaptive.enabled = env(ADAPTIVE)' config.yaml
fi

if [[ "$LIMIT" ]]; then
    echo "Set LIMIT to $LIMIT"
    yq -i '.repeater.advert_rate_limit.enabled = env(LIMIT)' config.yaml
fi

if [[ "$PENALTY" ]]; then
    echo "Set PENALTY to $PENALTY"
    yq -i '.repeater.advert_penalty_box.enabled = env(PENALTY)' config.yaml
fi

if [[ "$UNSCOPED" ]]; then
    echo "Set UNSCOPED to $UNSCOPED"
    yq -i '.mesh.unscoped_flood_allow = env(UNSCOPED)' config.yaml
fi

if [[ "$PATHHASH" ]]; then
    echo "Set PATHHASH to $PATHHASH"
    yq -i '.mesh.path_hash_mode = env(PATHHASH)' config.yaml
fi

if [[ "$TXDELAY" ]]; then
    echo "Set TXDELAY to $TXDELAY"
    yq -i '.delays.tx_delay_factor = env(TXDELAY)' config.yaml
fi

if [[ "$IATA" ]]; then
    echo "Set IATA to $IATA"
    yq -i '.mqtt_brokers.iata_code = env(IATA)' config.yaml
fi

if [[ "$EMAIL" ]]; then
    echo "Set EMAIL to $EMAIL"
    yq -i '.mqtt_brokers.email = env(EMAIL)' config.yaml
fi

# Update the password if one was provided
if [[ "$PASSWD" ]]; then
    echo "Setting password to $PASSWD"

    # Remove immutability if it exists to allow password update
    chattr -i /etc/shadow 2>/dev/null
    # Apply the password from a Balena Environment Variable (set in dashboard)
    if [ -n "$PASSWORD" ]; then
        echo "repeater:$PASSWORD" | chpasswd
    fi
    chattr +i /etc/shadow 2>/dev/null
fi

if [[ "$BROKER" ]]; then
    if [ ! -f "$CONFIG_DIR/mqtt_broker.yaml" ]; then
        echo "Copy sample mqtt_broker.yaml file"
        cp $OPT_DIR/mqtt* $CONFIG_DIR
    fi
    echo "Setting up mqtt brokers"
    yq -i '.mqtt_brokers.brokers = [load("mqtt_broker.yaml")]' config.yaml
fi


# start ntp, defaults are fine
echo "Starting ntpd"
sudo /usr/sbin/ntpd 

# start sshd
if [[ "$SSH" ]]; then
    echo "Starting sshd"
    sudo /usr/sbin/sshd 
fi

if [[ "$CLOUDFLARE" ]]; then
    echo "Starting cloudflared"
    echo cloudflared --loglevel warn tunnel run --token "$CLOUDFLARE"
    (sleep 20 ; /usr/local/bin/cloudflared --loglevel warn \
    tunnel run --token "$CLOUDFLARE") &
    #sudo /usr/local/bin/cloudflared --loglevel warn tunnel run --token "$CLOUDFLARE"
fi



grep -q 'pymc_repeater' "$CONFIG_FILE" && sed -i 's|pymc_repeater|openhop_repeater|g' "$CONFIG_FILE"

echo "docker-entrypoint.sh starting app"
# Now run the application
#exec "$@"
openhop-repeater
echo "OPENHOP exited, backing up $LIB_DIR to $CONFIG_DIR/backup"
mkdir -p "$CONFIG_DIR/backup"
cp "$LIB_DIR"/rep* "$CONFIG_DIR/backup/"
echo "sleeping $OPENHOP_DELAY seconds"
sleep $OPENHOP_DELAY
echo "docker-entrypoint.sh exit"
