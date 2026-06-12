# 🚧 UNDER CONSTRUCTION 🚧

# <kbd><img src="assets/images/balena-icon.png" alt="balena.io logo" width="60" style="border-radius:45%"/></kbd> <kbd><img src="assets/images/pymc.png" alt="pymc_repeater logo" width="60" style="border-radius:45%" /></kbd> balena-pymc-repeater

This project provides a containerized environment for running and managing `pymc_repeater` on balena-enabled hardware.

## The goal for this project is to be able to stand up a `pymc_repeater` container and completely manage it via balenaCloud with minimal hand-editing of config files and no container-level code changes.

## Key Features:
* **Simplified Management:** Utilizes environment variables to configure behavior and application settings.
* **Persistent Configuration:** Configuration file structures are persistent and read/write, ensuring settings survive updates.
* **Template-Based Setup:** If an existing `config.yaml` is not found, one is automatically created from `config.yaml.example`.
* **Flexible Configuration:** Supports device-specific presets and easy selection of supported configurations.
* **Maintenance & Debug Mode:** Includes support for debugging and terminal access to the container for manual adjustments when needed.

# Usage:

## 1. Create a free tier account at [balena-cloud.com](https://dashboard.balena-cloud.com/login)

## 2. Deploy by clicking the URL/Button below:
[![balena deploy button](assets/images/deploy.svg)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/pinztrek/balena-pymc-repeater)
### OR for bleeding edge:
[![balena deploy button](assets/images/deploy.svg)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/pinztrek/balena-pymc-repeater-dev)

## 3. Once logged into balena, it will create a fleet for *balena-pymc-repeater*
## 4. Create your device and download the disk image
* Select your device type (e.g., Raspberry Pi 3 or similar).
* Download the image and flash it to a microSD or eMMC using Balena Etcher or similar tools.

## 5. Set Environment Variables
Set these via the balenaCloud dashboard for your fleet or specific device:
* **DEBUG:** Set to `1` to enable a default 300-second sleep (useful for terminal access/debugging).

## 6. Power up your device
* The environment will download and start up automatically.
* Once running, you can access the container terminal via the balenaCloud dashboard to run commands or inspect logs.

# Controlling Behavior with Env Variables:
Balena Device or Fleet environment variables can be used to set configuration and change behavior:
* **DEBUG:** Set to `1` to keep the container alive for debugging.

# Configuration:
The application expects a `config.yaml` file. The container is designed to check for this file on boot; if missing, it will seed the directory with a template. You can mount your persistent volumes to `/etc/pymc_repeater` to ensure your configuration persists across deployments.

> <img src="assets/images/balena-terminal-pymc.png" alt="balena terminal" width="650"/>

# Release versions
Any updates for *balena-pymc-repeater* will be automatically deployed to your devices. If an update creates issues, you can pin to a prior release using the balena releases page.

---
*Maintained by [pinztrek](https://github.com/pinztrek/balena-pymc-repeater)*
