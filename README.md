# Jetson Orin Nano Boot Environment

This repository provides a Dockerized, fully automated environment for flashing and configuring the Nvidia Jetson Orin Nano via the Nvidia SDK Manager. By running this in a Docker container, it ensures that your host operating system (such as Arch Linux or another non-Ubuntu distribution) does not need Ubuntu-specific deb packages or desktop dependencies installed. Note that because flashing requires raw USB access, kernel NFS mounting, and USB ethernet routing, the container runs with `--privileged` and `--net=host` to interact directly with the hardware.

## Key Features & Automated Fixes
This environment is configured to automatically resolve several known SDK Manager bugs and network restrictions:
* **Host Conflict Resolution & Auto-Restore:** Safely stops conflicting host `rpcbind` and `nfs-server` services before launching, and automatically restores them along with X11 access controls when the script exits.
* **99% Hang Fix:** Automatically monitors and kills the `rpc.mountd` zombie process that holds pipes open, which previously caused the SDK Manager to hang indefinitely at 99% during the flash phase.
* **Network & Firewall Bypass:** Injects a custom `device_mode_host_setup.sh` script to ensure the Jetson target has internet access during component installation:
  * Overrides Docker's default `DROP` policy on the `FORWARD` chain.
  * Enforces a TTL of 64 (`-j TTL --ttl-set 64`) to bypass mobile hotspot tethering restrictions.
  * Runs a local `dnsmasq` proxy inside the container forwarding Jetson DNS queries to the host's upstream DNS, bypassing strict ISP Port-53 blocks.
* **One-Shot Execution:** Everything runs via a single `./jetson_boot.sh` script.

## Prerequisites

### For Linux Users (Arch Linux, Ubuntu, etc.)
* Docker installed and running.
* Your user must have permissions to run Docker (or run with `sudo`).

### For Windows Users (WSL2)
* Docker Desktop for Windows installed with WSL2 backend.
* [usbipd-win](https://github.com/dorssel/usbipd-win) installed on Windows to pass the Type-C USB device into WSL2.
* **Kernel Note:** Stock WSL2 kernels lack the `nfsd` kernel module required by L4T network flashing. WSL2 usage requires a custom kernel compiled with `CONFIG_NFSD=y`.

## Step 1: Download SDK Manager
NVIDIA requires a developer account to download the SDK Manager.
1. Go to the [NVIDIA SDK Manager Download Page](https://developer.nvidia.com/nvidia-sdk-manager).
2. Download the `.deb` file for Ubuntu (e.g., `sdkmanager_2.x.x_amd64.deb`).
3. Place the `.deb` file directly in this folder (`jetson_boot`).

## Step 2: Put Jetson in Recovery Mode
1. Ensure your Jetson Orin Nano is powered off.
2. Place a jumper across the `FC REC` (Force Recovery) pin and the `GND` (Ground) pin.
3. Plug in the power supply.
4. Connect the Jetson to your PC via the USB Type-C port.
5. Remove the jumper.

*(Check that it is detected using `lsusb` on Linux. You should see `NVIDIA Corp.`).*

**Windows Users Only:** 
Open a Command Prompt as Administrator and run:
```cmd
usbipd list
usbipd bind --busid <BUS_ID>
usbipd attach --wsl --busid <BUS_ID>
```
*(Replace `<BUS_ID>` with the bus ID of the NVIDIA device from the list).*

## Step 3: Run the Automation Script
Open a terminal in this folder and run:
```bash
./jetson_boot.sh
```

The script will build the docker image automatically, handle network spoofing and zombie process cleanup internally, and launch the SDK Manager GUI on your screen.
Once the UI opens, just follow the SDK Manager steps. The flashing process and the subsequent Target Components installation (via SSH) will execute seamlessly.

## Notes
* The container runs as a non-root user `nvidia` with `sudo` privileges.
* The container keeps running after the SDK Manager UI is closed. Press `Ctrl+C` in the terminal to stop it; it is then removed automatically (`--rm`), preserving your disk space.

## Troubleshooting
* **Host Components Installation Fails:** If you encounter errors while installing "Host Components" in the SDK Manager, the downloaded files might be corrupted. You can fix this by clearing the mapped directory on your host:
  ```bash
  sudo rm -rf nvidia_sdk/*
  ```
