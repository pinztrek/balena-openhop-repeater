#!/opt/openhop_repeater/venv/bin/python
"""Pre-install a bundled plugin wheel via the real PluginManager API.

Run once per boot by openhop-plugin-preinstall.service, before
openhop-plugin-manager.service starts. Uses the same install()/enable() calls
the live Plugins page would (repeater.plugins.manager.PluginManager), rather
than hand-writing the plugin storage layout, so this stays correct across
plugin-manager releases.

Idempotent by design, but only in the "leave it alone" direction: once a
plugin has ever been installed (by us or by the user), current_version()
returns non-None and this script does nothing -- it never re-installs,
re-enables, or downgrades a plugin the user has since updated or disabled
via the live Plugins page.
"""
from __future__ import annotations

import glob
import sys
from pathlib import Path
from typing import Any, Optional

CONFIG_PATH = "/etc/openhop_repeater/config.yaml"
BUNDLED_WHEEL_GLOB = "/opt/openhop_repeater/plugins/*.whl"


def _load_config(config_path: Optional[str]) -> dict[str, Any]:
    if not config_path:
        return {}
    try:
        from repeater.config import load_config

        return load_config(config_path)
    except Exception:
        import yaml

        path = Path(config_path)
        if not path.is_file():
            return {}
        with open(path, encoding="utf-8") as fh:
            data = yaml.safe_load(fh) or {}
        return data if isinstance(data, dict) else {}


def main() -> int:
    from repeater.plugins.manager import PluginManager
    from repeater.plugins.manifest import load_manifest_from_wheel
    from repeater.plugins.runtime import PluginRuntime
    from repeater.plugins.storage import PluginStorage, resolve_plugins_root

    wheels = sorted(glob.glob(BUNDLED_WHEEL_GLOB))
    if not wheels:
        print(f"openhop-plugin-preinstall: no wheel found at {BUNDLED_WHEEL_GLOB}, nothing to do")
        return 0
    wheel_path = Path(wheels[-1])

    manifest = load_manifest_from_wheel(wheel_path)
    config = _load_config(CONFIG_PATH)
    plugins_root = resolve_plugins_root(config)
    storage = PluginStorage(plugins_root)

    if storage.current_version(manifest.id) is not None:
        print(f"openhop-plugin-preinstall: {manifest.id} already installed, leaving as-is")
        return 0

    runtime = PluginRuntime(storage)
    manager = PluginManager(storage, runtime)

    print(f"openhop-plugin-preinstall: installing {manifest.id}@{manifest.version} from {wheel_path}")
    manager.install(wheel_path)
    manager.enable(manifest.id)
    print(f"openhop-plugin-preinstall: {manifest.id}@{manifest.version} installed and enabled")
    return 0


if __name__ == "__main__":
    sys.exit(main())
