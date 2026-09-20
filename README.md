# Jetson Orin Nano Boot Environment (Recently, it is not working)

This repository provides a Dockerized, fully automated environment for flashing and configuring the Nvidia Jetson Orin Nano via the Nvidia SDK Manager. By running this in a Docker container, it ensures that your host operating system (whether it is Arch Linux, another Linux distro, or Windows via WSL2) remains clean and unaffected by SDK dependencies.

## Prerequisites

### For Linux Users (Arch Linux, Ubuntu, etc.)
* Docker installed and running.
* Your user must have permissions to run Docker (or run with `sudo`).

### For Windows Users (WSL2)
* Docker Desktop for Windows installed with WSL2 backend.
* [usbipd-win](https://github.com/dorssel/usbipd-win) installed on Windows to pass the Type-C USB device into WSL2.

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

## Step 3: Run the Automation Script (One-Shot!)
We have fully automated the image building, display permissions, NFS/rpcbind host conflict resolution, and container launching into a single script.

Simply open a terminal in this folder and run:
```bash
./jetson_boot.sh
```

The script will:
* Build the docker image automatically if it doesn't exist.
* Check if the SDK Manager `.deb` file is present.
* Stop conflicting host services (`rpcbind.socket`, `rpcbind`, `nfs-server`) safely.
* Load the necessary kernel modules (`nfsd`).
* Set up X11 display permissions.
* Automatically handle network spoofing and zombie process cleanup internally.
* Launch the SDK Manager GUI on your screen.

Once the UI opens, just follow the SDK Manager steps. The flashing process and the subsequent Target Components installation (via SSH) will execute seamlessly.

## Notes
* The container runs as a non-root user `nvidia` with `sudo` privileges.
* When you close the SDK Manager UI, the container will automatically delete itself cleanly (`--rm`), preserving your disk space.

## Troubleshooting
* **Host Components Installation Fails:** If you encounter errors while installing "Host Components" in the SDK Manager, the downloaded files might be corrupted. You can fix this by clearing the mapped directory on your host:
  ```bash
  sudo rm -rf nvidia_sdk/*
  ```

## Proxy Configuration
If you are behind a proxy, you can modify the `docker run` command inside `jetson_boot.sh` by adding:
```bash
  -e http_proxy=http://<proxy-ip>:<port> \
  -e https_proxy=http://<proxy-ip>:<port> \
```
