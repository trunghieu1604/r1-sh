#!/bin/sh

rm -f $HOME/*.apk
rm -f $HOME/*.sh
echo "Clean up old files done."

wget -O $HOME/download.sh "https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/download.sh"
wget -O $HOME/cai-dat-ai-v3.sh "https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/voicebot.sh"
chmod +x $HOME/download.sh
chmod +x $HOME/voicebot.sh

echo "[1/2] Chuan bi cai dat..."
$HOME/download.sh
echo "[2/2] Cai dat Voicebot..."
$HOME/voicebot.sh || true
echo "Cai dat hoan tat."
echo "Doi thiet bi khoi lai xong."
echo "Vao wifi Phicomm R1, truy cap http://192.168.43.1:8081 de cau hinh Wi-Fi cho thiet bi."
