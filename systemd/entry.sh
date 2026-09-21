#!/bin/bash
# Container entrypoint for the systemd-managed image variant.
#
# Adapted from balena's own reference pattern (services-masterclass repo,
# systemd/printer/entry.sh) so this stays as close as possible to the
# officially supported way to run systemd as PID 1 inside a balena service:
# https://docs.balena.io/learn/more/masterclasses/services-masterclass
set -m

echo "systemd init enabled -- dumping container environment to /etc/docker.env"

# systemd causes a POLLHUP for the console FD to occur on startup once all
# other processes have stopped. This sleep keeps a process alive so console
# logging keeps working (balena's dashboard log viewer included).
sleep infinity &

# balena/docker set environment variables (OWNER, LORASCAN, SSH, etc.) on
# this process only -- systemd does not pass its own environment down to the
# units it manages. Dump it to a file our unit files pull in via
# `EnvironmentFile=-/etc/docker.env` instead.
for var in $(compgen -e); do
    printf '%q=%q\n' "$var" "${!var}"
done > /etc/docker.env

exec /lib/systemd/systemd
