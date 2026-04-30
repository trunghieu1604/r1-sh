#!/bin/sh

rm -f $HOME/*.apk
rm -f $HOME/*.sh
echo "Clean up old files done."

wget -O $HOME/getting.sh "https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/getting.sh"
wget -O $HOME/vietbot.sh "https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/vietbot.sh"
chmod +x $HOME/getting.sh
chmod +x $HOME/vietbot.sh

echo "[1/2] Chuan bi cai dat..."
$HOME/getting.sh
echo "[2/2] Cai dat Voicebot..."
$HOME/vietbot.sh || true
echo "Cai dat hoan tat."
echo "Doi thiet bi khoi lai xong."
echo "Vao wifi Phicomm R1, truy cap http://192.168.43.1:8081 de cau hinh Wi-Fi cho thiet bi."
