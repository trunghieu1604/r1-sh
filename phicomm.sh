#!/bin/sh

ADB_DEVICE_IP="192.168.43.1"
ADB_DEVICE_PORT="5555"
ADB_DEVICE="$ADB_DEVICE_IP:$ADB_DEVICE_PORT"
ADB="adb"

BASE_URL="https://github.com/trunghieu1604/r1-sh/releases/download/src"
PACKAGE_NAME="info.dourok.voicebot"

FREE_APK="free.apk"
PREMIUM_APK="premium.apk"
AIBOXPLUS_APK="aibox+.apk"
DLNA_APK="auto-dlna.apk"
UNI_SOUND_APK="uni-sound.apk"

log_info() { echo "[TRUNGHIEU] $*"; }

open_browser() {
    URL="http://192.168.43.1:8081"

    if [ -d "/data/data/com.termux" ] && command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$URL"

    elif command -v apk >/dev/null 2>&1; then
        echo "====================================="
        echo "Truy cập Safari và mở:"
        echo "$URL"
        echo "====================================="

    elif command -v open >/dev/null 2>&1; then
        open "$URL" >/dev/null 2>&1

    else
        echo "Truy cập: $URL"
    fi
}

setup_env() {
    if [ -d "/data/data/com.termux" ]; then
        echo "=====> Cài qua Termux <====="
        pkg install -y wget curl android-tools python >/dev/null 2>&1

    elif command -v apk >/dev/null 2>&1; then
        echo "=====> Cài qua iSH <====="
        apk update >/dev/null 2>&1
        apk add wget curl android-tools python3 >/dev/null 2>&1

    elif command -v brew >/dev/null 2>&1; then
        echo "=====> Cài qua macOS <====="
        brew install wget curl android-platform-tools python3 >/dev/null 2>&1

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
    local apps="device airskill exceptionreporter ijetty netctl systemtool otaservice productiontest bugreport"
    for app in $apps; do
        "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null 2>&1
    done
}

launch() {
    log_info "Khởi chạy ứng dụng Voicebot..."
    "$ADB" -s "$ADB_DEVICE" shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity"
}

install_apk() {
    local local_path="$1"
    local apk_file=$(basename "$local_path")
    log_info "Đẩy $apk_file lên thiết bị..."
    "$ADB" -s "$ADB_DEVICE" push "$local_path" "/data/local/tmp/$apk_file"
    log_info "Cài đặt $apk_file..."
    "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm install -r "/data/local/tmp/$apk_file"
}

detect_local_ip() {
    local ip=""
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
    fi
    if [ -z "$ip" ] && command -v ipconfig >/dev/null 2>&1; then
        ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
    fi
    if [ -z "$ip" ]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    echo "$ip"
}

start_http_server() {
    local dir="$1"
    local port="$2"
    local py_cmd=""
    
    if command -v python3 >/dev/null 2>&1; then
        py_cmd="python3"
    elif command -v python >/dev/null 2>&1; then
        py_cmd="python"
    else
        log_info "Lỗi: Không tìm thấy Python để chạy HTTP Server!"
        return 1
    fi

    local py_ver=$("$py_cmd" -c 'import sys; print(sys.version_info[0])' 2>/dev/null)

    stop_http_server

    log_info "Khởi chạy HTTP Server trên cổng $port..."
    cd "$dir" || return 1
    if [ "$py_ver" = "3" ]; then
        "$py_cmd" -m http.server "$port" >/dev/null 2>&1 &
    else
        "$py_cmd" -m SimpleHTTPServer "$port" >/dev/null 2>&1 &
    fi
    local pid=$!
    echo $pid > /tmp/r1_http.pid
    log_info "HTTP Server đang chạy ngầm với PID $pid."
}

stop_http_server() {
    if [ -f "/tmp/r1_http.pid" ]; then
        local pid=$(cat /tmp/r1_http.pid)
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Đang tắt HTTP Server cũ (PID $pid)..."
            kill "$pid" 2>/dev/null
            sleep 1
        fi
        rm -f /tmp/r1_http.pid
    fi
}

