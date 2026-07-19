#!/bin/sh
# Tự động kiểm tra và cài đặt wget nếu chưa có
if command -v pkg >/dev/null 2>&1; then
    pkg install -y wget
elif command -v apk >/dev/null 2>&1; then
    apk update && apk add wget
elif command -v brew >/dev/null 2>&1; then
    brew install wget
fi

# Tải và chạy script chính
wget -qO- https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/phicomm.sh | sh
