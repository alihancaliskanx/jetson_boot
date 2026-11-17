#!/bin/bash

# Stop execution on error (optional, we handle some manually)
set -e

# State tracking for host restoration on exit
SERVICES_TO_RESTART=()
XHOST_OPENED=0

cleanup() {
    trap - EXIT INT TERM
    if [[ ${#SERVICES_TO_RESTART[@]} -gt 0 ]]; then
        echo "🔄 Restoring stopped host services..."
        for service in "${SERVICES_TO_RESTART[@]}"; do
            sudo systemctl start "$service" 2>/dev/null || true
            echo "✅ $service restored."
        done
    fi
    if [[ "$XHOST_OPENED" -eq 1 ]]; then
        echo "🔒 Restoring X11 access control..."
        xhost - 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

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

# 3. Build Docker image
# Always built so that Dockerfile and entrypoint.sh changes take effect; the layer
# cache makes this instant when nothing changed. The host network is used because
# the default bridge has no internet access behind a transparent host proxy.
IMAGE_NAME="jetson-boot-env"
echo "🐳 Building Docker image ($IMAGE_NAME)..."
sudo docker build --network=host -t "$IMAGE_NAME" .
echo "✅ Docker image is up to date."

# 4. Prevent conflict with host NFS server
echo "🔍 Checking NFS server status..."
for service in rpcbind rpcbind.socket nfs-server; do
    if systemctl list-unit-files | grep -q "^$service"; then
        if systemctl is-active --quiet $service; then
            echo "🛑 Stopping $service on host to prevent conflicts..."
            sudo systemctl stop $service
            SERVICES_TO_RESTART+=("$service")
            echo "✅ $service stopped."
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
    XHOST_OPENED=1
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
if sudo docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "⚠️ Container ($CONTAINER_NAME) is already running. Executing inside..."
    sudo docker exec -it "$CONTAINER_NAME" bash -c "sdkmanager"
else
    # Start the container if not running
    sudo docker run -it --rm --init \
      --name "$CONTAINER_NAME" \
      --privileged \
      --security-opt apparmor=unconfined \
      --ipc=host \
      -e DISPLAY="$DISPLAY" \
      -e QT_X11_NO_MITSHM=1 \
      -e http_proxy="${http_proxy:-}" \
      -e https_proxy="${https_proxy:-}" \
      -v /tmp/.X11-unix:/tmp/.X11-unix \
      -v /dev/bus/usb:/dev/bus/usb \
      -v /dev:/dev \
      -v /lib/modules:/lib/modules \
      -v "$(pwd)":/sdk \
      -v "$(pwd)/sdkm_downloads":/home/nvidia/Downloads/nvidia/sdkm_downloads \
      -v "$(pwd)/nvidia_sdk":/home/nvidia/nvidia/nvidia_sdk \
      -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket \
      --net=host \
      "$IMAGE_NAME" bash -c "sdkmanager; sleep infinity"
fi
