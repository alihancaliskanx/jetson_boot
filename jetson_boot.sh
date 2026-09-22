#!/bin/bash

# Stop execution on error (optional, we handle some manually)
set -e

# Ensure we are in the project directory
cd "$(dirname "$0")" || exit 1

echo "🚀 Jetson Boot Automation Script Starting..."

# 1. Check for SDK Manager .deb file
echo "🔍 Looking for SDK Manager deb file..."
if ! ls sdkmanager_*.deb 1> /dev/null 2>&1; then
    echo "❌ ERROR: SDK Manager .deb file not found!"
    echo "Please download it from the NVIDIA website and place it in the 'jetson_boot' folder."
    exit 1
else
    echo "✅ SDK Manager .deb file is present."
fi

# 2. Check if Jetson device is in Recovery mode
echo "🔍 Looking for Jetson device (in Recovery Mode)..."
if ! lsusb | grep -qi "Nvidia"; then
    echo "⚠️ WARNING: Jetson device not found!"
    echo "Please ensure your Jetson is in Recovery Mode (FC REC and GND pins shorted) and connected via Type-C."
    read -p "Do you want to continue anyway? (y/N): " continue_choice
    if [[ "$continue_choice" != "y" && "$continue_choice" != "Y" ]]; then
        echo "🛑 Operation aborted."
        exit 1
    fi
else
    echo "✅ Jetson device connected (NVIDIA Corp. found)."
fi

# 3. Check and build Docker image
IMAGE_NAME="jetson-boot-env"
echo "🔍 Checking Docker image..."
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "🐳 Docker image ($IMAGE_NAME) not found. Building..."
    docker build -t $IMAGE_NAME .
    echo "✅ Docker image successfully built."
else
    echo "✅ Docker image ($IMAGE_NAME) already exists. Skipping build."
fi

# 4. Prevent conflict with host NFS server
echo "🔍 Checking NFS server status..."
for service in rpcbind rpcbind.socket nfs-server; do
    if systemctl list-unit-files | grep -q "^$service"; then
        if systemctl is-active --quiet $service; then
            echo "🛑 Stopping $service on host to prevent conflicts..."
            sudo systemctl stop $service
            sudo systemctl disable $service
            echo "✅ $service stopped and disabled."
        else
            echo "✅ $service is already stopped."
        fi
    fi
done

# 5. Display (X11) permissions
echo "🔍 Checking Display permissions..."
if ! xhost | grep -q "access control disabled"; then
    echo "🖥️ Granting X11 display permissions..."
    xhost +
else
    echo "✅ X11 display permissions are already set."
fi

# 6. Create necessary folders
echo "📁 Creating/Checking download folders..."
mkdir -p sdkm_downloads nvidia_sdk

# 6.5 Load NFS Kernel Module (Required for flash)
echo "🔧 Loading NFS kernel module (modprobe nfsd)..."
sudo modprobe nfsd || true

# 7. Start Docker Container
echo "🚀 Starting Docker container..."
CONTAINER_NAME="jetson-sdk-manager"

# If container is already running, just exec into it
if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "⚠️ Container ($CONTAINER_NAME) is already running. Executing inside..."
    sudo docker exec -it $CONTAINER_NAME bash -c "sdkmanager"
else
    # Start the container if not running
    sudo docker run -it --rm --init \
      --name $CONTAINER_NAME \
      --privileged \
      --security-opt apparmor=unconfined \
      --ipc=host \
      -e DISPLAY=$DISPLAY \
      -e QT_X11_NO_MITSHM=1 \
      -v /tmp/.X11-unix:/tmp/.X11-unix \
      -v /dev/bus/usb:/dev/bus/usb \
      -v /dev:/dev \
      -v /lib/modules:/lib/modules \
      -v $(pwd):/sdk \
      -v $(pwd)/sdkm_downloads:/home/nvidia/Downloads/nvidia/sdkm_downloads \
      -v $(pwd)/nvidia_sdk:/home/nvidia/nvidia/nvidia_sdk \
      -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket \
      --net=host \
      $IMAGE_NAME bash -c "sdkmanager; sleep infinity"
fi
