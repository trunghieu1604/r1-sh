**CÀI ĐẶT AIBOX**

if command -v pkg >/dev/null 2>&1; then
    pkg install -y wget    
elif command -v apk >/dev/null 2>&1; then
    apk update && apk add wget    
elif command -v brew >/dev/null 2>&1; then
    brew install wget    
fi && wget -qO- https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/aibox.sh | sh

****************************************************************************************
**CÀI ĐẶT MP3**

if command -v pkg >/dev/null 2>&1; then
    pkg install -y wget    
elif command -v apk >/dev/null 2>&1; then
    apk update && apk add wget    
elif command -v brew >/dev/null 2>&1; then
    brew install wget    
fi && wget -qO- https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/mp3.sh | sh

***************************************************************************************
**APK HỔ TRỢ**

APK Quét IP R1: https://github.com/trunghieu1604/r1-sh/releases/download/src/Fing-R1.apk

APK Remote MP3: https://github.com/trunghieu1604/r1-sh/releases/download/src/remote.apk
