#!/usr/bin/env bash
# One-command CPU setup for MiniMind (no GPU needed).
# Creates a Python 3.11 virtual env in ./.venv, installs CPU-only PyTorch plus
# requirements.txt, and downloads the pretrained weights from ModelScope.
#
# Usage (from the repo root):
#   bash scripts/setup_cpu.sh            # env + chat weights + web-demo model
#   bash scripts/setup_cpu.sh --minimal  # env + only the main chat weights
#   bash scripts/setup_cpu.sh --no-weights
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-full}"
PY_VERSION=3.11   # numpy 1.26.4 (pinned) has no wheels for Python 3.13

echo "==> Creating virtual env (.venv, Python $PY_VERSION)"
if command -v uv >/dev/null 2>&1; then
  [ -x .venv/bin/python ] || uv venv -p "$PY_VERSION" .venv
  PIP=(uv pip install -p .venv/bin/python)
else
  [ -x .venv/bin/python ] || "python$PY_VERSION" -m venv .venv
  .venv/bin/python -m pip install -q --upgrade pip
  PIP=(.venv/bin/python -m pip install)
fi

echo "==> Installing CPU-only PyTorch"
"${PIP[@]}" torch==2.6.0 --index-url https://download.pytorch.org/whl/cpu
echo "==> Installing requirements.txt"
"${PIP[@]}" -r requirements.txt

if [ "$MODE" = "--no-weights" ]; then
  echo "==> Skipping weight downloads"; exit 0
fi

if [ "$MODE" = "--minimal" ]; then
  WEIGHTS="full_sft_768.pth"
else
  WEIGHTS="full_sft_768.pth grpo_768.pth agent_768.pth lora_identity_768.pth lora_medical_768.pth lora_exam_768.pth"
fi

echo "==> Downloading PyTorch weights into ./out"
.venv/bin/python - "$WEIGHTS" <<'EOF'
import os, sys
from modelscope.hub.file_download import model_file_download
for name in sys.argv[1].split():
    if os.path.exists(os.path.join("out", name)):
        print("already have", name); continue
    model_file_download("gongjy/minimind-3-pytorch", name, local_dir="out")
    print("downloaded", name)
EOF

if [ "$MODE" != "--minimal" ]; then
  echo "==> Downloading transformers-format model for the web demo (scripts/minimind-3)"
  .venv/bin/python -c "
from modelscope import snapshot_download
snapshot_download('gongjy/minimind-3', local_dir='scripts/minimind-3')"
fi

# ModelScope leaves temporary folders behind; they are safe to remove.
find out scripts/minimind-3 -maxdepth 1 -name '._____temp' -type d -exec rm -r {} + 2>/dev/null || true

cat <<'EOF'

Done. Try it:
  .venv/bin/python eval_llm.py --weight full_sft          # terminal chat (type 1, then your question)
  cd scripts && ../.venv/bin/streamlit run web_demo.py    # web UI at http://localhost:8501
  cd scripts && ../.venv/bin/python serve_openai_api.py   # OpenAI-style API at http://localhost:8998
See CPU_QUICKSTART.md for more.
EOF
