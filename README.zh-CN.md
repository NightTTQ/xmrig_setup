# XMRig Setup

[English](README.md) | **中文**

XMRig 一键安装脚本，支持 Windows / Linux，自动识别 x86-64 与 ARM64，接入 [C3 Pool](https://c3pool.com) 挖矿。基于 [xmrig-Ponder](https://github.com/NightTTQ/xmrig-Ponder) 构建。

---

## 使用指南

### 推荐：网页生成命令

打开 **[命令生成工具](http://mine.ponder.fun/)**，输入 XMR 钱包地址即可生成 Windows/Linux 的完整安装与卸载命令，复制执行即可。

---

### 手动执行（将 `<Wallet Address>` 换为你的钱包地址）

**后台与自启**：Windows / Linux 均会配置开机自启与后台常驻。Windows 下**以管理员运行**则用 NSSM 注册为服务（防杀）；非管理员仅开机自启。Linux 使用 systemd 注册为服务。

#### Windows（CMD）

- **GitHub 源：**

```cmd
powershell -Command "$wc = New-Object System.Net.WebClient; $tempfile = [System.IO.Path]::GetTempFileName(); $tempfile += '.bat'; $wc.DownloadFile('https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/setup_ponder_miner.bat', $tempfile); & $tempfile <Wallet Address>; Remove-Item -Force $tempfile"
```

- **镜像源：**

```cmd
powershell -Command "$wc = New-Object System.Net.WebClient; $tempfile = [System.IO.Path]::GetTempFileName(); $tempfile += '.bat'; $wc.DownloadFile('https://download.ponder.fun/xmrig_setup/setup_ponder_miner.bat', $tempfile); & $tempfile <Wallet Address>; Remove-Item -Force $tempfile"
```

#### Linux（终端）

- **GitHub 源：**

```bash
curl -s -L https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/setup_ponder_miner.sh | LC_ALL=en_US.UTF-8 bash -s <Wallet Address>
```

- **镜像源：**

```bash
curl -s -L https://download.ponder.fun/xmrig_setup/setup_ponder_miner.sh | LC_ALL=en_US.UTF-8 bash -s <Wallet Address>
```

#### Linux 服务管理

| 操作     | 命令                                     |
| -------- | ---------------------------------------- |
| 查看日志 | `tail -f $HOME/ponder/xmrig.log`         |
| 停止     | `systemctl stop ponder_miner.service`    |
| 启动     | `systemctl start ponder_miner.service`   |
| 重启     | `systemctl restart ponder_miner.service` |

#### 卸载

**Windows（CMD）**

- GitHub：

```cmd
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $tempfile = [System.IO.Path]::GetTempFileName(); $tempfile += '.bat'; $wc.DownloadFile('https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/uninstall_ponder_miner.bat', $tempfile); & $tempfile; Remove-Item -Force $tempfile"
```

- 镜像：

```cmd
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $tempfile = [System.IO.Path]::GetTempFileName(); $tempfile += '.bat'; $wc.DownloadFile('https://download.ponder.fun/xmrig_setup/uninstall_ponder_miner.bat', $tempfile); & $tempfile; Remove-Item -Force $tempfile"
```

**Linux（终端）**

- GitHub：

```bash
curl -s -L https://raw.githubusercontent.com/NightTTQ/xmrig_setup/master/uninstall_ponder_miner.sh | bash -s
```

- 镜像：

```bash
curl -s -L https://download.ponder.fun/xmrig_setup/uninstall_ponder_miner.sh | bash -s
```

---

## 链接

- [命令生成页](http://mine.ponder.fun/) · [XMRig-Ponder](https://github.com/NightTTQ/xmrig-Ponder) · [C3 Pool](https://c3pool.com)
