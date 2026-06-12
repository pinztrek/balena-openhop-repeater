#!/bin/bash
echo "docker-entrypoint.sh started"

# Change ownership of GPIO devices to the 'gpio' group
# and grant read/write access to that group.
if [ -e /dev/gpiochip0 ]; then
    echo "override gpio groups..."
    sudo chgrp gpio /dev/gpiochip*
    sudo chmod g+rw /dev/gpiochip*
fi

# If you also need access to gpiomem
if [ -e /dev/gpiomem ]; then
    echo "override gpiomem groups..."
    sudo chgrp gpio /dev/gpiomem
    sudo chmod g+rw /dev/gpiomem
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

if [[ "$OWNER" ]]; then
    echo "Set owner_info to $OWNER"
    yq -i '.repeater.owner_info = env(OWNER)' config.yaml
fi

if [[ "$NODE_NAME" ]]; then
    echo "Set owner_info to $NODE_NAME"
    yq -i '.repeater.node_name = env(NODE_NAME)' config.yaml
fi

cd /etc/pymc_repeater

echo "docker-entrypoint.sh starting app"
# Now run the application
#exec "$@"
pymc-repeater ; echo "PYMC exited, sleeping $PYMC_DELAY seconds"; sleep $PYMC_DELAY
echo "docker-entrypoint.sh exit"
