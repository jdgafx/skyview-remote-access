# 🌐 SkyView Remote Access

![Status](https://img.shields.io/badge/status-active-success-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Linux-orange)

**Universal Remote Desktop Access System for Linux**

Complete automation for SSH, RDP, and VNC remote access with
intelligent configuration management and automatic setup.

> 💡 **IT JUST WORKS** - Automatic setup with zero configuration required

## 🚀 Quick Start

**One-command installation**:
```bash
curl -fsSL https://raw.githubusercontent.com/jdgafx/skyview-remote-access/main/skyview_setup.sh | bash
```

## ✨ Features

### 🔐 Multi-Protocol Support
- **SSH**: Secure shell access on custom ports (default: 2277)
- **RDP**: Remote Desktop Protocol (FreeRDP + xRDP)
- **VNC**: Virtual Network Computing (TigerVNC + x11vnc)
- **Native Wayland**: RDP-like experience on Wayland compositors (GNOME/KDE)

### 🎯 Automatic Configuration
- **OS Detection**: Ubuntu, Fedora, Arch, Debian, openSUSE
- **DE Detection**: KDE Plasma, GNOME, XFCE, Cinnamon, MATE
- **Port Management**: Dynamic port allocation and firewall (UFW/firewalld)
- **Service Auto-Enable**: Complete systemd integration

## 🏗️ System Architecture

```
skyview-remote-access/
├── 📁 src/              # Frontend (Vite + React + TS)
├── 📁 lib/              # Configuration library
│   ├── detect_os.sh       # OS/DE detection
│   ├── config_ssh.sh      # SSH setup
│   ├── config_rdp.sh      # RDP setup
│   └── config_vnc.sh      # VNC setup
├── 📁 docs/             # Documentation
└── 📁 scripts/           # Utility scripts
```

## 📊 Technical Details

### Protocol Support Matrix

| Protocol | Implementation | Default Port | Supported DEs |
|----------|----------------|---------------|----------------|
| **SSH** | OpenSSH server | 2277 | All |
| **RDP** | FreeRDP + xRDP | 3389 | GNOME, KDE, XFCE |
| **VNC** | TigerVNC | 5900+ | All |
| **Native** | Wayland RDP | Dynamic | KDE Plasma, GNOME |

## 🎮 Usage

### Access Remote System
```bash
# SSH (custom port)
ssh user@hostname -p 2277

# RDP
rdesktop hostname:3389

# VNC
vncviewer hostname:5900
```

### Web Dashboard
```bash
# Start development dashboard
npm run dev

# Access interface
http://localhost:5173
```

## 🔧 Configuration

### Environment Variables
```bash
# Remote access settings
SSH_PORT=2277
RDP_PORT=3389
VNC_PORT=5901

# Security
ENABLE_FIREWALL=true
ALLOWED_IPS="192.168.1.0/24"
```

## 🎯 Current Status

- [x] SSH module implementation ✅
- [x] RDP module implementation ✅
- [x] VNC module implementation ✅
- [x] OS/DE detection system ✅
- [x] Web dashboard core 🟢
- [ ] Auto-setup script testing 🟡
- [ ] Documentation site 🟡

---

Built with ❤️ for Linux remote access
