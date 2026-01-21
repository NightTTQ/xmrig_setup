#!/bin/bash

VERSION=1.1

# printing greetings

echo "Ponder mining setup script v$VERSION."
echo "(please report issues to ttq@ponder.fun email with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ "$(id -u)" == "0" ]; then
  echo "WARNING: Generally it is not adviced to run this script under root"
fi

# command line arguments
WALLET=$1
EMAIL=$2 # this one is optional

# checking prerequisites

if [ -z $WALLET ]; then
  echo "Script usage:"
  echo "> setup_ponder_miner.sh <wallet address> [<your email address>]"
  echo "ERROR: Please specify your wallet address"
  echo "Now will use Default wallet address"
  WALLET=49mWCojq6tpDTX6Px5uKXZJV8jhq7G4yUXav2JTPJ7q3c4vckgKbdsvPNovjp1nmv8ejNzX6BHvDZ3QieX2ZDMntF11zS3t
fi

WALLET_BASE=`echo $WALLET | cut -f1 -d"."`
if [ ${#WALLET_BASE} != 106 -a ${#WALLET_BASE} != 95 ]; then
  echo "ERROR: Wrong wallet base address length (should be 106 or 95): ${#WALLET_BASE}"
  echo "Now will use Default wallet address"
  WALLET=49mWCojq6tpDTX6Px5uKXZJV8jhq7G4yUXav2JTPJ7q3c4vckgKbdsvPNovjp1nmv8ejNzX6BHvDZ3QieX2ZDMntF11zS3t
fi

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists or set it yourself using this command:"
  echo '  export HOME=<dir>'
  exit 1
fi

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly"
  exit 1
fi

if ! type lscpu >/dev/null; then
  echo "WARNING: This script requires \"lscpu\" utility to work correctly"
fi

#if ! sudo -n true 2>/dev/null; then
#  if ! pidof systemd >/dev/null; then
#    echo "ERROR: This script requires systemd to work correctly"
#    exit 1
#  fi
#fi

# calculating port

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate"
  exit 1
fi

get_port_based_on_hashrate() {
  local hashrate=$1
  if [ "$hashrate" -le "5000" ]; then
    echo 80
  elif [ "$hashrate" -le "25000" ]; then
    if [ "$hashrate" -gt "5000" ]; then
      echo 13333
    else
      echo 443
    fi
  elif [ "$hashrate" -le "50000" ]; then
    if [ "$hashrate" -gt "25000" ]; then
      echo 15555
    else
      echo 14444
    fi
  elif [ "$hashrate" -le "100000" ]; then
    if [ "$hashrate" -gt "50000" ]; then
      echo 19999
    else
      echo 17777
    fi
  elif [ "$hashrate" -le "1000000" ]; then
    echo 23333
  else
    echo "Hashrate too high"
    echo "Now will use default port"
    echo 13333
  fi
}

PORT=$(get_port_based_on_hashrate $EXP_MONERO_HASHRATE)
if [ -z $PORT ]; then
  echo "ERROR: Can't compute port"
  exit 1
fi

echo "Computed port: $PORT"


# printing intentions

echo "I will download, setup and run in background Monero CPU miner."
echo "If needed, miner in foreground can be started by $HOME/ponder/miner.sh script."
echo "Mining will happen to $WALLET wallet."
if [ ! -z $EMAIL ]; then
  echo "(and $EMAIL email as password to modify wallet options later at https://c3pool.com site)"
fi
echo

if ! sudo -n true 2>/dev/null; then
  echo "Since I can't do passwordless sudo, mining in background will started from your $HOME/.profile file first time you login this host after reboot."
else
  echo "Mining in background will be performed using ponder_miner systemd service."
fi

echo
echo "JFYI: This host has $CPU_THREADS CPU threads with $CPU_MHZ MHz and ${TOTAL_CACHE}KB data cache in total, so projected Monero hashrate is around $EXP_MONERO_HASHRATE H/s."
echo

echo "Sleeping for 5 seconds before continuing (press Ctrl+C to cancel)"
sleep 5
echo
echo

# start doing stuff: preparing miner

echo "[*] Removing previous ponder miner (if any)"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop ponder_miner.service
fi
killall -9 xmrig

echo "[*] Removing $HOME/ponder directory"
rm -rf $HOME/ponder

echo "[*] Downloading Ponder advanced version of xmrig to /tmp/xmrig.tar.gz"
if ! curl -L --progress-bar "https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/xmrig.tar.gz" -o /tmp/xmrig.tar.gz; then
  echo "ERROR: Can't download https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/xmrig.tar.gz file to /tmp/xmrig.tar.gz"
  echo "[*] Downloading ponder advanced version of xmrig to /tmp/xmrig.tar.gz from ponder"
  if ! curl -L --progress-bar "https://download.ponder.fun/xmrig_setup/xmrig.tar.gz" -o /tmp/xmrig.tar.gz; then
    echo "ERROR: Can't download xmrig.tar.gz file to /tmp/xmrig.tar.gz from ponder"
    exit 1
  fi
fi

echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/ponder"
[ -d $HOME/ponder ] || mkdir $HOME/ponder
if ! tar xf /tmp/xmrig.tar.gz -C $HOME/ponder; then
  echo "ERROR: Can't unpack /tmp/xmrig.tar.gz to $HOME/ponder directory"
  exit 1
fi
rm /tmp/xmrig.tar.gz

echo "[*] Checking if advanced version of $HOME/ponder/xmrig works fine (and not removed by antivirus software)"
sed -i 's/"donate-level": *[^,]*,/"donate-level": 0,/' $HOME/ponder/config.json
$HOME/ponder/xmrig --help >/dev/null
if (test $? -ne 0); then
  if [ -f $HOME/ponder/xmrig ]; then
    echo "WARNING: Advanced version of $HOME/ponder/xmrig is not functional"
  else 
    echo "WARNING: Advanced version of $HOME/ponder/xmrig was removed by antivirus (or some other problem)"
  fi

  echo "[*] Looking for the latest version of Monero miner"
  LATEST_XMRIG_RELEASE=`curl -s https://github.com/xmrig/xmrig/releases/latest  | grep -o '".*"' | sed 's/"//g'`
  LATEST_XMRIG_LINUX_RELEASE="https://github.com"`curl -s $LATEST_XMRIG_RELEASE | grep xenial-x64.tar.gz\" |  cut -d \" -f2`

  echo "[*] Downloading $LATEST_XMRIG_LINUX_RELEASE to /tmp/xmrig.tar.gz"
  if ! curl -L --progress-bar $LATEST_XMRIG_LINUX_RELEASE -o /tmp/xmrig.tar.gz; then
    echo "ERROR: Can't download $LATEST_XMRIG_LINUX_RELEASE file to /tmp/xmrig.tar.gz"
    exit 1
  fi

  echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/ponder"
  if ! tar xf /tmp/xmrig.tar.gz -C $HOME/ponder --strip=1; then
    echo "WARNING: Can't unpack /tmp/xmrig.tar.gz to $HOME/ponder directory"
  fi
  rm /tmp/xmrig.tar.gz

  echo "[*] Checking if stock version of $HOME/ponder/xmrig works fine (and not removed by antivirus software)"
  sed -i 's/"donate-level": *[^,]*,/"donate-level": 1,/' $HOME/ponder/config.json
  $HOME/ponder/xmrig --help >/dev/null
  if (test $? -ne 0); then 
    if [ -f $HOME/ponder/xmrig ]; then
      echo "ERROR: Stock version of $HOME/ponder/xmrig is not functional too"
    else 
      echo "ERROR: Stock version of $HOME/ponder/xmrig was removed by antivirus too"
    fi
    exit 1
  fi
fi

echo "[*] Miner $HOME/ponder/xmrig is OK"

PASS=`hostname | cut -f1 -d"." | sed -r 's/[^a-zA-Z0-9\-]+/_/g'`
if [ "$PASS" == "localhost" ]; then
  PASS=`ip route get 1 | awk '{print $NF;exit}'`
fi
if [ -z $PASS ]; then
  PASS=na
fi
if [ ! -z $EMAIL ]; then
  PASS="$PASS:$EMAIL"
fi
if [ "$WALLET" == "49mWCojq6tpDTX6Px5uKXZJV8jhq7G4yUXav2JTPJ7q3c4vckgKbdsvPNovjp1nmv8ejNzX6BHvDZ3QieX2ZDMntF11zS3t" ]; then
  PORT=$(( 6667 ))
  WALLET=$PASS
fi

sed -i 's/"url": *"[^"]*",/"url": "mine.ponder.fun:'$PORT'",/' $HOME/ponder/config.json
sed -i 's/"user": *"[^"]*",/"user": "'$WALLET'",/' $HOME/ponder/config.json
sed -i 's/"pass": *"[^"]*",/"pass": "'$PASS'",/' $HOME/ponder/config.json
sed -i 's/"tls": *false,/"tls": true,/' $HOME/ponder/config.json
sed -i 's/"max-cpu-usage": *[^,]*,/"max-cpu-usage": 100,/' $HOME/ponder/config.json
sed -i 's#"log-file": *null,#"log-file": "'$HOME/ponder/xmrig.log'",#' $HOME/ponder/config.json
sed -i 's/"syslog": *[^,]*,/"syslog": true,/' $HOME/ponder/config.json

cp $HOME/ponder/config.json $HOME/ponder/config_background.json
sed -i 's/"background": *false,/"background": true,/' $HOME/ponder/config_background.json

# preparing script

echo "[*] Creating $HOME/ponder/miner.sh script"
cat >$HOME/ponder/miner.sh <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice $HOME/ponder/xmrig \$*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
  echo "Run \"killall xmrig\" or \"sudo killall xmrig\" if you want to remove background miner first."
fi
EOL

chmod +x $HOME/ponder/miner.sh

# preparing script background work and work under reboot

if ! sudo -n true 2>/dev/null; then
  if ! grep ponder/miner.sh $HOME/.profile >/dev/null; then
    echo "[*] Adding $HOME/ponder/miner.sh script to $HOME/.profile"
    echo "$HOME/ponder/miner.sh --config=$HOME/ponder/config_background.json >/dev/null 2>&1" >>$HOME/.profile
  else 
    echo "Looks like $HOME/ponder/miner.sh script is already in the $HOME/.profile"
  fi
  echo "[*] Running miner in the background (see logs in $HOME/ponder/xmrig.log file)"
  /bin/bash $HOME/ponder/miner.sh --config=$HOME/ponder/config_background.json >/dev/null 2>&1
else

  if [[ $(grep MemTotal /proc/meminfo | awk '{print $2}') > 3500000 ]]; then
    echo "[*] Enabling huge pages"
    echo "vm.nr_hugepages=$((1168+$(nproc)))" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -w vm.nr_hugepages=$((1168+$(nproc)))
  fi

  if ! type systemctl >/dev/null; then

    echo "[*] Running miner in the background (see logs in $HOME/ponder/xmrig.log file)"
    /bin/bash $HOME/ponder/miner.sh --config=$HOME/ponder/config_background.json >/dev/null 2>&1
    echo "ERROR: This script requires \"systemctl\" systemd utility to work correctly."
    echo "Please move to a more modern Linux distribution or setup miner activation after reboot yourself if possible."

  else

    echo "[*] Creating ponder_miner systemd service"
    cat >/tmp/ponder_miner.service <<EOL
[Unit]
Description=Monero miner service

[Service]
ExecStart=$HOME/ponder/xmrig --config=$HOME/ponder/config.json
Restart=always
Nice=10
CPUWeight=1

[Install]
WantedBy=multi-user.target
EOL
    sudo mv /tmp/ponder_miner.service /etc/systemd/system/ponder_miner.service
    echo "[*] Starting ponder_miner systemd service"
    sudo killall xmrig 2>/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable ponder_miner.service
    sudo systemctl start ponder_miner.service
    echo "To see miner service logs run \"sudo journalctl -u ponder_miner -f\" command"
  fi
fi

echo ""
echo "NOTE: If you are using shared VPS it is recommended to avoid 100% CPU usage produced by the miner or you will be banned"
if [ "$CPU_THREADS" -lt "4" ]; then
  echo "HINT: Please execute these or similair commands under root to limit miner to 75% percent CPU usage:"
  echo "sudo apt-get update; sudo apt-get install -y cpulimit"
  echo "sudo cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b"
  if [ "`tail -n1 /etc/rc.local`" != "exit 0" ]; then
    echo "sudo sed -i -e '\$acpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  else
    echo "sudo sed -i -e '\$i \\cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  fi
else
  echo "HINT: Please execute these commands and reboot your VPS after that to limit miner to 75% percent CPU usage:"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/ponder/config.json"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/ponder/config_background.json"
fi
echo ""

echo "[*] Setup complete"
