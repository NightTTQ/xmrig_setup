#!/bin/bash

VERSION=1.0

# printing greetings

echo "ponder mining uninstall script v$VERSION."
echo "(please report issues to ttq@ponder.fun email with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists"
  exit 1
fi

echo "[*] Removing ponder miner"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop ponder_miner.service
  sudo systemctl disable ponder_miner.service
  rm -f /etc/systemd/system/ponder_miner.service
  sudo systemctl daemon-reload
  sudo systemctl reset-failed
fi

sed -i '/ponder/d' $HOME/.profile
killall -9 xmrig

echo "[*] Removing $HOME/ponder directory"
rm -rf $HOME/ponder

echo "[*] Uninstall complete"

