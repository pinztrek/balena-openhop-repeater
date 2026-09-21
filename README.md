
# <kbd><img src="assets/images/balena-icon.png" alt="balena.io logo" width="60" style="border-radius:45%"/></kbd> <kbd><img src="assets/images/openhop.png" alt="openhop_repeater logo" width="60" style="border-radius:45%" /></kbd> balena-openhop-repeater

This project provides a containerized environment for running and managing `openhop_repeater` on balena-enabled hardware.

## The goal for this project is to be able to stand up a `openhop_repeater` container and completely manage it via balenaCloud with minimal hand-editing of config files and no container-level code changes.

Specifically, no arcane docker/linux knowledge is required (though some linux awareness sometimes helps for advanced changes). But it's close to turnkey. 

## Key Features:
* **Simplified Management:** Utilizes environment variables to configure behavior and application settings for the corner cases where you don't want to use the openhop web gui. 
* **Automatic Deployments:** Release and dev branches, will automatically update devices when pushed unless you pin to a specific release
* **Persistent Configuration:** Configuration file structures are persistent and read/write, ensuring settings survive updates.
* **Template-Based Setup:** If an existing `config.yaml` is not found, one is automatically created from `config.yaml.example`.
* **Maintenance & Debug Mode:** Includes support for debugging and terminal access to the container for manual adjustments when needed.
* **2 stage docker build:** Builds the code, then deploys to a minimal docker image. Run image is only ~400MB!
* **Can be manually edited via Balena terminal** Nano, vi, etc are available to edit config files in the balena terminal

## Current Status:
* **v1.1.1-beta** OpenHop fully operational, extending remote mgt options

### 🚧 UNDER CONSTRUCTION 🚧
* **dev branch** adding more obscure variable support in addition to web/manual config

### Known Issues:
* USB devices have not been tested yet and may have permission issues

# Usage:

## 1. Create a free tier account at [balena-cloud.com](https://dashboard.balena-cloud.com/login)

## 2. Deploy by clicking the URL/Button below:
[![balena deploy button](assets/images/deploy.svg)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/pinztrek/balena-openhop-repeater)
### OR for bleeding edge dev balena branch (unstable):
[![balena deploy button](assets/images/deploy.svg)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/pinztrek/balena-openhop-repeater-dev)

## 3. Once logged into balena, it will create a fleet for *balena-openhop-repeater*
## 4. Create your device and download the disk image
* Select your device type (e.g., Raspberry Pi 3, 4 or similar).
* Download the image and flash it to a microSD or eMMC using Balena Etcher or similar tools.


## 5. Power up your device
* The environment will download and start up automatically.

_Note:_ The first time it boots it has to download the full OS, so it can take a while. Later updates will be faster. 
* Once running, you can access the container terminal via the balenaCloud dashboard to run commands or inspect logs.
* You'll want to note the local IP address on the dashboard if you do not know it already

## 6. Access the OpenHop web control plane GUI
* Using your browser navigate to: **http://your_IP_addr:8000**
* The OpenHop web gui should load and start the setup dialog. Work through this, selecting radio, region, etc. Note the current build dropped the Nebrahat, which I will readd. 
* When it's complete, OpenHop will restart the container. There is a sleep delay when OpenHop exits which will need to expire, or you can hit the recycle button on the balena dashboard to restart the container. 
* It'll come up running the gui, and you should start seeing packets if all is set correctly
* If you need to adjust the config, use the terminal, select the openhop container, and it will give you a shell prompt. All editable files should be accessible as the _repeater_ user, but sudo is available if needed. 

# Controlling Behavior with Env Variables:

Balena environment variables can manage most configuration items, eliminating the need for manual gui config or editing config.yaml.

The big win with this approach is if you are operating several repeaters you can level configurations across your fleet. Likewise, you can standup a new repeater and not have to do any manual configuration just by setting it's name, radio type, lat/lon, etc. via env variables. 

See [docs/variables.md](docs/variables.md) for the full listi of variables and how to use.

# Configuration:
The application expects a `config.yaml` file. The container is designed to check for this file on boot; if missing, it will seed the directory with a template. 

You can ssh or scp _out_ from the terminal window and use them to copy in existing files:
_scp myuserid@xx.xx.xx.xx:mydir/config.yaml ._

# Device I/O considerations:
Things like DT Overlays and parameters are handled in the fleet or device configuration menu. 
* **Nebrahats** Typically need DT overlay set to "spi0-0cs" and the DT parames set to **not** have spi=on set. (You may or may not need i2c_arm=on set)
* **Zebra hats** Seemed to work with DT overlay set to "spi0-0cs" and the DT params set to "i2c_arm=on","spi=on"
* **USB** USB devices should work, but I have not tested them. There may be some permission tweaks needed in the Balena dockerentry.sh to sort that. Let me know if you see issues or change needed.

# Persistant Volumes:
**read / write:**
* **/etc/openhop_repeater** mainly contains config,yaml, but can hold backup configs, etc
* **/var/lib/openhop_repeater** main runtime data dir for databases, also home dir for the **repeater** user. By default the identity key is stored in a hidden folder here unless overridden in _config.yaml_

**read only:**
* **/opt/lib/openhop_repeater** has normal default files from build
* **/usr/local/bin** has support scripts, including the normal script to import a private key of your chosing. 
* **/usr/local** normal python pip install locations for libs and executables (lib and bin respectively)


# Balena Terminal: 
<img src="assets/images/balena-terminal-openhop.png" alt="balena terminal" width="650"/> Use the balena terminal to hand edit or manipulate the running environment.

# Release versions

The "Deploy to Balena" link creates a fleet with the latest release automatically. 

Any updates for *balena-openhop-repeater* will be automatically deployed to your devices when a push is initiated for your fleet. This is typically done by doing a git push  to a special origin remote to balena. 

Note that when you push *balena-openhop-repeater* it will pull the latest *OpenHop-repeater* code and include it. You can manually override to a specific release of *OpenHop-repeater* if needed. 

There are other methods to push updates, see the next topic. 

If an update creates issues, you can pin to a prior release using the balena releases page.

# Updating Your OpenHop Install

Getting an OpenHop instance running with minimal interaction / Linux / git knowledge is the main focus. 

But, once running, you will periodically want to refresh your fleet with the latest code from the [openhop-dev/openhop_repeater](https://github.com/openhop-dev/openhop_repeater) repo.

There are multiple ways to do this, see [docs/update.md](docs/update.md) for update procedures.

# AI acknowledgement:
This project is hand written. I do occasionally use claude-code to help make tedious revisions or help troubleshoot obscure issues. But it is **NOT** vibe coded. And all edits are reviewed before execution. 

# Credit:
*  [LLoyd openhop-dev](https://github.com/openhop-dev) The excellent openhop_repeater project itself is why we are here. [https://github.com/openhop-dev/openhop_repeater](https://github.com/openhop-dev/openhop_repeater)
*  [Michael Gillet's](https://github.com/migillett) (migillett) docker contribution to the openhop_repeater code [https://github.com/migillett/openhop_repeater](https://github.com/migillett/openhop_repeater) informed inital prototype of this balena based project as I ported from my balena-meshtasticd project. There are still tidbits leveraged in the build. 

---
*Maintained by [pinztrek](https://github.com/pinztrek/balena-openhop-repeater)*
