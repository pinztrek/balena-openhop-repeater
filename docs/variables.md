# Environment Variables

Balena environment variables can manage most config items, eliminating the need for editing config.yaml.

Set these via the balenaCloud dashboard for your fleet or specific device to configure or manage:

***Basic***
* **OWNER:** Set to desired owner_info string, stores in config.yaml
* **NODE_NAME:** Set to desired node_name string, stores in config.yaml
* **LAT:** Set to desired lattitude string, stores in config.yaml
* **LON:** Set to desired longitude string, stores in config.yaml
* **IATA** set for broker airport code reporting (mqtt_brokers,iata_code)

***Debugging***
* **OPENHOP_RESET:** Set to `1` to restore to a default config.yaml, will trigger setup menu. Does not overwrite databases
* **OPENHOP_CLEAN:** Set to `1` to restore wipe all config / data and start fresh
* **OPENHOP_DEBUG:** Set to `1` to enable a 180-second sleep (useful for terminal access/debugging).
* **OPENHOP_DELAY:** Set to desired sleep period (useful for terminal access/debugging). Overrides default 5 second sleep when _openhop_repeater_ exits.
* **RECYCLE:** Set to desired number of seconds between forced restarts. Defaults to 21600 (6 hours). _openhop_repeater_ is stopped and the container exits (to be restarted by balena) once RECYCLE seconds elapse, or immediately if the app exits/dies on its own first.

***Advanced*** ( Typically only used for managing fleets of nodes remotely)
* **KEY_HEX** Set identity key as hex string (repeater.identity_key) — auto-converted to base64 (uses same format as the convert script)
* **KEY_BASE64** Set identity key directly as base64 string (repeater.identity_key)
* **MAXFLOODHOPS** Set to desired hop limit, (repeater.max_flood_hops)
* **ADVERT** Set to # hours for advert interval (repeater.send_advert_interval_hours)
* **ADAPTIVE** Set to true to enable adaptive advert limit, (repeater.advert_adaptive.enabled.)
* **LIMIT** Set to true to enable advert limiting, (repeater.advert_rate_limit.enabled)
* **PENALTY** Set to true to enable advert penalty box, (repeater.advert_penalty_box.enable)
* **MAXCLIENTS** Set to increase or limit the number of web clients
* **ADMIN** Set admin pw (repeater.security.admin_password) _note:_ setting this will bypass the setup dialog, so don't use it until you have been thru setup unless you want to set everything radio/region manually
* **GUEST** Set guest pw (repeater.security.guest_password)
* **READONLY** Set to true to read only access (security.allow_read_only)
* **UNSCOPED** Set to true to enable unscoped forwarding (mesh.unscoped_flood_allow)
* **PATHHASH** Set to 0 or 1 change path hash # of bytes (mesh.path_hash_mode) default is 1 for 2 byte
* **TXDELAY** Set to change TX delay factor (delays.tx_delay_factor) default is 1.25
* **EMAIL** Set for broker email (normally req'd for mqtt)  (mqtt_brokers.email)
* **POLICY** Set to `1` to enable policy support — seeds `policy.yaml` from the default example into `/etc/openhop_repeater/` if not already present. Existing policy files are never overwritten.
* **BROKER** Set to `1` to enable MQTT broker integration — merges `mqtt_broker.yaml` from `/etc/openhop_repeater/` into config.yaml (seeds from default if not present)
* **US** Set to `1` to apply US/Canada radio region defaults to config.yaml (910.525MHz / SF7 / BW62.5)
* **RADIO** Set to hardware profile name from `radio-settings.json` to configure SX1262 GPIO pin assignments (e.g. `RADIO=zebra`, `RADIO=nebrahat`). Merges profile into the `sx1262` config section.
* **PWR** Set to desired power in dbm to override radio/region defaults

***Logging***
* **SYSLOG** Set to an IP or hostname, with optional port (e.g. `192.168.1.100`, `192.168.1.100:514`, `syslog.example.com`). Port defaults to 514 if omitted. When set: starts rsyslogd, seeds `/etc/openhop_repeater/rsyslog.conf` on first run, and updates the active forwarding target on every restart via sed (other conf edits are preserved). Pipes all openhop output through `logger` tagged with `NODE_NAME`.

***Planned***
* **RADIO_REGION** Select and configure the radio region presets by specifying the entry in the presets.
* **REGION** Set repeater region configuration for packets (unrelated to the radio region above)

**Notes:**
* Setting the admin password will prevent the setup dialog from running! You'll need to setup everything manually like radio, region, etc.
* Any variables which impact config.yaml are executed prior to startup of _openhop_repeater_
* Most of the env variables control behavior that you can now set via the GUI. But if you manage multiple repeaters, it really helps to have the settings level based on your local policy.
