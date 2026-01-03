#!/bin/sh
APK_NAME="Phicomm-R1e.apk"
APK_PATH="$HOME/$APK_NAME"
ADB_DEVICE_IP="192.168.43.1"
ADB_DEVICE_PORT="5555"
ADB_DEVICE="$ADB_DEVICE_IP:$ADB_DEVICE_PORT"
APK_REMOTE_PATH="/data/local/tmp/$APK_NAME"
PACKAGE_NAME="info.dourok.voicebot"
RECONNECT_COUNT=0
MAX_RECONNECT=999

ADB="adb"

log_info() {
    echo "[TrungHieu] $*"
}

fail() {
    log_info "$1"
    exit 1
}

check_adb() {
    log_info "Kiem tra adb..."
    if ! command -v adb >/dev/null 2>&1; then
        log_info "adb chua duoc cai. Dang cai dat android-tools..."
        if command -v apk >/dev/null 2>&1; then
            apk add --no-cache android-tools
        elif command -v pkg >/dev/null 2>&1; then
            pkg install -y android-tools
        else
            fail "Khong tim thay trinh quan ly goi phu hop de cai dat adb. Vui long cai dat adb thu cong."
        fi
    fi
}

wait_for_wifi() {
    log_info "Kiem tra ket noi Wi-Fi toi $ADB_DEVICE_IP..."
    local wifi_prompt_shown=0
    while true; do
        if ping -c 1 -W 1 "$ADB_DEVICE_IP" >/dev/null 2>&1; then
            log_info "Da ping thanh cong $ADB_DEVICE_IP."
            return
        fi
        if [ "$wifi_prompt_shown" -eq 0 ]; then
            log_info "Hay ket noi toi Wifi cua loa: Phicomm R1"
            wifi_prompt_shown=1
        fi
        sleep 3
    done
}

is_device_connected() {
    "$ADB" devices 2>/dev/null | awk -v dev="$ADB_DEVICE" '$1==dev && $2=="device" {found=1} END {exit (found?0:1)}'
}

ensure_device_connection() {
    wait_for_wifi
    if is_device_connected; then
        return
    fi
    connect_adb
}

adb_exec() {
    "$ADB" "$@"
}

reconnect_adb() {
    while true; do
        RECONNECT_COUNT=$((RECONNECT_COUNT + 1))
        if [ "$RECONNECT_COUNT" -gt "$MAX_RECONNECT" ]; then
            fail "Khong the ket noi ADB sau $MAX_RECONNECT lan thu."
        fi

        log_info "Mat ket noi ADB, thu ket noi lai (lan $RECONNECT_COUNT)..."
        wait_for_wifi
        "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1 || true
        sleep 2

        if is_device_connected; then
            RECONNECT_COUNT=0
            return
        fi
    done
}

connect_adb() {
    log_info "Khoi dong lai ket noi ADB..."
    wait_for_wifi
    while true; do
        "$ADB" disconnect
        "$ADB" kill-server
        "$ADB" connect "$ADB_DEVICE"
        if is_device_connected; then
            return
        fi
        log_info "Chua ket noi duoc $ADB_DEVICE, thu lai..."
        sleep 2
    done
}

step_hide_packages() {
    log_info "Vo hieu hoa bloatware..."
    local apps="airskill exceptionreporter systemtool otaservice productiontest bugreport"
    for app in $apps; do
        log_info "Hide com.phicomm.speaker.$app"
        adb_exec shell /system/bin/pm hide "com.phicomm.speaker.$app"
    done
}

step_push_apk() {
    local apk_path="$1"
    local apk_remote_path="$2"
    adb_exec push "$apk_path" "$apk_remote_path"
}

step_uninstall_existing() {
    local package_name="$1"
    log_info "Kiem tra lam sach thiet bi truoc khi cai dat..."
    adb_exec shell /system/bin/pm uninstall "$package_name"
}

step_install_apk() {
    local name="$1"
    local path="$2"
    log_info "Cai dat $name..."
    adb_exec shell /system/bin/pm install -r "$path"
}

launch() {
    local name="$1"
    local main_activity="$2"
    log_info "Khoi dong ung dung $name..."
    adb_exec shell am start -n "$main_activity"
}

check_adb
connect_adb
step_hide_packages

log_info "Day file APKs len thiet bi..."
step_push_apk "$APK_PATH" "$APK_REMOTE_PATH"
step_uninstall_existing "$PACKAGE_NAME"
step_install_apk "$APK_NAME" "$APK_REMOTE_PATH"
launch "$APK_NAME" "$PACKAGE_NAME/.java.activities.MainActivity"
