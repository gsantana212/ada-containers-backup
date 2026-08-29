#!/data/data/com.termux/files/usr/bin/bash
# install-stack-termux-v6.sh — Hermes with --no-deps, skip firecrawl
set -uo pipefail

PREFIX='/data/data/com.termux/files/usr'
HOME='/data/data/com.termux/files/home'
HERMES_HOME="$HOME/.hermes"

echo "=== A: install hermes-agent without firecrawl-anydoc ==="
cd "$HERMES_HOME/hermes-agent-src"
source "$HERMES_HOME/venv/bin/activate"
# First upgrade pip + install core deps that DO have aarch64 wheels
pip install --quiet --upgrade pip wheel setuptools 2>&1 | tail -2
pip install --quiet httpx pydantic click rich pydantic-settings python-dotenv typer fastapi uvicorn websockets aiohttp requests PyYAML 2>&1 | tail -2
# Try the install with --no-deps and skip firecrawl-anydoc
pip install --quiet --no-deps -e . 2>&1 | tail -3
# Try to install remaining deps but skip firecrawl
pip install --quiet -e . --no-build-isolation 2>&1 | tail -5 || true
# Find firecrawl-anydoc in requirements and remove from optional
# Try just installing the package core
python -c "import hermes" 2>&1 | head -5 || pip install --quiet hermes-agent 2>&1 | tail -3
ln -sf "$HERMES_HOME/venv/bin/hermes" "$PREFIX/bin/hermes"
echo "hermes: $(hermes --version 2>&1 | head -2)"
echo

echo "=== B: copy OpenRouter key from VPS into pixel's .env ==="
mkdir -p "$HOME/.hermes"
KEY=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 8022 -i ~/.ssh/ada_mesh_ed25519 u0_a179@100.111.165.85 'echo "skip"' 2>/dev/null; echo "")
# Actually, run on the VPS side and SCP - but we are running on the pixel. So read key from environment if set.
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "WARN: OPENROUTER_API_KEY not in pixel env. Will read from /root/.hermes/.env if it exists."
  if [[ -f "$HOME/.hermes/.env" ]]; then
    source "$HOME/.hermes/.env"
  fi
fi
echo "OPENROUTER_API_KEY set: $([[ -n "${OPENROUTER_API_KEY:-}" ]] && echo YES || echo NO)"
echo

echo "=== C: update EVA wrappers to source .env ==="
cat > "$HOME/.hermes/bin/eva1" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash
[[ -f "$HOME/.hermes/.env" ]] && source "$HOME/.hermes/.env"
exec hermes chat --profile eva1 --provider openrouter --model openrouter/free --yolo --query "$*"
WRAP
cat > "$HOME/.hermes/bin/eva2" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash
[[ -f "$HOME/.hermes/.env" ]] && source "$HOME/.hermes/.env"
DSH_HOME="$HOME/.local/share/deepseek-harness"
export DEEPSEEK_API_KEY="${OPENROUTER_API_KEY:-sk-placeholder}"
export DEEPSEEK_BASE_URL="https://openrouter.ai/api/v1"
export DEEPSEEK_MODEL="deepseek/deepseek-v4-flash"
cd "$DSH_HOME" && exec pnpm dsh --profile headless "$*"
WRAP
cat > "$HOME/.hermes/bin/eva3" <<'WRAP'
#!/data/data/com.termux/files/usr/bin/bash
[[ -f "$HOME/.hermes/.env" ]] && source "$HOME/.hermes/.env"
if [[ -n "$XAI_API_KEY" ]] && command -v grok >/dev/null 2>&1; then
  exec grok -p "$*" --output-format plain --yolo
fi
exec hermes chat --profile ada --provider openrouter --model qwen/qwen3.7-flash --yolo --query "$*"
WRAP
chmod +x "$HOME/.hermes/bin/eva1" "$HOME/.hermes/bin/eva2" "$HOME/.hermes/bin/eva3"
echo "EVA wrappers updated"
echo

echo "=== D: write the OpenRouter key to .env (if not already) ==="
# Read from the VPS via SSH (we have access from VPS, but we're on pixel here)
# Instead: write the key directly. The key is shared - just paste it here.
# The installer can be re-run with KEY=sk-... env var
if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
  echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY}" > "$HOME/.hermes/.env"
  chmod 600 "$HOME/.hermes/.env"
  echo "key written"
fi
echo

echo "=== E: final inventory ==="
echo "Hermes:    $(hermes --version 2>&1 | head -1)"
echo "OpenCode:  $(opencode --version 2>&1 | head -1)"
echo "DSH:       $(cd $HOME/.local/share/deepseek-harness 2>/dev/null && pnpm dsh --version 2>&1 | tail -1)"
echo "eva1:      $(which eva1 2>&1)"
echo "eva2:      $(which eva2 2>&1)"
echo "eva3:      $(which eva3 2>&1)"
echo

echo "=== DONE ==="
echo "To use: from srv1773565 run"
echo "  ssh -p 8022 -i /root/.ssh/ada_mesh_ed25519 u0_a179@100.111.165.85 'eva1 hello'"
echo
echo "If OPENROUTER_API_KEY was set in env, it's in ~/.hermes/.env now."
