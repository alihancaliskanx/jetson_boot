# Jetson Orin Nano Boot Environment

This repository provides a Dockerized environment for flashing and configuring the Nvidia Jetson Orin Nano via the Nvidia SDK Manager. By running this in a Docker container, it ensures that your host operating system (whether it is Arch Linux, another Linux distro, or Windows via WSL2) remains clean and unaffected by SDK dependencies.

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
2. Download the `.deb` file for Ubuntu (e.g., `sdkmanager_1.9.4-10816_amd64.deb`).
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

## Step 3: Build the Docker Image
In this folder, open a terminal and run:
```bash
docker build -t jetson-boot-env .
```

## Step 4: Run the Docker Container
Run the container, passing through the USB devices and mounting this folder so it can install the `.deb` file.

**For Linux and WSL2:**
```bash
docker run -it \
    --privileged \
    -v /dev/bus/usb:/dev/bus/usb \
    -v /dev:/dev \
    -v $(pwd):/sdk \
    --net=host \
    jetson-boot-env
```

## Step 5: Flash the Jetson
Once the container starts, it will automatically install the SDK Manager `.deb` file found in the `/sdk` directory and launch the SDK Manager CLI.

Follow the on-screen instructions in the CLI to login, select **JetPack 6 (Ubuntu 22.04)**, and flash your Orin Nano.

## Notes
* You can pass specific arguments to the sdkmanager CLI by appending them to the docker run command, for example: `docker run ... jetson-boot-env --cli --login-type devzone`.
* The container runs as a non-root user `nvidia` with `sudo` privileges.
