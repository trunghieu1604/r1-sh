#!/bin/sh

ADB_DEVICE_IP="192.168.43.1"
ADB_DEVICE_PORT="5555"
ADB_DEVICE="$ADB_DEVICE_IP:$ADB_DEVICE_PORT"
ADB="adb"

BASE_URL="https://github.com/trunghieu1604/r1-sh/releases/download/src"
PACKAGE_NAME="com.wifi.transfer.pro"

MUSIC_APK="music.apk"
DLNA_APK="auto-dlna.apk"

log_info() { echo "[TRUNGHIEU] $*"; }



setup_env() {
    if command -v adb >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
        log_info "Các công cụ cần thiết (adb, curl) đã được cài đặt."
        rm -f "$HOME"/*.apk >/dev/null 2>&1
        return 0
    fi

    if [ -d "/data/data/com.termux" ]; then
        echo "=====> Cài qua Termux <====="
        
        local termux_dir="$HOME/.termux"
        local prop_file="$termux_dir/termux.properties"
        mkdir -p "$termux_dir"
        if [ ! -f "$prop_file" ]; then
            echo "enforce-char-based-input = true" > "$prop_file"
            termux-reload-settings >/dev/null 2>&1
        elif ! grep -q "^[[:space:]]*enforce-char-based-input[[:space:]]*=[[:space:]]*true" "$prop_file"; then
            sed -i 's/^[[:space:]]*enforce-char-based-input.*/# &/' "$prop_file" 2>/dev/null
            echo "enforce-char-based-input = true" >> "$prop_file"
            termux-reload-settings >/dev/null 2>&1
        fi

        pkg upgrade -y >/dev/null 2>&1
        pkg install -y wget curl android-tools >/dev/null 2>&1

    elif command -v apk >/dev/null 2>&1; then
        echo "=====> Cài qua iSH <====="
        apk update >/dev/null 2>&1
        apk add wget curl android-tools >/dev/null 2>&1

    elif command -v brew >/dev/null 2>&1; then
        echo "=====> Cài qua macOS <====="
        brew install wget curl android-platform-tools >/dev/null 2>&1

    else
        echo "Không hỗ trợ môi trường này."
        exit 1
    fi

    echo "Đã cài thành công, chờ xoá bộ nhớ cũ."
    rm -f "$HOME"/*.apk >/dev/null 2>&1
    echo "Đã xoá bộ nhớ."
}

progress_download() {
    url="$1"
    output="$2"
    name="$3"
    echo "Đang tải $name..."
    total_size=$(curl -sIL "$url" | grep -i Content-Length | tail -1 | tr -d '\r' | awk '{print $2}')
    curl -L -sS "$url" -o "$output" >/dev/null 2>&1 &
    pid=$!
    while kill -0 $pid 2>/dev/null; do
        if [ -f "$output" ]; then
            current_size=$(wc -c < "$output" 2>/dev/null)
            if [ -n "$total_size" ] && [ "$total_size" -gt 0 ]; then
                percent=$((current_size * 100 / total_size))
                [ "$percent" -gt 100 ] && percent=100
                bars=$((percent / 10))
                done_bar=$(printf "%${bars}s" | tr ' ' '#')
                printf "\r[%-10s] %3d%%" "$done_bar" "$percent"
            fi
        fi
        sleep 0.2
    done
    wait $pid
    printf "\r[##########] 100%%\n"
}

wait_for_wifi() {
    local prompt_shown=0
    while ! ping -c 1 -W 1 "$ADB_DEVICE_IP" >/dev/null 2>&1; do
        if [ "$prompt_shown" -eq 0 ]; then
            echo "[TRUNGHIEU] Hãy kết nối tới Wifi của loa: Phicomm R1"
            prompt_shown=1
        fi
        sleep 3
    done
    log_info "Đã ping thành công $ADB_DEVICE_IP."
}

is_device_connected() {
    "$ADB" devices 2>/dev/null | grep -q "$ADB_DEVICE.*device"
}

connect_adb() {
    log_info "Khởi động kết nối ADB..."
    wait_for_wifi
    while true; do
        "$ADB" disconnect >/dev/null 2>&1
        "$ADB" kill-server >/dev/null 2>&1
        "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1
        if is_device_connected; then return; fi
        sleep 2
    done
}

hide_bloatware() {
    log_info "Vô hiệu hóa bloatware..."
    local apps="device exceptionreporter otaservice productiontest bugreport"
    for app in $apps; do
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null 2>&1
    done
}

launch() {
    log_info "Khởi chạy ứng dụng MUSIC..."
    "$ADB" -s "$ADB_DEVICE" shell am force-stop "$PACKAGE_NAME"
    "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/com.wifi.transfer.pro.MainActivity"
    "$ADB" -s "$ADB_DEVICE" shell am broadcast -a android.intent.action.BOOT_COMPLETED -p "$PACKAGE_NAME"
}

launch1() {
    log_info "Khởi chạy ứng dụng DLNA..."
    "$ADB" -s "$ADB_DEVICE" shell am startservice "com.phicomm.speaker.player/.EchoService"
}

install_apk() {
    local local_path="$1"
    local apk_file=$(basename "$local_path")
    log_info "Đẩy $apk_file lên thiết bị..."
    "$ADB" -s "$ADB_DEVICE" push "$local_path" "/data/local/tmp/$apk_file"
    log_info "Cài đặt $apk_file..."
    "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1
    "$ADB" -s "$ADB_DEVICE" shell settings put global package_verifier_enable 0
    "$ADB" -s "$ADB_DEVICE" shell settings put global verifier_verify_adb_installs 0
    "$ADB" -s "$ADB_DEVICE" shell "CLASSPATH=/system/framework/pm.jar app_process /system/bin com.android.commands.pm.Pm install -r -d /data/local/tmp/$apk_file"
    "$ADB" -s "$ADB_DEVICE" shell rm "/data/local/tmp/$apk_file"
}

config_wifi() {
    clear
    echo "======================================="
    echo "||      CẤU HÌNH WI-FI CHO LOA R1    ||"
    echo "======================================="
    echo "|| Chuyển bàn phím về tiếng Anh nếu  ||"
    echo "||như chạy script này bằng TERMUX    ||"
    echo "======================================="
    
    printf "Nhập tên Wi-Fi (SSID): "
    read -r ssid
    if [ -z "$ssid" ]; then
        echo "Tên Wi-Fi không được để trống!"
        sleep 2
        return 1
    fi
    
    printf "Nhập mật khẩu: "
    read -r password
    
    local secure="WPA"
    if [ -z "$password" ]; then
        secure="INSECURE"
    fi
    
    log_info "Đang gửi cấu hình wifi tới R1..."
    
    local response=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
        -d "{\"ssid\":\"$ssid\",\"secure\":\"$secure\",\"password\":\"$password\",\"mac\":\"\"}" \
        "http://192.168.43.1:8989/api/configwifi")
        
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -eq 200 ] 2>/dev/null; then
        echo ""
        log_info "Gửi cấu hình thành công! Vui lòng chờ loa kết nối khoảng 10s."
        log_info "Đang khởi động lại loa..."
        "$ADB" -s "$ADB_DEVICE" reboot >/dev/null 2>&1
        log_info "Cài đặt hoàn tất."
    else
        echo ""
        log_info "Lỗi: Không thể gửi cấu hình tới loa."
        log_info "Hãy chắc chắn đã kết nối vào Wifi của loa."
    fi
    
    printf "Nhấn Enter để quay lại menu..."
    read -r temp
}

show_menu() {
    clear
    echo "======================================="
	echo "||          MUSIC - DLNA             ||"
	echo "||  1. [MUSIC] FULL                  ||"
	echo "======================================="
	echo "||       CHỈ CÀI MỖI MUSIC           ||"
	echo "||  2. [MUSIC]                       ||"
	echo "======================================="
    echo "||  0. Thoát                         ||"
    echo "======================================="
    printf "Chọn số theo danh sách (0-2): "
}

main() {
    exec < /dev/tty
    stty echo 2>/dev/null
    setup_env
    while true; do
        show_menu
        read -r choice
        case $choice in
            1)
                APK=$MUSIC_APK
                echo ""
                echo "[1/2] Chuẩn bị tải file."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "MUSIC"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
                
                echo ""
                echo "[2/2] Cài đặt MUSIC."
                connect_adb
                hide_bloatware
                
                log_info "Kiểm tra làm sạch thiết bị..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                launch
                
                install_apk "$HOME/$DLNA_APK"
				launch1
				
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1
                
                echo ""
                config_wifi
                exit 0
                ;;	
            2)
                APK=$MUSIC_APK
                echo ""
                echo "[1/2] Chuẩn bị tải file cập nhật."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "MUSIC"
                
                echo ""
                echo "[2/2] Cập nhật MUSIC."
                connect_adb
                hide_bloatware
                
                log_info "Kiểm tra làm sạch thiết bị..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                launch
                
                echo ""
                config_wifi
                exit 0
                ;;
			0) exit 0 ;;
            *) echo "Lựa chọn không hợp lệ!"; sleep 2 ;;
        esac
    done
}

main
