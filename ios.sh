#!/bin/bash
APK_NAME="Phicomm-R1.apk"
APK_URL="https://github.com/trunghieu1604/r1-ai/releases/download/v1.0/$APK_NAME"
APK_PATH="$HOME/$APK_NAME"
ADB_DEVICE_IP="192.168.43.1"
ADB_DEVICE_PORT="5555"
ADB_DEVICE="$ADB_DEVICE_IP:$ADB_DEVICE_PORT"
APK_REMOTE_PATH="/data/local/tmp/$APK_NAME"
PACKAGE_NAME="info.dourok.voicebot"
RECONNECT_COUNT=0
MAX_RECONNECT=999
MAX_INSTALL_RETRY=10
ADB_CMD_MAX_RETRY=10
ADB_CMD_RETRY_DELAY=2

ADB="adb"

log_info() {
    echo "[Trunghieu][INFO] $*"
}

log_warn() {
    echo "[Trunghieu][WARN] $*"
}

log_error() {
    echo "[Trunghieu][ERROR] $*" >&2
}

fail() {
    log_error "$1"
    exit 1
}

check_adb() {
    log_info "Kiem tra Adb..."
    if ! command -v adb >/dev/null 2>&1; then
        log_warn "ADB chua duoc cai. Dang cai dat ADB-Tools..."
        # Check if apk command is available (Alpine Linux), neu ton tai thi su dung no de cai dat
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
            log_warn "Hay ket noi toi Wifi cua loa: Phicomm R1"
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
    local attempt=0
    local out=""
    local status=1
    while [ "$attempt" -lt "$ADB_CMD_MAX_RETRY" ]; do
        attempt=$((attempt + 1))
        ensure_device_connection
        out=$("$ADB" "$@" 2>&1)
        status=$?
        if [ "$status" -eq 0 ]; then
            printf '%s' "$out"
            return 0
        fi

        if echo "$out" | grep -Eiq "no devices|device offline|failed to connect|cannot connect|connection refused|device not found"; then
            log_warn "Mat ket noi ADB khi chay '$*' (lan $attempt/$ADB_CMD_MAX_RETRY). Thu ket noi lai..."
            reconnect_adb
            continue
        fi

        if [ "$attempt" -lt "$ADB_CMD_MAX_RETRY" ]; then
            log_warn "Lenh adb '$*' that bai (lan $attempt/$ADB_CMD_MAX_RETRY), thu lai sau $ADB_CMD_RETRY_DELAY giay..."
            sleep "$ADB_CMD_RETRY_DELAY"
        fi
    done

    log_error "Lenh adb '$*' that bai sau $ADB_CMD_MAX_RETRY lan thu."
    printf '%s' "$out"
    return "$status"
}

reconnect_adb() {
    while true; do
        RECONNECT_COUNT=$((RECONNECT_COUNT + 1))
        if [ "$RECONNECT_COUNT" -gt "$MAX_RECONNECT" ]; then
            fail "Khong the ket noi ADB sau $MAX_RECONNECT lan thu."
        fi

        log_warn "Mat ket noi ADB, thu ket noi lai (lan $RECONNECT_COUNT)..."
        wait_for_wifi
        "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1 || true
        sleep 2

        if is_device_connected; then
            RECONNECT_COUNT=0
            return
        fi
    done
}

prepare_apk() {
    log_info "Tai cac file can thiet ..."
    if command -v curl >/dev/null 2>&1; then
        log_info "Dang tai bang curl ..."
        if ! curl -fL "$APK_URL" -o "$APK_PATH"; then
            fail "Khong tai duoc file APK."
        fi
    else
        log_info "Dang tai bang wget ..."
        if ! wget -O "$APK_PATH" "$APK_URL"; then
            fail "Khong tai duoc file APK."
        fi
    fi
    [ -f "$APK_PATH" ] || fail "File $APK_PATH khong ton tai sau khi tai."
}

connect_adb() {
    log_info "Khoi dong lai ket noi ADB..."
    wait_for_wifi
    while true; do
        "$ADB" disconnect >/dev/null 2>&1 || true
        "$ADB" connect "$ADB_DEVICE" >/dev/null 2>&1 || true

        if is_device_connected; then
            RECONNECT_COUNT=0
            return
        fi

        log_warn "Chua ket noi duoc $ADB_DEVICE, thu lai..."
        sleep 2
    done
}

step_hide_packages() {
    log_info "Vo hieu hoa bloatware..."
    local apps="airskill exceptionreporter systemtool device otaservice productiontest bugreport"
    for app in $apps; do
        log_info "Hide com.phicomm.speaker.$app"
        adb_exec shell /system/bin/pm hide "com.phicomm.speaker.$app" >/dev/null || true
    done
}

step_push_apk() {
    log_info "Sao chep APK len thiet bi..."
    if ! adb_exec push "$APK_PATH" "$APK_REMOTE_PATH" >/dev/null; then
        fail "Khong the dua APK len thiet bi."
    fi
}

step_uninstall_existing() {
    log_info "Kiem tra phien ban APK truoc khi cai dat..."
    local out
    out=$(adb_exec shell /system/bin/pm list packages "$PACKAGE_NAME" || true)

    if echo "$out" | grep -q "$PACKAGE_NAME"; then
        log_warn "Phien ban cu ton tai, tien hanh go bo..."
        local uninstall_out
        uninstall_out=$(adb_exec shell /system/bin/pm uninstall "$PACKAGE_NAME" || true)

        if echo "$uninstall_out" | grep -qi "Success"; then
            log_info "Da go cai phien ban cu thanh cong."
        else
            log_warn "Khong the go cai phien ban cu: $uninstall_out"
        fi
    else
        log_info "Thiet bi da san sang cai dat VoiceBot."
    fi
}

restore_packages() {
    log_warn "Khoi phuc cac ung dung mac dinh..."
    local apps="player device airskill exceptionreporter ijetty netctl otaservice systemtool productiontest bugreport"
    for app in $apps; do
        adb_exec shell /system/bin/pm unhide "com.phicomm.speaker.$app" >/dev/null || true
    done
}

step_install_apk() {
    local retry=0
    while [ "$retry" -lt "$MAX_INSTALL_RETRY" ]; do
        retry=$((retry + 1))
        log_info "Cai dat VoiceBot (lan $retry/$MAX_INSTALL_RETRY)..."

        local out
        out=$(adb_exec shell /system/bin/pm install -r "$APK_REMOTE_PATH" || true)

        if echo "$out" | grep -qi "Success"; then
            install_success
            return
        fi

        if echo "$out" | grep -qi "INSTALL_FAILED_DEXOPT"; then
            log_warn "Loi DexOpt, thu lai..."
            sleep 1
            continue
        fi

        if echo "$out" | grep -qi "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
            log_warn "Phien ban cu ton tai, dang go bo..."
            adb_exec shell /system/bin/pm uninstall "$PACKAGE_NAME" >/dev/null || true
            retry=0
            continue
        fi

        log_error "Cai dat that bai: $out"
        break
    done

    restore_packages
    fail "Khong the cai dat VoiceBot."
}

install_success() {
    log_info "Khoi dong ung dung VoiceBot..."
    adb_exec shell am start -n "$PACKAGE_NAME/.java.activities.MainActivity" >/dev/null || true
    log_info "Hoan tat. VoiceBot san sang su dung."
}

check_adb
prepare_apk
connect_adb
step_hide_packages
step_push_apk
step_uninstall_existing
step_install_apk
