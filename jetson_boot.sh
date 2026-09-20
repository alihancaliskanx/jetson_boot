#!/bin/bash

# Hata durumunda betiğin çalışmasını durdur (isteğe bağlı, bazı yerlerde manuel kontrol ediyoruz)
set -e

# Proje dizininde olduğumuzdan emin olalım
cd "$(dirname "$0")" || exit 1

echo "🚀 Jetson Boot Otomasyon Betiği Başlıyor..."

# 1. SDK Manager .deb dosyası kontrolü
echo "🔍 SDK Manager dosyası aranıyor..."
if ! ls sdkmanager_*.deb 1> /dev/null 2>&1; then
    echo "❌ HATA: SDK Manager .deb dosyası bulunamadı!"
    echo "Lütfen NVIDIA sitesinden indirip 'jetson_boot' klasörüne koyun."
    exit 1
else
    echo "✅ SDK Manager .deb dosyası mevcut."
fi

# 2. Jetson cihazının Recovery modunda olup olmadığını kontrol et
echo "🔍 Jetson cihazı (Recovery Modunda) aranıyor..."
if ! lsusb | grep -qi "Nvidia"; then
    echo "⚠️ UYARI: Jetson cihazı bulunamadı!"
    echo "Lütfen Jetson'ı Recovery Moduna (FC REC ile GND pinlerini birleştirerek) alıp Type-C ile bağladığınızdan emin olun."
    read -p "Yine de devam etmek istiyor musunuz? (E/h): " continue_choice
    if [[ "$continue_choice" == "h" || "$continue_choice" == "H" ]]; then
        echo "🛑 İşlem iptal edildi."
        exit 1
    fi
else
    echo "✅ Jetson cihazı bağlı (NVIDIA Corp. bulundu)."
fi

# 3. Docker imajı kontrolü ve derlenmesi
IMAGE_NAME="jetson-boot-env"
echo "🔍 Docker imajı kontrol ediliyor..."
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "🐳 Docker imajı ($IMAGE_NAME) bulunamadı. Derleniyor..."
    docker build -t $IMAGE_NAME .
    echo "✅ Docker imajı başarıyla derlendi."
else
    echo "✅ Docker imajı ($IMAGE_NAME) zaten mevcut. Derleme atlanıyor."
fi

# 4. Host NFS sunucusunun çakışmasını önleme
echo "🔍 NFS sunucu durumu kontrol ediliyor..."
for service in rpcbind nfs-server; do
    # Servisin sistemde var olup olmadığına bakıyoruz
    if systemctl list-unit-files | grep -q "^$service.service"; then
        if systemctl is-active --quiet $service; then
            echo "🛑 Çakışmayı önlemek için host üzerindeki $service durduruluyor..."
            sudo systemctl stop $service
            sudo systemctl disable $service
            echo "✅ $service durduruldu ve devre dışı bırakıldı."
        else
            echo "✅ $service zaten çalışmıyor."
        fi
    fi
done

# 5. Ekran (X11) izinleri
echo "🔍 Display izinleri kontrol ediliyor..."
if ! xhost | grep -q "access control disabled"; then
    echo "🖥️ X11 display izinleri veriliyor..."
    xhost +
else
    echo "✅ X11 display izinleri zaten ayarlanmış."
fi

# 6. Gerekli klasörleri oluştur (Varsa zarar vermez)
echo "📁 İndirme klasörleri oluşturuluyor/kontrol ediliyor..."
mkdir -p sdkm_downloads nvidia_sdk

# 7. Docker Container'ı Başlat
echo "🚀 Docker container başlatılıyor..."
CONTAINER_NAME="jetson-sdk-manager"

# Container zaten çalışıyorsa hata vermesin, sadece içine girelim
if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "⚠️ Container ($CONTAINER_NAME) zaten çalışıyor. İçine giriliyor..."
    sudo docker exec -it $CONTAINER_NAME bash -c "sdkmanager"
else
    # Container çalışmıyorsa başlat
    sudo docker run -it --rm \
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
