# One-command CPU setup for MiniMind on Windows (no GPU needed).
# Windows version of scripts/setup_cpu.sh. Works in Windows PowerShell 5.1 and PowerShell 7.
#
# Usage (from the repo folder):
#   powershell -ExecutionPolicy Bypass -File scripts\setup_cpu.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\setup_cpu.ps1 -Minimal
#   powershell -ExecutionPolicy Bypass -File scripts\setup_cpu.ps1 -NoWeights
param(
    [switch]$Minimal,
    [switch]$NoWeights
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

function Run($exe, [string[]]$argList) {
    & $exe @argList
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $exe $($argList -join ' ')" }
}

$venvPy = '.venv\Scripts\python.exe'

Write-Host '==> Creating virtual env (.venv, Python 3.11)'
if (-not (Test-Path $venvPy)) {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        Run 'py' @('-3.11', '-m', 'venv', '.venv')
    } else {
        throw 'Python 3.11 not found. Install it with:  winget install Python.Python.3.11   then open a new PowerShell window and re-run this script.'
    }
}
Run $venvPy @('-m', 'pip', 'install', '-q', '--upgrade', 'pip')

Write-Host '==> Installing CPU-only PyTorch'
Run $venvPy @('-m', 'pip', 'install', 'torch==2.6.0', '--index-url', 'https://download.pytorch.org/whl/cpu')
Write-Host '==> Installing requirements.txt'
Run $venvPy @('-m', 'pip', 'install', '-r', 'requirements.txt')

if ($NoWeights) { Write-Host '==> Skipping weight downloads'; exit 0 }

if ($Minimal) {
    $weights = 'full_sft_768.pth'
} else {
    $weights = 'full_sft_768.pth grpo_768.pth agent_768.pth lora_identity_768.pth lora_medical_768.pth lora_exam_768.pth'
}

Write-Host '==> Downloading PyTorch weights into .\out'
$dl = @'
import os, sys
from modelscope.hub.file_download import model_file_download
for name in sys.argv[1].split():
    if os.path.exists(os.path.join("out", name)):
        print("already have", name); continue
    model_file_download("gongjy/minimind-3-pytorch", name, local_dir="out")
    print("downloaded", name)
'@
$tmp = Join-Path $env:TEMP 'minimind_download.py'
Set-Content -Path $tmp -Value $dl -Encoding UTF8
Run $venvPy @($tmp, $weights)
Remove-Item $tmp

if (-not $Minimal) {
    Write-Host '==> Downloading transformers-format model for the web demo (scripts\minimind-3)'
    Run $venvPy @('-c', "from modelscope import snapshot_download; snapshot_download('gongjy/minimind-3', local_dir='scripts/minimind-3')")
}

# ModelScope leaves temporary folders behind; they are safe to remove.
foreach ($d in @('out\._____temp', 'scripts\minimind-3\._____temp')) {
    if (Test-Path $d) { Remove-Item -Recurse -Force $d }
}

Write-Host @'

Done. Try it:
  .venv\Scripts\python.exe eval_llm.py --weight full_sft
      (terminal chat: type 1, then your question)
  cd scripts; ..\.venv\Scripts\streamlit.exe run web_demo.py
      (web UI at http://localhost:8501)
  cd scripts; ..\.venv\Scripts\python.exe serve_openai_api.py
      (OpenAI-style API at http://localhost:8998)
See CPU_QUICKSTART.md for more.
'@
