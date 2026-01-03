#!/bin/sh

rm -f $HOME/*.apk
rm -f $HOME/*.sh
echo "Clean up old files done."

wget -O $HOME/tai-files.sh "$DOMAIN/$VERSION/tai-files.sh"
wget -O $HOME/cai-dat-ai.sh "$DOMAIN/$VERSION/cai-dat-ai.sh"
wget -O $HOME/cai-dat-dlna-unisound.sh "$DOMAIN/$VERSION/cai-dat-dlna-unisound.sh"
chmod +x $HOME/tai-files.sh
chmod +x $HOME/cai-dat-ai.sh
chmod +x $HOME/cai-dat-dlna-unisound.sh

echo "[1/3] Chuan bi cai dat..."
$HOME/tai-files.sh $DOMAIN $VERSION
echo "[2/3] Cai dat DLNA va Unisound..."
$HOME/cai-dat-dlna-unisound.sh $VERSION || true
echo "[3/3] Cai dat AI Box Plus..."
$HOME/cai-dat-ai.sh $VERSION || true

echo "Cai dat hoan tat."
echo "Doi thiet bi khoi lai xong."
echo "Vao wifi Phicomm R1, truy cap http://192.168.43.1:8081 de cau hinh Wi-Fi cho thiet bi."