scan_r1_ip() {
    local py_cmd=""
    if command -v python3 >/dev/null 2>&1; then
        py_cmd="python3"
    elif command -v python >/dev/null 2>&1; then
        py_cmd="python"
    else
        echo ""
        return 1
    fi

    local detected_ip=$("$py_cmd" -c '
import socket
from threading import Thread
import sys

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("1.1.1.1", 80))
    local_ip = s.getsockname()[0]
    s.close()
except:
    sys.exit(1)

ip_parts = local_ip.split(".")
if len(ip_parts) != 4:
    sys.exit(1)
subnet = ".".join(ip_parts[:3])

found = []
def check_ip(ip):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(0.4)
    result = s.connect_ex((ip, 5555))
    if result == 0:
        found.append(ip)
    s.close()

threads = []
for i in range(1, 255):
    ip = "%s.%d" % (subnet, i)
    t = Thread(target=check_ip, args=(ip,))
    t.start()
    threads.append(t)

for t in threads:
    t.join()

if found:
    print(found[0])
' 2>/dev/null)

    echo "$detected_ip"
}

upgrade_firmware() {
    local fw_ver="$1"
    local txt_file="ota-${fw_ver}.txt"
    local zip_file="incremental-ota-${fw_ver}.zip"
    
    local upgrade_dir="$HOME/r1_upgrade"
    mkdir -p "$upgrade_dir/firmware"
    
    log_info "Tải file cấu hình $txt_file..."
    local txt_url="https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/$txt_file"
    progress_download "$txt_url" "$upgrade_dir/$txt_file" "$txt_file"
    
    log_info "Tải file zip firmware $zip_file..."
    local zip_url="https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/firmware/$zip_file"
    progress_download "$zip_url" "$upgrade_dir/firmware/$zip_file" "$zip_file"

    local def_ip=$(detect_local_ip)
    printf "Nhập IP của máy tính [$def_ip]: "
    read local_ip < /dev/tty
    if [ -z "$local_ip" ]; then
        local_ip="$def_ip"
    fi
    
    log_info "Đang quét tìm loa R1 trong mạng nội bộ..."
    local scanned_ip=$(scan_r1_ip)
    local def_r1_ip="$ADB_DEVICE_IP"
    if [ -n "$scanned_ip" ]; then
        log_info "Tìm thấy loa R1 tại IP: $scanned_ip"
        def_r1_ip="$scanned_ip"
    else
        log_info "Không quét thấy loa tự động. Sử dụng IP mặc định $ADB_DEVICE_IP."
    fi

    printf "Nhập IP của loa R1 [$def_r1_ip]: "
    read r1_ip < /dev/tty
    if [ -z "$r1_ip" ]; then
        r1_ip="$def_r1_ip"
    fi

    log_info "Cấu hình otaprop.txt..."
    sed -e "s/REPLACEBYIP/${local_ip}:8080/" "$upgrade_dir/$txt_file" > "$upgrade_dir/otaprop.txt"

    start_http_server "$upgrade_dir" 8080
    if [ $? -ne 0 ]; then
        log_info "Không thể khởi chạy HTTP Server. Tiến trình bị hủy."
        return 1
    fi

    log_info "Kết nối ADB tới loa ($r1_ip)..."
    "$ADB" disconnect >/dev/null 2>&1
    "$ADB" kill-server >/dev/null 2>&1
    "$ADB" connect "$r1_ip:5555" >/dev/null 2>&1
    
    local connected=0
    for i in 1 2 3 4 5; do
        if "$ADB" devices | grep -q "$r1_ip.*device"; then
            connected=1
            break
        fi
        sleep 2
    done
    
    if [ "$connected" -eq 0 ]; then
        log_info "Lỗi: Không thể kết nối ADB tới loa $r1_ip"
        stop_http_server
        return 1
    fi

    log_info "Đang đẩy otaprop.txt lên loa..."
    "$ADB" -s "$r1_ip:5555" push "$upgrade_dir/otaprop.txt" "/sdcard/otaprop.txt"
    log_info "Khởi động lại loa để tiến hành cập nhật..."
    "$ADB" -s "$r1_ip:5555" reboot

    echo "=========================================================="
    echo " Loa Phicomm R1 đang khởi động lại."
    echo " Hãy dùng điện thoại / trình duyệt cấu hình Wi-Fi cho loa."
    echo " Sau khi kết nối Wi-Fi, loa sẽ tự tải và cài đặt ROM."
    echo " KHÔNG ĐƯỢC TẮT nguồn loa hay tắt máy tính lúc này!"
    echo " Sau khi nâng cấp xong, hãy chạy Option 8 để dọn dẹp."
    echo "=========================================================="
    printf "Nhấn Enter để quay lại menu..."
    read temp < /dev/tty
}

