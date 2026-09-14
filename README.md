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

## Step 4: Enable NFS Server on Host (Required for Jetson Flash)
Because the Jetson Orin Nano uses `initrd` flashing over a temporary network interface, the NFS server must be running. Due to Docker networking limitations, it is best to run this natively on your host machine.
Run the following on your Linux host:
```bash
sudo touch /etc/exports
sudo systemctl enable --now rpcbind nfs-server
```
*(If the command fails, you may need to install your distro's NFS utilities package first, e.g., `sudo pacman -S nfs-utils` on Arch or `sudo apt install nfs-kernel-server` on Ubuntu).*

## Step 5: Grant Display Permission (Linux)
Allow Docker to draw windows on your local X11/Wayland display by running:
```bash
xhost +
```

## Step 6: Run the Docker Container (Native GUI)
Create directories to persist the large SDK downloads so they aren't lost when the container stops, then run the container with X11 forwarding:

**For Linux:**
```bash
mkdir -p sdkm_downloads nvidia_sdk && \
sudo docker run -it --rm \
  --privileged \
  --security-opt apparmor=unconfined \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -e QT_X11_NO_MITSHM=1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /dev/bus/usb:/dev/bus/usb \
  -v /dev:/dev \
  -v /etc/exports:/etc/exports \
  -v $(pwd):/sdk \
  -v $(pwd)/sdkm_downloads:/home/nvidia/Downloads/nvidia/sdkm_downloads \
  -v $(pwd)/nvidia_sdk:/home/nvidia/nvidia/nvidia_sdk \
  --net=host \
  --entrypoint bash \
  jetson-boot-env -c "sdkmanager; sleep infinity"
```

Once the container starts, the NVIDIA SDK Manager window should pop up directly on your desktop. When you are finished, press `Ctrl+C` in the terminal to close the container.

## Notes
* You can pass specific arguments to the sdkmanager CLI by appending them to the docker run command, for example: `docker run ... jetson-boot-env --cli --login-type devzone`.
* The container runs as a non-root user `nvidia` with `sudo` privileges.

## Troubleshooting
* **Host Components Installation Fails:** If you encounter errors while installing "Host Components" in the SDK Manager, the downloaded files might be corrupted. You can fix this by clearing the mapped directory on your host:
  ```bash
  sudo rm -rf nvidia_sdk/*
  ```
