# Running under systemd (experimental)

An alternate build that runs real systemd as PID 1 inside the container,
following balena's own documented pattern for multi-process services
([services masterclass](https://docs.balena.io/learn/more/masterclasses/services-masterclass),
[reference repo](https://github.com/balena-io/services-masterclass/tree/master/systemd)).
This lets `openhop-repeater` and `openhop-plugin-manager` run as independent
systemd units you can `systemctl stop`/`start`/`restart` without touching the
rest of the container, and reuses the project's own stock unit files
(`openhop-dev/openhop_repeater`'s `openhop-repeater.service` and
`repeater/plugins/openhop-plugin-manager.service`) rather than inventing new
ones.

This is the default build on the `systemd` branch -- `Dockerfile.template`/
`docker-compose.yml` are this variant. The pre-systemd build is kept as
`Dockerfile.classic.template` + `docker-compose.classic.yml` for
reference/rollback:

```
docker compose -f docker-compose.classic.yml build   # pre-systemd
docker compose build                                  # systemd (default here)
```

## What changed vs. the classic build

- **Install layout**: `openhop_repeater` and `lorascan` are installed into a
  real venv at `/opt/openhop_repeater/venv` instead of the base image's
  system Python, so upstream's unit files -- which hardcode
  `/opt/openhop_repeater/venv/bin/...` -- work with just one addition each
  (see below).
- **Entrypoint**: `systemd/entry.sh` replaces `docker-entrypoint.sh` as the
  container `ENTRYPOINT`. balena/docker env vars only reach PID 1's own
  process, not the units systemd manages, so entry.sh dumps its environment
  to `/etc/docker.env` before `exec`-ing systemd; every unit that needs env
  vars adds `EnvironmentFile=-/etc/docker.env`.
- **Config templating**: everything `docker-entrypoint.sh` used to do before
  launching the app (env-var -> `config.yaml` mutations, seeding
  policy/regions/mqtt_broker files, starting ntpd/sshd/rsyslogd/cloudflared)
  is now `scripts/openhop-configure.sh`, run once per boot by
  `openhop-configure.service` (`Type=oneshot`, `RemainAfterExit=yes`),
  ordered `Before=openhop-repeater.service`.
- **The boot-time LORASCAN survey** is `scripts/openhop-lorascan-boot.sh` /
  `openhop-lorascan-boot.service`, same recipe as `scripts/scan500` -- also a
  oneshot ordered before the repeater starts.
- **RECYCLE** (the periodic forced restart) is `openhop-recycle.timer` +
  `.service` (`systemctl try-restart openhop-repeater.service`) instead of
  killing the app and letting the whole container exit/restart.
  `openhop-configure.sh` writes a drop-in overriding the timer's period from
  `$RECYCLE`, or disables the timer if `RECYCLE=false`.
- **State backup on stop** (dumping `repeater.db`/regions/mqtt_broker.yaml
  back to the config volume) is `scripts/openhop-backup.sh`, wired in as
  `ExecStopPost=` on `openhop-repeater.service` -- it now runs on every stop
  or restart of that unit specifically, not only on container exit.
- **Journal forwarding**: when `SYSLOG` is set, `openhop-configure.sh` also
  turns on journald's `ForwardToSyslog=yes`, so rsyslogd forwards every
  unit's journal output (repeater, plugin manager, the config/lorascan
  oneshots) to the remote target -- replacing the old single `exec > >(tee
  ... logger)` redirect, which only covered the app's own stdout.

## tmpfs / persistent storage

systemd requires `/run` and `/run/lock` as tmpfs; `/tmp` is tmpfs'd too.
journald is deliberately left in its default **volatile-only** mode (no
`/var/log/journal` directory is created, so it logs to `/run/log/journal`
instead) -- this, plus the tmpfs mounts, removes the two most
constantly-written directories on a systemd system from the SD
card/eMMC entirely.

State that must actually survive a restart -- `config.yaml`, `repeater.db`,
lorascan's own config/profiles and scan databases -- stays on the existing
config/data volumes exactly as before (see the `LORASCAN_DIR` /
`LORASCAN_DB_DIR` split from the lorascan work: config/profiles under
`/etc/openhop_repeater/lorascan`, scan databases under
`/var/lib/openhop_repeater/lorascan`). Nothing that needs to persist is on
tmpfs.

**ZFS**: raised as an alternative to tmpfs for directories that are both
frequently written *and* need to persist (wear-levelling, snapshots,
compression). Not pursued here -- balenaOS's data partition is managed by
balenaOS itself and its Yocto-built kernel does not ship ZFS modules, so
using ZFS would mean a custom balenaOS build with an out-of-tree ZFS kernel
module: a host-image-level project, not something this container's
Dockerfile can do on stock balenaOS. Worth a separate look if it's still
wanted, but out of scope for this branch.

## Known balena-specific caveats

- Requires `privileged: true` (already set, for GPIO/SPI/USB access
  regardless of systemd) -- balena's own reference example for this pattern
  uses the same setting.
- `STOPSIGNAL 37` (`RTMIN+3`) is required for systemd to shut down cleanly;
  balena/Docker's default `SIGTERM` does not stop it gracefully.
- Older balenaOS/balena-engine versions have a known bug ("Failed to trim/
  attach to compat systemd cgroup") triggered by restarting balena-engine
  itself while a systemd-in-container service is running; recovery is
  deleting and letting the supervisor recreate the container. Not something
  this repo can fix -- worth checking the balenaOS version on target
  devices before relying on this in production.

## Not done yet (explicitly out of scope for this pass)

- **On-demand lorascan start/stop**: only the boot-time survey
  (`openhop-lorascan-boot.service`) exists so far. A `lorascan-scan.service`
  (or a templated `lorascan-scan@.service`) that can be started/stopped at
  will, independent of boot, is the next step here.
- ntpd/sshd/rsyslogd/cloudflared are still started the old way (plain
  background processes from `openhop-configure.sh`), not as their own
  supervised systemd units (e.g. Debian's own `ssh.service`/
  `rsyslog.service`). Functionally unchanged from the classic build, but not
  "real" systemd services -- a reasonable follow-up once the core
  openhop-repeater/plugin-manager conversion has been run on real hardware.
- `enable`/`disable` toggling was explicitly out of scope for this pass
  (units are enabled once at image build time); only start/stop was asked
  for.
- None of this has been run on real balena hardware yet -- it's built from
  documented systemd/balena behavior and upstream's own shipped unit files,
  not verified end-to-end in this environment (no local Docker/systemd
  available to test against).