cleanup_upgrade() {
    stop_http_server
    
    log_info "Đang quét tìm loa R1 trong mạng nội bộ..."
    local scanned_ip=$(scan_r1_ip)
    local def_r1_ip="$ADB_DEVICE_IP"
    if [ -n "$scanned_ip" ]; then
        log_info "Tìm thấy loa R1 tại IP: $scanned_ip"
        def_r1_ip="$scanned_ip"
    else
        log_info "Không quét thấy loa tự động. Sử dụng IP mặc định $ADB_DEVICE_IP."
    fi

    printf "Nhập IP của loa R1 [$def_r1_ip]: "
    read r1_ip < /dev/tty
    if [ -z "$r1_ip" ]; then
        r1_ip="$def_r1_ip"
    fi

    log_info "Kết nối ADB tới loa ($r1_ip) để dọn dẹp..."
    "$ADB" disconnect >/dev/null 2>&1
    "$ADB" kill-server >/dev/null 2>&1
    "$ADB" connect "$r1_ip:5555" >/dev/null 2>&1
    
    local connected=0
    for i in 1 2 3 4 5; do
        if "$ADB" devices | grep -q "$r1_ip.*device"; then
            connected=1
            break
        fi
        sleep 2
    done

    if [ "$connected" -eq 1 ]; then
        log_info "Xóa otaprop.txt trên loa..."
        "$ADB" -s "$r1_ip:5555" shell rm "/sdcard/otaprop.txt"
        log_info "Đã xóa xong."
    else
        log_info "Không thể kết nối ADB để tự động xóa file trên loa."
        log_info "Hãy đảm bảo loa đã bật và kết nối cùng mạng, sau đó chạy lại Option 8."
    fi

    local upgrade_dir="$HOME/r1_upgrade"
    if [ -d "$upgrade_dir" ]; then
        log_info "Xóa các file tải tạm cục bộ..."
        rm -rf "$upgrade_dir"
    fi
    log_info "Hoàn tất dọn dẹp."
    printf "Nhấn Enter để quay lại menu..."
    read temp < /dev/tty
}

upgrade_firmware_menu() {
    local current_ver="Chưa kết nối"
    log_info "Đang kiểm tra kết nối tới loa..."
    "$ADB" connect "$ADB_DEVICE_IP:5555" >/dev/null 2>&1
    if "$ADB" devices | grep -q "$ADB_DEVICE_IP.*device"; then
        current_ver=$("$ADB" -s "$ADB_DEVICE_IP:5555" shell getprop ro.build.display.id 2>/dev/null | tr -d '\r\n')
        if [ -z "$current_ver" ]; then
            current_ver=$("$ADB" -s "$ADB_DEVICE_IP:5555" shell getprop ro.build.version.incremental 2>/dev/null | tr -d '\r\n')
        fi
        if [ -z "$current_ver" ]; then
            current_ver="Không xác định"
        else
            local clean_ver=$(echo "$current_ver" | grep -o '[0-9]\{4\}$')
            if [ -n "$clean_ver" ]; then
                current_ver="$clean_ver"
            fi
        fi
    fi

    while true; do
        clear
        echo "======================================="
        echo "||    CHỌN PHIÊN BẢN CẦN NÂNG CẤP    ||"
        echo "||  Phiên bản hiện tại của loa:      ||"
        echo "||  >> $current_ver <<"
        case "$current_ver" in
            *3448*)
                echo "||  (CẢNH BÁO: ĐÃ LÀ BẢN CAO NHẤT!)  ||"
                ;;
        esac
        echo "||                                   ||"
        echo "||  1. ota-3119-3166                 ||"
        echo "||  2. ota-3166-3415                 ||"
        echo "||  3. ota-3174-3318                 ||"
        echo "||  4. ota-3318-3331                 ||"
        echo "||  5. ota-3331-3448                 ||"
        echo "||  6. ota-3415-3448                 ||"
        echo "||  0. Quay lại                      ||"
        echo "======================================="
        printf "Chọn phiên bản (0-6): "
        read fw_choice < /dev/tty
        
        case $fw_choice in
            1) upgrade_firmware "3119-3166"; break ;;
            2) upgrade_firmware "3166-3415"; break ;;
            3) upgrade_firmware "3174-3318"; break ;;
            4) upgrade_firmware "3318-3331"; break ;;
            5) upgrade_firmware "3331-3448"; break ;;
            6) upgrade_firmware "3415-3448"; break ;;
            0) break ;;
            * ) echo "Lựa chọn không hợp lệ!"; sleep 1 ;;
        esac
    done
}

