#!/bin/bash
# SkyView Remote Access - Verification Script

echo "========================================"
echo "  SKYVIEW REMOTE ACCESS VERIFICATION"
echo "========================================"
echo ""

# Get IP
IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')

echo "IP Address: $IP"
echo ""

echo "=== RDP (Port 3389) ==="
if ss -tlnp 2>/dev/null | grep -q ":3389"; then
    echo "✓ RDP is LISTENING on port 3389"
else
    echo "✗ RDP is NOT listening (run: sudo systemctl start xrdp)"
fi

echo ""
echo "=== SSH (Port 2277) ==="
if ss -tlnp 2>/dev/null | grep -q ":2277"; then
    echo "✓ SSH is LISTENING on port 2277"
else
    echo "✗ SSH is NOT listening (run: sudo apt install openssh-server && sudo systemctl start sshd)"
fi

echo ""
echo "=== VNC (Port 5900) ==="
if ss -tlnp 2>/dev/null | grep -q ":5900"; then
    echo "✓ VNC is LISTENING on port 5900"
else
    echo "✗ VNC is NOT listening (run: sudo apt install tigervnc-standalone-server)"
fi

echo ""
echo "=== Services Enabled ==="
echo -n "xrdp: "
systemctl is-enabled xrdp 2>/dev/null || echo "not installed"
echo -n "sshd: "
systemctl is-enabled sshd 2>/dev/null || echo "not installed"
echo -n "skyview-remote: "
systemctl is-enabled skyview-remote 2>/dev/null || echo "not installed"

echo ""
echo "=== Desktop Environment ==="
echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-unknown}"
echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-unknown}"

echo ""
echo "========================================"
echo "  CONNECTION SUMMARY"
echo "========================================"
echo ""
echo "RDP: Microsoft Remote Desktop → $IP:3389"
echo "SSH: ssh -p 2277 skyview_user@$IP"
echo "VNC: TigerVNC Viewer → $IP:5900"
echo ""
