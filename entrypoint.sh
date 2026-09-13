#!/bin/bash
# entrypoint.sh

# Install SDK Manager if a .deb file is mapped
if ls /sdk/sdkmanager*.deb 1> /dev/null 2>&1; then
    echo "SDK Manager deb file found in /sdk. Installing..."
    sudo apt-get update
    # Install the first matching deb file
    DEB_FILE=$(ls /sdk/sdkmanager*.deb | head -n 1)
    sudo apt-get install -y "$DEB_FILE"
fi

if command -v sdkmanager &> /dev/null; then
    echo "SDK Manager is installed. Starting..."
    if [ $# -eq 0 ]; then
        exec sdkmanager --cli
    else
        exec sdkmanager "$@"
    fi
else
    echo "=========================================================="
    echo "ERROR: SDK Manager is not installed."
    echo "Please download the SDK Manager .deb file from NVIDIA:"
    echo "https://developer.nvidia.com/nvidia-sdk-manager"
    echo "Place it in this project folder, then restart the container."
    echo "=========================================================="
    exec /bin/bash
fi
