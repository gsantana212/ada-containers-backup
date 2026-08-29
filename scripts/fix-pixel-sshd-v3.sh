#!/data/data/com.termux/files/usr/bin/bash
# fix-pixel-sshd-v3.sh — write sshd log to $HOME/sshd.log (always writable)
set -uo pipefail

PREFIX='/data/data/com.termux/files/usr'
SSHDIR="$PREFIX/etc/ssh"
LOGFILE="$HOME/sshd.log"

echo "=== A: ensure dirs ==="
mkdir -p "$SSHDIR" "$HOME/.ssh"
chmod 700 "$SSHDIR" "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
echo "OK"
echo

echo "=== B: generate ed25519 host key ==="
yes | ssh-keygen -t ed25519 -f "$SSHDIR/ssh_host_ed25519_key" -N "" -C "termux-pixel-2026-08-29" 2>&1 | tail -2
echo

echo "=== C: generate rsa host key ==="
yes | ssh-keygen -t rsa -b 4096 -f "$SSHDIR/ssh_host_rsa_key" -N "" -C "termux-pixel-2026-08-29" 2>&1 | tail -2
echo

echo "=== D: perms ==="
chmod 600 "$SSHDIR/"ssh_host_*key
chmod 644 "$SSHDIR/"ssh_host_*key.pub
echo "host keys:"
ls -1 "$SSHDIR/"ssh_host_*key*
echo

echo "=== E: rewrite sshd_config (absolute paths) ==="
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
LogLevel VERBOSE
EOF
echo "OK"
echo

echo "=== F: install Ada's public key ==="
KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPiu2LU50Y6ajqIoxzG5BT+/E9dKDSyHJlvAk6B+ESkb ada-to-mesh-2026-08-29'
if ! grep -qF "$KEY" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
  echo "$KEY" >> "$HOME/.ssh/authorized_keys"
  echo "key installed"
else
  echo "key already present"
fi
echo

echo "=== G: kill prior sshd ==="
pkill -f sshd 2>/dev/null
sleep 1
echo "OK"
echo

echo "=== H: start sshd, log to $LOGFILE ==="
sshd -E "$LOGFILE"
sleep 2
echo

echo "=== I: verify listening on 8022 ==="
if ss -tlnp 2>/dev/null | grep -q ':8022 '; then
  echo "✅ sshd IS listening on port 8022"
  ss -tlnp 2>/dev/null | grep ':8022'
else
  echo "❌ not listening. sshd.log:"
  cat "$LOGFILE" 2>&1 | tail -20
  exit 1
fi
echo

echo "=== J: wake-lock ==="
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock 2>&1
  echo "OK"
fi
echo

echo "=== K: report ==="
TS_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+)3' | head -1)
echo "Termux user: $(whoami)"
echo "Home: $HOME"
echo "Tailscale IP: ${TS_IP:-NOT_RUNNING}"
echo
echo "Connect from srv1773565:"
echo "  ssh -p 8022 -i /root/.ssh/ada_mesh_ed25519 $(whoami)@${TS_IP:-<pixel-ip>}"
echo
echo "=== DONE ==="
