#!/data/data/com.termux/files/usr/bin/bash
# fix-pixel-sshd.sh — generates sshd host keys explicitly + starts sshd
# Run this AFTER run-on-pixel-termux.sh failed (or as a fresh install)
set -uo pipefail

echo "=== A: ensure ssh dir exists ==="
mkdir -p "$PREFIX/etc/ssh"
chmod 700 "$PREFIX/etc/ssh"
echo "OK"
echo

echo "=== B: generate ed25519 host key (explicit) ==="
ssh-keygen -t ed25519 -f "$PREFIX/etc/ssh/ssh_host_ed25519_key" -N "" -C "termux-pixel-2026-08-29" 2>&1 | head -3
echo

echo "=== C: generate rsa host key (4096-bit, OpenSSH 10+ removed DSA + ECDSA default) ==="
ssh-keygen -t rsa -b 4096 -f "$PREFIX/etc/ssh/ssh_host_rsa_key" -N "" -C "termux-pixel-2026-08-29" 2>&1 | head -3
echo

echo "=== D: verify host keys exist with correct perms ==="
ls -la "$PREFIX/etc/ssh/"ssh_host_*key*
chmod 600 "$PREFIX/etc/ssh/"ssh_host_*key
chmod 644 "$PREFIX/etc/ssh/"ssh_host_*key.pub
echo

echo "=== E: re-verify sshd_config (in case Step 5 was skipped) ==="
SSHD_CONFIG="$PREFIX/etc/ssh/sshd_config"
if ! grep -q "^Port 8022" "$SSHD_CONFIG" 2>/dev/null; then
  echo "writing sshd_config..."
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
else
  echo "sshd_config already has Port 8022"
fi
echo

echo "=== F: kill any previous sshd, start fresh ==="
pkill -f "sshd" 2>/dev/null || true
sleep 1
echo

echo "=== G: start sshd in DAEMON mode (not -D) ==="
# IMPORTANT: no -D flag. Without -D, sshd forks into a daemon and stays alive.
sshd -E /tmp/sshd.log
sleep 2
echo

echo "=== H: verify it's listening ==="
if ss -tlnp 2>/dev/null | grep -q ':8022 '; then
  echo "✅ sshd IS listening on port 8022"
  ss -tlnp 2>/dev/null | grep ':8022'
else
  echo "❌ still not listening. Log:"
  cat /tmp/sshd.log 2>&1
  exit 1
fi
echo

echo "=== I: acquire wake-lock ==="
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock 2>&1
  echo "Wake-lock acquired"
else
  echo "Install Termux:API from F-Droid for wake-lock"
fi
echo

echo "=== J: report Termux user + Tailscale IP ==="
echo "Termux user: $(whoami)"
echo "Termux home: $HOME"
echo "Termux prefix: $PREFIX"
TS_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
echo "Tailscale IP: ${TS_IP:-NOT_RUNNING}"
echo

echo "=== DONE ==="
echo "From srv1773565, connect with:"
echo "  ssh -p 8022 -i /root/.ssh/ada_mesh_ed25519 $(whoami)@${TS_IP:-<pixel-ip>}"
