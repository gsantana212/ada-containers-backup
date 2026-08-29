#!/data/data/com.termux/files/usr/bin/bash
# run-on-pixel-termux.sh — paste into Termux on pixel-10a
# Installs openssh in Termux, starts sshd on port 8022, installs Ada's ed25519 key,
# sets up wake-lock so sshd stays alive, and prints the connect command.
# Author: Ada (srv1773565) via Gio
# Date: 2026-08-29

set -euo pipefail

echo "=== Step 1: ensure openssh + termux-api installed ==="
pkg update -y >/dev/null 2>&1 || true
pkg install -y openssh termux-api termux-tools 2>&1 | tail -5
echo

echo "=== Step 2: setup ~/.ssh ==="
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "OK"
echo

echo "=== Step 3: install Ada's ed25519 public key ==="
KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPiu2LU50Y6ajqIoxzG5BT+/E9dKDSyHJlvAk6B+ESkb ada-to-mesh-2026-08-29'
if grep -qF "$KEY" ~/.ssh/authorized_keys 2>/dev/null; then
  echo "Key already installed"
else
  echo "$KEY" >> ~/.ssh/authorized_keys
  echo "Key installed"
fi
echo

echo "=== Step 4: generate sshd host key (idempotent) ==="
ssh-keygen -A 2>&1 | tail -3
echo

echo "=== Step 5: write sshd_config (port 8022, key-only, no root) ==="
SSHD_CONFIG="$PREFIX/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak.2026-08-29" 2>/dev/null || true
cat > "$SSHD_CONFIG" <<'EOF'
Port 8022
HostKey $PREFIX/etc/ssh/ssh_host_ed25519_key
HostKey $PREFIX/etc/ssh/ssh_host_rsa_key
AuthorizedKeysFile  ~/.ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers *
Subsystem sftp $PREFIX/libexec/sftp-server
EOF
echo "sshd_config written"
echo

echo "=== Step 6: start sshd on port 8022 ==="
# Kill any existing sshd
pkill -f "sshd -D" 2>/dev/null || true
sleep 1
# Start sshd in background with explicit PID file
nohup sshd -E /tmp/sshd.log >/dev/null 2>&1 &
sleep 2
# Verify it's listening
if ss -tlnp 2>/dev/null | grep -q ':8022 '; then
  echo "sshd is listening on port 8022"
else
  echo "WARNING: sshd not listening. Log:"
  cat /tmp/sshd.log 2>/dev/null | tail -10
fi
echo

echo "=== Step 7: acquire wake-lock so phone doesn't sleep sshd ==="
# This requires termux-api + the Termux:API app installed from F-Droid.
# If termux-wake-lock is unavailable, sshd will die when phone sleeps.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock 2>&1 | head -3
  echo "Wake-lock acquired"
else
  echo "WARNING: termux-wake-lock not found. Install Termux:API app from F-Droid:"
  echo "  https://f-droid.org/en/packages/com.termux.api/"
fi
echo

echo "=== Step 8: print the Tailscale IP + connect command ==="
# Tailscale usually doesn't expose the IP via termux, but we can grep from /proc/net
TS_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [ -z "$TS_IP" ]; then
  TS_IP="(tailscale not running — start it from the Tailscale Android app)"
fi
echo "Tailscale IP: $TS_IP"
echo "Termux listens on: $TS_IP:8022"
echo
echo "=== To test from srv1773565 (Ada's VPS) ==="
echo "  ssh -p 8022 -i /root/.ssh/ada_mesh_ed25519 root@$TS_IP 'echo PIXEL_OK; uname -a'"
echo
echo "=== DONE ==="
echo "If you saw 'sshd is listening on port 8022' above, the mesh is connected."
echo "If Termux dies when the phone sleeps, install Termux:API app + termux-wake-lock,"
echo "or run 'termux-wake-lock' manually each session."
