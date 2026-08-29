#!/usr/bin/env bash
# run-on-lab0.sh — paste into lab0 root shell to grant srv1773565 mesh access
# Enables Tailscale SSH server-side + installs Ada's ed25519 public key
# Author: Ada (srv1773565)
# Date: 2026-08-29

set -euo pipefail

echo "=== Step 1: enable Tailscale SSH server-side on lab0 ==="
if command -v tailscale >/dev/null 2>&1; then
  tailscale set --ssh
  sleep 1
  echo "Tailscale SSH enabled."
else
  echo "ERROR: tailscale not found in PATH. Install Tailscale first:"
  echo "  curl -fsSL https://tailscale.com/install.sh | sh"
  exit 1
fi
echo

echo "=== Step 2: verify SSH capability is advertised ==="
if tailscale status --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); caps=d.get('Self',{}).get('Capabilities',[]); ssh_caps=[c for c in caps if 'ssh' in c.lower()]; sys.exit(0 if ssh_caps else 1)" 2>/dev/null; then
  echo "SSH capability: OK"
  tailscale status --json | python3 -c "import json,sys; d=json.load(sys.stdin); print('  Capabilities:', [c for c in d.get('Self',{}).get('Capabilities',[]) if 'ssh' in c.lower()])"
else
  echo "ERROR: SSH capability not advertised. Try: sudo tailscale set --ssh"
  exit 2
fi
echo

echo "=== Step 3: install Ada's public key ==="
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPiu2LU50Y6ajqIoxzG5BT+/E9dKDSyHJlvAk6B+ESkb ada-to-mesh-2026-08-29'

if grep -qF "$KEY" ~/.ssh/authorized_keys; then
  echo "Key already installed"
else
  echo "$KEY" >> ~/.ssh/authorized_keys
  echo "Key installed"
fi
echo

echo "=== Step 4: verify ==="
echo "authorized_keys contains ada-to-mesh: $(grep -c ada-to-mesh ~/.ssh/authorized_keys) entries"
echo

echo "=== DONE ==="
echo "Now srv1773565 can run 'tailscale ssh lab0' to reach you."
echo "Test from srv1773565:"
echo "  tailscale ssh lab0 'echo MESH_OK; uname -a'"
