#!/bin/sh

rm -f $HOME/*.apk
rm -f $HOME/*.sh
echo "Clean up old files done."

wget -O $HOME/taive.sh "https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/taive.sh"
wget -O $HOME/vietbotpre.sh "https://raw.githubusercontent.com/trunghieu1604/r1-sh/main/vietbotpre.sh"
chmod +x $HOME/taive.sh
chmod +x $HOME/vietbotpre.sh

echo "[1/2] Chuan bi cai dat..."
$HOME/taive.sh
echo "[2/2] Cai dat Vietbot..."
$HOME/vietbotpre.sh || true
echo "Cai dat hoan tat."
echo "Doi thiet bi khoi lai xong."
echo "Vao wifi Phicomm R1, truy cap http://192.168.43.1:8081 de cau hinh Wi-Fi cho thiet bi."