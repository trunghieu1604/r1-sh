#!/bin/sh

APK_NAME="Phicomm-R1.apk"
APK_URL="https://github.com/trunghieu1604/r1-ai/releases/download/v1.0/$APK_NAME"
APK_PATH="$HOME/$APK_NAME"

prepare_apk() {
    local apk_path="$1"
    local apk_url="$2"
    wget -O "$apk_path" "$apk_url"
}

prepare_apk "$APK_PATH" "$APK_URL"
