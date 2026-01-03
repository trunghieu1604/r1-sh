#!/bin/sh

APK_NAME="Phicomm-R1.apk"
APK_URL="https://github.com/trunghieu1604/r1-ai/releases/download/v1.0/$APK_NAME"
APK_PATH="$HOME/$APK_NAME"

DLNA_APK_NAME="dlna.apk"
DLNA_APK_LOCAL_PATH="$HOME/$DLNA_APK_NAME"
DLNA_APK_URL="https://github.com/trunghieu1604/r1-ai/releases/download/v1.0/$DLNA_APK_NAME"

UNISOUND_APK_NAME="uni.apk"
UNISOUND_APK_LOCAL_PATH="$HOME/$UNISOUND_APK_NAME"
UNISOUND_APK_URL="https://github.com/trunghieu1604/r1-ai/releases/download/v1.0/$UNISOUND_APK_NAME"

prepare_apk() {
    local apk_path="$1"
    local apk_url="$2"
    wget -O "$apk_path" "$apk_url"
}

prepare_apk "$APK_PATH" "$APK_URL"
prepare_apk "$DLNA_APK_LOCAL_PATH" "$DLNA_APK_URL"
prepare_apk "$UNISOUND_APK_LOCAL_PATH" "$UNISOUND_APK_URL"