show_menu() {
    clear
    echo "======================================="
	echo "||   CÀI ĐẶT AI - DLNA - UNISOUND    ||"
	echo "||  1. [VIETBOT] FULL FREE - V1.2    ||"
    echo "||  2. [VIETBOT] FULL PREMIUM - V1.2 ||"
	echo "||  3. [AIBOX++] FULL - V5.1.3       ||"
	echo "======================================="
	echo "||          CHỈ CÀI MỖI AI           ||"
	echo "||  4. [VIETBOT] FREE - V1.2         ||"
    echo "||  5. [VIETBOT] PREMIUM - V1.2      ||"
    echo "||  6. [AIBOX++] - V5.1.3            ||"
	echo "======================================="
	echo "||        NÂNG CẤP FIRMWARE R1       ||"
	echo "||  7. Nâng cấp Firmware R1          ||"
	echo "||  8. Dọn dẹp otaprop & Tắt server  ||"
	echo "======================================="
    echo "||  0. Thoát                         ||"
    echo "======================================="
    printf "Chọn số theo danh sách (0-8): "
}

main() {
    setup_env
    while true; do
        show_menu
        read choice < /dev/tty
        case $choice in
            1|2|3)
        case "$choice" in
            1) APK=$FREE_APK ;;
            2) APK=$PREMIUM_APK ;;
			3) APK=$AIBOXPLUS_APK ;;
        esac
                echo ""
                echo "[1/2] Chuẩn bị tải file."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Voicebot"
                progress_download "$BASE_URL/$DLNA_APK" "$HOME/$DLNA_APK" "DLNA"
                progress_download "$BASE_URL/$UNI_SOUND_APK" "$HOME/$UNI_SOUND_APK" "Unisound"
                
                echo ""
                echo "[2/2] Cài đặt Voicebot."
                connect_adb
                hide_bloatware
                
                log_info "Kiểm tra làm sạch thiết bị..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                launch
                
                install_apk "$HOME/$DLNA_APK"
                install_apk "$HOME/$UNI_SOUND_APK"
                
                "$ADB" -s "$ADB_DEVICE" shell settings put secure install_non_market_apps 1
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm unhide "com.phicomm.speaker.player"
                
                echo ""
                log_info "Đang khởi động lại loa..."
				log_info "Cài đặt hoàn tất."
				log_info "Vào wifi Phicomm R1, truy cập 192.168.43.1:8081 để cấu hình Wi-Fi cho thiết bị."
                sleep 2
                "$ADB" -s "$ADB_DEVICE" reboot
                
                exit 0
                ;;	
            4|5|6)
        case "$choice" in
            4) APK=$FREE_APK ;;
            5) APK=$PREMIUM_APK ;;
            6) APK=$AIBOXPLUS_APK ;;
        esac
                echo ""
                echo "[1/2] Chuẩn bị tải file cập nhật."
                progress_download "$BASE_URL/$APK" "$HOME/$APK" "Voicebot"
                
                echo ""
                echo "[2/2] Cập nhật Voicebot."
                connect_adb
                hide_bloatware
                
                log_info "Kiểm tra làm sạch thiết bị..."
                "$ADB" -s "$ADB_DEVICE" shell /system/bin/pm uninstall "$PACKAGE_NAME"
                
                install_apk "$HOME/$APK"
                launch
                
                echo ""
				echo "Đang mở trang cấu hình..."
                echo "Cài đặt hoàn tất."
                sleep 1
                open_browser
                exit 0
                ;;
            7)
                upgrade_firmware_menu
                ;;
            8)
                cleanup_upgrade
                ;;
			0) exit 0 ;;
            *) echo "Lựa chọn không hợp lệ!"; sleep 2 ;;
        esac
    done
}

main
