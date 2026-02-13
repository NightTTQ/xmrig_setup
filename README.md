# XMRig Setup

**English** | [中文](README.zh-CN.md)

One-click install scripts for XMRig: Windows and Linux, auto-detects x86-64 and ARM64, mines on [C3 Pool](https://c3pool.com). Built from [xmrig-Ponder](https://github.com/NightTTQ/xmrig-Ponder).

---

## Usage

### Recommended: Generate commands in browser

Open **[Command generator](http://mine.ponder.fun/)**, enter your XMR wallet address to get full install/uninstall commands for Windows or Linux, then copy and run them.

---

### Manual run (replace `<Wallet Address>` with your wallet address)

**Background & startup:** Both Windows and Linux get startup on boot and background persistence. On Windows, **run as Administrator** to register as an NSSM service (resistant to termination); otherwise only startup on boot. On Linux, the script registers a systemd service.

#### Windows (CMD)

- **GitHub:**

```cmd
powershell -Command "$wc = New-Object System.Net.WebClient; $tempfile = [System.IO.Path]::GetTempFileName(); $tempfile += '.bat'; $wc.DownloadFile('https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/setup_ponder_miner.bat', $tempfile); & $tempfile <Wallet Address>; Remove-Item -Force $tempfile"
```

- **Mirror:**

```cmd
powershell -Command "$wc = New-Object System.Net.WebClient; $tempfile = [System.IO.Path]::GetTempFileName(); $tempfile += '.bat'; $wc.DownloadFile('https://download.ponder.fun/xmrig_setup/setup_ponder_miner.bat', $tempfile); & $tempfile <Wallet Address>; Remove-Item -Force $tempfile"
```

#### Linux (terminal)

- **GitHub:**

```bash
curl -s -L https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/setup_ponder_miner.sh | LC_ALL=en_US.UTF-8 bash -s <Wallet Address>
```

- **Mirror:**

```bash
curl -s -L https://download.ponder.fun/xmrig_setup/setup_ponder_miner.sh | LC_ALL=en_US.UTF-8 bash -s <Wallet Address>
```

#### Linux service (systemctl)

| Action   | Command                                  |
| -------- | ---------------------------------------- |
| View log | `tail -f $HOME/ponder/xmrig.log`         |
| Stop     | `systemctl stop ponder_miner.service`    |
| Start    | `systemctl start ponder_miner.service`   |
| Restart  | `systemctl restart ponder_miner.service` |

#### Uninstall

**Windows (CMD)**

- GitHub:

```cmd
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $tempfile = [System.IO.Path]::GetTempFileName(); $tempfile += '.bat'; $wc.DownloadFile('https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/uninstall_ponder_miner.bat', $tempfile); & $tempfile; Remove-Item -Force $tempfile"
```

- Mirror:

```cmd
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $tempfile = [System.IO.Path]::GetTempFileName(); $tempfile += '.bat'; $wc.DownloadFile('https://download.ponder.fun/xmrig_setup/uninstall_ponder_miner.bat', $tempfile); & $tempfile; Remove-Item -Force $tempfile"
```

**Linux (terminal)**

- GitHub:

```bash
curl -s -L https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/uninstall_ponder_miner.sh | bash -s
```

- Mirror:

```bash
curl -s -L https://download.ponder.fun/xmrig_setup/uninstall_ponder_miner.sh | bash -s
```

---

## Links

- [Command generator](http://mine.ponder.fun/) · [XMRig-Ponder](https://github.com/NightTTQ/xmrig-Ponder) · [C3 Pool](https://c3pool.com) · [Ponder](https://ponder.fun)
