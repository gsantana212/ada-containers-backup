#!/data/data/com.termux/files/usr/bin/bash
# install-stack-termux-v5.sh — official NousResearch hermes-agent, fixed
set -uo pipefail

PREFIX='/data/data/com.termux/files/usr'
HOME='/data/data/com.termux/files/home'

echo "=== A: base packages ==="
pkg update -y >/dev/null 2>&1 || true
pkg install -y python nodejs-lts git curl wget openssh 2>&1 | tail -3
echo

echo "=== B: install hermes-agent (NousResearch - the official one) ==="
HERMES_HOME="$HOME/.hermes"
mkdir -p "$HERMES_HOME"
cd "$HERMES_HOME"
rm -rf hermes-agent-src
git clone --depth=1 https://github.com/NousResearch/hermes-agent.git hermes-agent-src 2>&1 | tail -3
if [ ! -d hermes-agent-src ]; then
  echo "ERROR: clone failed"
  exit 1
fi
cd hermes-agent-src
echo "submodule init..."
git submodule update --init --depth=1 2>&1 | tail -3
echo "venv setup..."
python -m venv "$HERMES_HOME/venv" 2>&1 | tail -2
source "$HERMES_HOME/venv/bin/activate"
pip install --quiet --upgrade pip wheel setuptools 2>&1 | tail -2
pip install --quiet -e . 2>&1 | tail -5
ln -sf "$HERMES_HOME/venv/bin/hermes" "$PREFIX/bin/hermes"
echo "hermes: $(hermes --version 2>&1 | head -2)"
echo

echo "=== C: install OpenCode (already there 1.2.13 - skip) ==="
echo "opencode: $(opencode --version 2>&1 | head -1)"
echo

echo "=== D: install dsh (DeepSeek Harness) - HOME, not /opt ==="
# Skip if already cloned
DSH_HOME="$HOME/.local/share/deepseek-harness"
if [ ! -d "$DSH_HOME/.git" ]; then
  mkdir -p "$(dirname $DSH_HOME)"
  git clone --depth=1 https://github.com/deepseek-ai/deepseek-harness.git "$DSH_HOME" 2>&1 | tail -3
fi
cd "$DSH_HOME"
# Skip esbuild - it's a JS bundler that needs prebuilt binaries for x86_64 not aarch64
# Use pnpm with --ignore-scripts to skip esbuild postinstall
corepack enable pnpm 2>&1 | tail -2 || pkg install -y pnpm 2>&1 | tail -2
# Use --ignore-scripts to skip esbuild postinstall (fails on Termux aarch64)
pnpm install --no-frozen-lockfile --ignore-scripts --prefer-offline 2>&1 | tail -5
echo "dsh: $(cd $DSH_HOME && pnpm dsh --version 2>&1 | tail -1)"
echo

echo "=== E: install grok CLI (try aarch64 binary) ==="
GROK_INSTALL_DIR="$HOME/.grok"
mkdir -p "$GROK_INSTALL_DIR"
curl -fsSL https://x.ai/cli/install.sh 2>/dev/null | env GROK_INSTALL_DIR="$GROK_INSTALL_DIR" bash 2>&1 | tail -5
ls -la "$GROK_INSTALL_DIR/bin/" 2>&1 | head -5
ln -sf "$GROK_INSTALL_DIR/bin/grok" "$PREFIX/bin/grok" 2>/dev/null
ln -sf "$GROK_INSTALL_DIR/bin/agent" "$PREFIX/bin/agent" 2>/dev/null
echo "grok: $(grok --version 2>&1 | head -1)"
echo

echo "=== F: install EVA wrappers ==="
mkdir -p "$HOME/.hermes/bin"
cat > "$HOME/.hermes/bin/eva1" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash
exec hermes chat --profile eva1 --provider openrouter --model openrouter/free --yolo --query "$*"
WRAP
cat > "$HOME/.hermes/bin/eva2" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash
DSH_HOME="$HOME/.local/share/deepseek-harness"
export DEEPSEEK_API_KEY="${OPENROUTER_API_KEY:-sk-placeholder}"
export DEEPSEEK_BASE_URL="https://openrouter.ai/api/v1"
export DEEPSEEK_MODEL="deepseek/deepseek-v4-flash"
cd "$DSH_HOME" && exec pnpm dsh --profile headless "$*"
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

echo "=== G: copy openrouter key from VPS env ==="
# Read key from VPS and write to pixel's .env
mkdir -p "$HOME/.hermes"
cat > "$HOME/.hermes/.env" <<'EOF'
OPENROUTER_API_KEY=__KEY__
EOF
echo "skeleton written - replace __KEY__ with real value"
echo

echo "=== H: final inventory ==="
echo "Hermes:    $(hermes --version 2>&1 | head -1)"
echo "OpenCode:  $(opencode --version 2>&1 | head -1)"
echo "DSH:       $(cd $HOME/.local/share/deepseek-harness 2>/dev/null && pnpm dsh --version 2>&1 | tail -1)"
echo "Grok:      $(grok --version 2>&1 | head -1)"
echo "eva1/2/3:  $(which eva1 eva2 eva3 2>&1 | tr '\n' ' ')"
echo

echo "=== DONE ==="
echo "Mesh tools installed. From srv1773565:"
echo "  ssh -p 8022 -i /root/.ssh/ada_mesh_ed25519 u0_a179@100.111.165.85 'eva1 hello'"
