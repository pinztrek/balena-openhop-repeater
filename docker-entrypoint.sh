#!/bin/bash
echo "docker-entrypoint.sh started"

# Change ownership of GPIO devices to the 'gpio' group
# and grant read/write access to that group.
if [ -e /dev/gpiochip0 ]; then
    sudo chgrp gpio /dev/gpiochip*
    sudo chmod g+rw /dev/gpiochip*
fi

# If you also need access to gpiomem
if [ -e /dev/gpiomem ]; then
    sudo chgrp gpio /dev/gpiomem
    sudo chmod g+rw /dev/gpiomem
fi

ls -al /dev/gpi*

# Seed the radio settings if missing
if [ ! -f /var/lib/pymc_repeater/radioi-settings.json ]; then
    echo "Install radio  files..."
    sudo cp /opt/pymc_repeater/radio* /var/lib/pymc_repeater
    sudo chown repeater:repeater /var/lib/pymc_repeater/radio*
fi
# Seed the configuration if missing
if [ ! -f /etc/pymc_repeater/config.yaml ]; then
    echo "Initializing default configuration..."
    sudo cp /opt/pymc_repeater/config.yaml.example /etc/pymc_repeater/config.yaml
    sudo chown repeater:repeater /etc/pymc_repeater/config.yaml
fi

cd /etc/pymc_repeater

echo "docker-entrypoint.sh starting app"
# Now run the application
#exec "$@"
pymc-repeater ; sleep 300
echo "docker-entrypoint.sh exit"
