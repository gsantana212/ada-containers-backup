#!/data/data/com.termux/files/usr/bin/bash
# fix-pixel-sshd-v2.sh — actually works, expands $PREFIX properly
# Use ABSOLUTE paths in sshd_config (Termux sshd doesn't expand $PREFIX env var)
set -uo pipefail

PREFIX='/data/data/com.termux/files/usr'
SSHDIR="$PREFIX/etc/ssh"

echo "=== A: ensure ssh dir exists ==="
mkdir -p "$SSHDIR"
chmod 700 "$SSHDIR"
echo "OK"
echo

echo "=== B: generate ed25519 host key (force overwrite if exists) ==="
yes | ssh-keygen -t ed25519 -f "$SSHDIR/ssh_host_ed25519_key" -N "" -C "termux-pixel-2026-08-29" 2>&1 | tail -3
echo

echo "=== C: generate rsa host key ==="
yes | ssh-keygen -t rsa -b 4096 -f "$SSHDIR/ssh_host_rsa_key" -N "" -C "termux-pixel-2026-08-29" 2>&1 | tail -3
echo

echo "=== D: fix permissions ==="
chmod 600 "$SSHDIR/"ssh_host_*key
chmod 644 "$SSHDIR/"ssh_host_*key.pub
ls -la "$SSHDIR/"ssh_host_*key*
echo

echo "=== E: rewrite sshd_config with ABSOLUTE paths ==="
SSHD_CONFIG="$SSHDIR/sshd_config"
cat > "$SSHD_CONFIG" <<EOF
Port 8022
HostKey /data/data/com.termux/files/usr/etc/ssh/ssh_host_ed25519_key
HostKey /data/data/com.termux/files/usr/etc/ssh/ssh_host_rsa_key
AuthorizedKeysFile  ~/.ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers *
Subsystem sftp /data/data/com.termux/files/usr/libexec/sftp-server
EOF
echo "sshd_config:"
cat "$SSHD_CONFIG"
echo

echo "=== F: kill any previous sshd ==="
pkill -f "sshd" 2>/dev/null
sleep 1
echo "OK"
echo

echo "=== G: start sshd WITHOUT -D (daemon mode) ==="
sshd -E /tmp/sshd.log
sleep 2
echo

echo "=== H: verify listening on 8022 ==="
if ss -tlnp 2>/dev/null | grep -q ':8022 '; then
  echo "✅ sshd IS listening on port 8022"
  ss -tlnp 2>/dev/null | grep ':8022'
else
  echo "❌ still not listening. Log:"
  cat /tmp/sshd.log 2>&1 | tail -15
  exit 1
fi
echo

echo "=== I: wake-lock ==="
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock
  echo "OK"
else
  echo "Install Termux:API from F-Droid"
fi
echo

echo "=== J: report ==="
TS_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+)3' | head -1)
echo "Termux user: $(whoami)"
echo "Tailscale IP: ${TS_IP:-NOT_RUNNING}"
echo
echo "Connect from srv1773565:"
echo "  ssh -p 8022 -i /root/.ssh/ada_mesh_ed25519 $(whoami)@${TS_IP:-<pixel-ip>}"
echo
echo "=== DONE ==="
