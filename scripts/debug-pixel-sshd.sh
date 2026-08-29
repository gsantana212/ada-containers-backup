#!/data/data/com.termux/files/usr/bin/bash
# debug-pixel-sshd.sh — diagnose why sshd isn't starting
set -uo pipefail

echo "=== A: sshd binary ==="
which sshd
ls -la "$PREFIX/bin/sshd" 2>&1 | head -2
echo

echo "=== B: sshd_config present ==="
ls -la "$PREFIX/etc/ssh/" 2>&1
echo

echo "=== C: host keys ==="
ls -la "$PREFIX/etc/ssh/"ssh_host_*key 2>&1
echo

echo "=== D: try sshd in foreground briefly (foreground test) ==="
echo "---running sshd in test mode (will exit after 2s)---"
timeout 2 sshd -D -e 2>&1 | head -20 || echo "(timeout - that's expected, means sshd ran but was killed)"
echo

echo "=== E: try sshd without -E flag (use stderr) ==="
nohup sshd -D >/tmp/sshd2.log 2>&1 &
SLEEPD=$!
sleep 2
kill $SLEEPD 2>/dev/null
echo "--- /tmp/sshd2.log ---"
cat /tmp/sshd2.log 2>&1 | head -20
echo

echo "=== F: check listening sockets ==="
ss -tlnp 2>&1 | head -10
echo

echo "=== G: try PRIVILEGED mode (Termux runs as uid 10000, sshd wants root) ==="
echo "Termux uid: $(id -u)"
echo "sshd needs port 8022 - check if we can bind without root"
echo

echo "=== H: look at original sshd error if any ==="
ls -la /tmp/sshd*.log 2>&1
cat /tmp/sshd.log 2>&1 | head -20
echo

echo "=== I: explicit verbose start ==="
echo "running: sshd -ddd -p 8022 (debug mode, will fail to background)..."
timeout 5 sshd -ddd -p 8022 2>&1 | head -40
echo
echo "=== DONE ==="
