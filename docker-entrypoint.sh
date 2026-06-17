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

if [[ "$PYMC_DEBUG" ]] && [[ ! "$PYMC_DELAY" ]]; then
        PYMC_DELAY=180
fi

if [[ ! "$PYMC_DELAY" ]]; then
        PYMC_DELAY=5
fi
echo "delay set to $PYMC_DELAY"


cfgdir="/etc/pymc_repeater"
installdir="/opt/pymc_repeater"
rundir="/opt/pymc_repeater"

sudo chown -R repeater:repeater $cfgdir


if [[ "$PYMC_CLEAN" ]]; then
        echo "Nuke $rundir files"
        rm -rf $rundir/repeat* $rundir/.config
        PYMC_RESET=1
fi

if [[ "$PYMC_RESET" ]]; then
        echo "Save Old Config in config.last"
        cp "$cfgdir"/config.yaml "$cfgdir"/config.last
        echo "Install default config.yaml"
        cp "$installdir"/config.yaml.example "$cfgdir"/config.yaml
fi


# Seed the radio settings if missing
if [ ! -f /var/lib/pymc_repeater/radio-settings.json ]; then
    echo "Install radio files..."
    sudo cp /opt/pymc_repeater/radio* /var/lib/pymc_repeater
    sudo chown repeater:repeater /var/lib/pymc_repeater/radio*
fi
# Seed the configuration if missing
if [ ! -f /etc/pymc_repeater/config.yaml ]; then
    echo "Initializing default configuration..."
    sudo cp /opt/pymc_repeater/config.yaml.example /etc/pymc_repeater/config.yaml
    sudo chown repeater:repeater /etc/pymc_repeater/config.yaml
fi

# make changes to config.yaml as needed
cd /etc/pymc_repeater

if [[ "$OWNER" ]]; then
    echo "Set owner_info to $OWNER"
    yq -i '.repeater.owner_info = env(OWNER)' config.yaml
    yq -i '.mqtt_brokers.owner = env(OWNER)' config.yaml
fi

if [[ "$NODE_NAME" ]]; then
    echo "Set node_name to $NODE_NAME"
    yq -i '.repeater.node_name = env(NODE_NAME)' config.yaml
fi

if [[ "$LAT" ]]; then
    echo "Set LAT to $LAT"
    yq -i '.repeater.latitude = env(LAT)' config.yaml
fi

if [[ "$LON" ]]; then
    echo "Set LON to $LON"
    yq -i '.repeater.longitude = env(LON)' config.yaml
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
    yq -i '.repeater.security.guest_password = env(ADMIN)' config.yaml
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
    if [ ! -f /etc/pymc_repeater/mqtt_broker.yaml ]; then
        echo "Copy sample mqtt_broker.yaml file"
        cp /opt/pymc_repeater/mqtt* /etc/pymc_repeater
    fi
    echo "Setting up mqtt brokers"
    yq -i '.mqtt_brokers.brokers = [load("/etc/pymc_repeater/mqtt_broker.yaml")]' config.yaml
    
fi


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



cd /etc/pymc_repeater

echo "docker-entrypoint.sh starting app"
# Now run the application
#exec "$@"
pymc-repeater ; echo "PYMC exited, sleeping $PYMC_DELAY seconds"; sleep $PYMC_DELAY
echo "docker-entrypoint.sh exit"
