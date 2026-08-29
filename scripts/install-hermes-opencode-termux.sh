#!/data/data/com.termux/files/usr/bin/bash
# install-hermes-opencode-termux.sh — installs full stack on Pixel 10a Termux
# Run as Termux user (no root needed for user-local install)
set -uo pipefail

PREFIX='/data/data/com.termux/files/usr'
HOME='/data/data/com.termux/files/home'

echo "=== A: install system packages ==="
pkg update -y >/dev/null 2>&1 || true
pkg install -y python nodejs-lts git curl wget openssh 2>&1 | tail -3
echo

echo "=== B: verify versions ==="
echo "python: $(python --version 2>&1)"
echo "node:   $(node --version 2>&1)"
echo "git:    $(git --version 2>&1)"
echo "curl:   $(curl --version | head -1)"
echo

echo "=== C: install uv (fast Python package manager) ==="
curl -fsSL https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$PREFIX/bin" sh 2>&1 | tail -5
export PATH="$PREFIX/bin:$PATH"
uv --version
echo

echo "=== D: install hermes-agent ==="
# Clone the install dir
HERMES_HOME="$HOME/.hermes"
mkdir -p "$HERMES_HOME"
cd "$HERMES_HOME"
# Pull a specific tag - latest stable as of 2026-08-29
git clone --depth=1 https://github.com/just-every/hermes-agent.git hermes-agent-src 2>&1 | tail -3 || \
git clone --depth=1 https://github.com/hermes-agent/hermes-agent.git hermes-agent-src 2>&1 | tail -3
echo

echo "=== E: install hermes CLI ==="
if [ -d "$HERMES_HOME/hermes-agent-src" ]; then
  cd "$HERMES_HOME/hermes-agent-src"
  # Use uv for fast dep install
  uv venv "$HERMES_HOME/venv" 2>&1 | tail -3
  source "$HERMES_HOME/venv/bin/activate"
  uv pip install -e . 2>&1 | tail -5
  # Symlink to PATH
  ln -sf "$HERMES_HOME/venv/bin/hermes" "$PREFIX/bin/hermes"
  echo "hermes installed: $(hermes --version 2>&1 | head -2)"
fi
echo

echo "=== F: install opencode (Go binary) ==="
# Use the official installer
curl -fsSL https://raw.githubusercontent.com/sst/opencode/main/install.sh | bash 2>&1 | tail -5 || true
ls -la "$HOME/.local/bin/opencode" 2>&1
if [ -x "$HOME/.local/bin/opencode" ]; then
  ln -sf "$HOME/.local/bin/opencode" "$PREFIX/bin/opencode"
fi
echo "opencode: $(opencode --version 2>&1 | head -2)"
echo

echo "=== G: install dsh (DeepSeek Harness) ==="
# dsh needs node + pnpm. node-lts is installed; pnpm via corepack
corepack enable pnpm 2>&1 | tail -3 || pkg install -y pnpm 2>&1 | tail -3
mkdir -p "$HOME/.local/share/pnpm"
export PNPM_HOME="$HOME/.local/share/pnpm"
git clone --depth=1 https://github.com/deepseek-ai/deepseek-harness.git /opt/deepseek-harness 2>&1 | tail -3 || mkdir -p /opt/deepseek-harness && cd /opt/deepseek-harness
cd /opt/deepseek-harness 2>/dev/null && pnpm install --prefer-offline 2>&1 | tail -3
echo

echo "=== H: install the grok CLI (Grok Build) ==="
curl -fsSL https://x.ai/cli/install.sh | env GROK_INSTALL_DIR="$PREFIX/bin" bash 2>&1 | tail -5 || true
echo "grok: $(grok --version 2>&1 | head -2)"
echo

echo "=== I: install EVA wrappers ==="
mkdir -p "$HOME/.hermes/bin"
cat > "$HOME/.hermes/bin/eva1" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec hermes chat --profile eva1 --provider openrouter --model openrouter/free --yolo --query "$*"
EOF
cat > "$HOME/.hermes/bin/eva2" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
export DEEPSEEK_API_KEY="sk-or-v1-fake-key-replace-at-runtime"
export DEEPSEEK_BASE_URL="https://openrouter.ai/api/v1"
export DEEPSEEK_MODEL="deepseek/deepseek-v4-flash"
cd /opt/deepseek-harness 2>/dev/null && pnpm dsh --profile headless "$*" 2>/dev/null || echo "dsh not available on this box"
EOF
cat > "$HOME/.hermes/bin/eva3" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
if [[ -n "$XAI_API_KEY" ]] && command -v grok >/dev/null 2>&1; then
  exec grok -p "$*" --output-format plain --yolo
fi
exec hermes chat --profile ada --provider openrouter --model qwen/qwen3.7-flash --yolo --query "$*"
EOF
chmod +x "$HOME/.hermes/bin/eva1" "$HOME/.hermes/bin/eva2" "$HOME/.hermes/bin/eva3"
ln -sf "$HOME/.hermes/bin/eva1" "$PREFIX/bin/eva1"
ln -sf "$HOME/.hermes/bin/eva2" "$PREFIX/bin/eva2"
ln -sf "$HOME/.hermes/bin/eva3" "$PREFIX/bin/eva3"
echo "eva1/eva2/eva3 installed"
echo

echo "=== J: install joplin CLI (knowledge backend) ==="
npm install -g joplin 2>&1 | tail -3 || true
echo "joplin: $(joplin --version 2>&1 | head -2)"
echo

echo "=== K: add ada-mesh-key to authorized_keys (idempotent) ==="
KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPiu2LU50Y6ajqIoxzG5BT+/E9dKDSyHJlvAk6B+ESkb ada-to-mesh-2026-08-29'
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys" && chmod 600 "$HOME/.ssh/authorized_keys"
if ! grep -qF "$KEY" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
  echo "$KEY" >> "$HOME/.ssh/authorized_keys"
  echo "ada-mesh key installed"
fi
echo

echo "=== L: final inventory ==="
echo "Hermes:    $(hermes --version 2>&1 | head -1)"
echo "OpenCode:  $(opencode --version 2>&1 | head -1)"
echo "DSH:       $(cd /opt/deepseek-harness 2>/dev/null && pnpm dsh --version 2>&1 | tail -1)"
echo "Grok:      $(grok --version 2>&1 | head -1)"
echo "Python:    $(python --version 2>&1)"
echo "Node:      $(node --version 2>&1)"
echo "Git:       $(git --version 2>&1)"
echo

echo "=== DONE ==="
echo "Mesh tools installed. To use from srv1773565:"
echo "  ssh -p 8022 -i /root/.ssh/ada_mesh_ed25519 u0_a179@100.111.165.85 'eva1 hello'"
