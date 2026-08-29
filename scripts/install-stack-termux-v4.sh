#!/data/data/com.termux/files/usr/bin/bash
# install-stack-termux-v4.sh — fixed for Termux (no /opt write, no root, aarch64)
set -uo pipefail

PREFIX='/data/data/com.termux/files/usr'
HOME='/data/data/com.termux/files/home'

echo "=== A: base packages ==="
pkg update -y >/dev/null 2>&1 || true
pkg install -y python nodejs-lts git curl wget openssh 2>&1 | tail -3
echo

echo "=== B: versions ==="
echo "python: $(python --version 2>&1)"
echo "node:   $(node --version 2>&1)"
echo "git:    $(git --version 2>&1)"
echo

echo "=== C: install uv (Python package mgr) ==="
# Use Termux pkg - uv isn't packaged but pip works
pip install --quiet uv 2>&1 | tail -3
uv --version 2>&1 || echo "uv install failed"
echo

echo "=== D: install hermes-agent CLI (using main repo) ==="
HERMES_HOME="$HOME/.hermes"
mkdir -p "$HERMES_HOME"
cd "$HERMES_HOME"
# Try the canonical repo first, fallback to a tarball
git clone --depth=1 https://github.com/just-every/hermes-agent.git hermes-agent-src 2>&1 | tail -3 || true
if [ ! -d hermes-agent-src ]; then
  echo "trying alternative repo..."
  git clone --depth=1 https://github.com/hermes-agent-community/hermes-cli.git hermes-agent-src 2>&1 | tail -3
fi
if [ -d hermes-agent-src ]; then
  cd hermes-agent-src
  python -m venv "$HERMES_HOME/venv" 2>&1 | tail -2
  source "$HERMES_HOME/venv/bin/activate"
  pip install --quiet -e . 2>&1 | tail -3 || pip install --quiet . 2>&1 | tail -3
  ln -sf "$HERMES_HOME/venv/bin/hermes" "$PREFIX/bin/hermes" 2>/dev/null
  echo "hermes: $(hermes --version 2>&1 | head -2)"
fi
echo

echo "=== E: install OpenCode CLI (binary release for aarch64) ==="
# Try npm first, then fallback to direct binary
npm install -g opencode-ai 2>&1 | tail -5 || true
which opencode && opencode --version 2>&1 | head -1 || echo "opencode not installed via npm"
echo

echo "=== F: install dsh (DeepSeek Harness) - HOME, not /opt ==="
# Termux can't write to /opt. Use $HOME instead.
DSH_HOME="$HOME/.local/share/deepseek-harness"
mkdir -p "$DSH_HOME"
git clone --depth=1 https://github.com/deepseek-ai/deepseek-harness.git "$DSH_HOME" 2>&1 | tail -3
cd "$DSH_HOME"
# pnpm via corepack
corepack enable pnpm 2>&1 | tail -2 || pkg install -y pnpm 2>&1 | tail -2
# install with no-frozen-lockfile since no lockfile present
pnpm install --no-frozen-lockfile --prefer-offline 2>&1 | tail -5
echo "dsh dir: $DSH_HOME"
# Update EVA2 wrapper to point here
echo

echo "=== G: install grok CLI (aarch64 binary) ==="
# x.ai CLI may not have aarch64 build - check first
curl -fsSL https://x.ai/cli/install.sh -o /tmp/grok-install.sh 2>&1
sh /tmp/grok-install.sh 2>&1 | tail -10 || echo "grok install attempted"
ls -la "$HOME/.grok/bin/" 2>&1 | head -5
ln -sf "$HOME/.grok/bin/grok" "$PREFIX/bin/grok" 2>/dev/null
echo

echo "=== H: install joplin CLI (skip - slow npm install) ==="
# Skip joplin - it's optional and slow on Termux. Will use filesystem instead.
echo "Joplin skipped (use filesystem-based knowledge instead)"
echo

echo "=== I: install EVA wrappers with correct paths ==="
mkdir -p "$HOME/.hermes/bin"
cat > "$HOME/.hermes/bin/eva1" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash
exec hermes chat --profile eva1 --provider openrouter --model openrouter/free --yolo --query "$*"
WRAP
cat > "$HOME/.hermes/bin/eva2" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash
DSH_HOME="$HOME/.local/share/deepseek-harness"
if [ ! -d "$DSH_HOME" ]; then
  echo "ERROR: dsh not installed at $DSH_HOME" >&2
  exit 2
fi
export DEEPSEEK_API_KEY="${OPENROUTER_API_KEY:-sk-placeholder}"
export DEEPSEEK_BASE_URL="https://openrouter.ai/api/v1"
export DEEPSEEK_MODEL="deepseek/deepseek-v4-flash"
cd "$DSH_HOME"
exec pnpm dsh --profile headless "$*"
WRAP
cat > "$HOME/.hermes/bin/eva3" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash
if [[ -n "$XAI_API_KEY" ]] && command -v grok >/dev/null 2>&1; then
  exec grok -p "$*" --output-format plain --yolo
fi
exec hermes chat --profile ada --provider openrouter --model qwen/qwen3.7-flash --yolo --query "$*"
WRAP
chmod +x "$HOME/.hermes/bin/eva1" "$HOME/.hermes/bin/eva2" "$HOME/.hermes/bin/eva3"
ln -sf "$HOME/.hermes/bin/eva1" "$PREFIX/bin/eva1"
ln -sf "$HOME/.hermes/bin/eva2" "$PREFIX/bin/eva2"
ln -sf "$HOME/.hermes/bin/eva3" "$PREFIX/bin/eva3"
echo "EVA wrappers installed"
echo

echo "=== J: final inventory ==="
echo "Hermes:    $(hermes --version 2>&1 | head -1)"
echo "OpenCode:  $(opencode --version 2>&1 | head -1)"
echo "DSH:       $(cd $HOME/.local/share/deepseek-harness 2>/dev/null && pnpm dsh --version 2>&1 | tail -1)"
echo "Grok:      $(grok --version 2>&1 | head -1)"
echo "eva1:      $(which eva1 2>&1)"
echo "eva2:      $(which eva2 2>&1)"
echo "eva3:      $(which eva3 2>&1)"
echo "sshd:      $(ss -tlnp 2>/dev/null | grep ':8022 ' || echo 'NOT LISTENING')"
echo "termux-wake-lock: $(command -v termux-wake-lock 2>&1 || echo 'install Termux:API from F-Droid')"
echo

echo "=== DONE ==="
echo "Mesh tools installed. Verify from srv1773565:"
echo "  ssh -p 8022 -i /root/.ssh/ada_mesh_ed25519 u0_a179@100.111.165.85 'hermes --version; eva1 hello'"
