# MiniMind on CPU (no GPU)

MiniMind is small (about 64M parameters), so a regular CPU can run it.
Replies come out at roughly 70–90 tokens per second, so a typical answer takes a few seconds.
Training is the part that really needs a GPU (see the end of this page).

## 1. Set up (one command)

```bash
bash scripts/setup_cpu.sh
```

The script:

- creates a Python 3.11 virtual env in `.venv`. The pinned `numpy==1.26.4` does not install on Python 3.13.
- installs CPU-only PyTorch 2.6.0 and `requirements.txt`.
- downloads the pretrained weights from ModelScope into `out/` (~420 MB).
- downloads the Hugging Face-format model the web demo uses into `scripts/minimind-3/` (~130 MB).

Use `--minimal` to download only the main chat model, or `--no-weights` to skip the downloads.
Re-running the script is safe: it skips anything already present.

## 2. Ways to use it

### Terminal chat

```bash
.venv/bin/python eval_llm.py --weight full_sft
```

Type `1` to ask your own questions, or `0` to run the 8 built-in test prompts. Press Enter on an empty line to quit.

### Web chat UI

```bash
cd scripts && ../.venv/bin/streamlit run web_demo.py
```

Then open http://localhost:8501.

### OpenAI-compatible API

```bash
cd scripts && ../.venv/bin/python serve_openai_api.py
```

```bash
curl localhost:8998/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"minimind","messages":[{"role":"user","content":"Hello!"}],"max_tokens":100}'
```

Any OpenAI client library can use it with `base_url="http://localhost:8998/v1"`.

## 3. Model variants (files in `out/`)

| Command flags | What it is |
|---|---|
| `--weight full_sft` | Main chat model. Start here. |
| `--weight grpo` | Reinforcement-learning tuned. Add `--open_thinking 1` to show its reasoning. |
| `--weight agent` | Tuned for tool calling (see `scripts/eval_toolcall.py`). |
| `--weight full_sft --lora_weight lora_identity` | Add-on that teaches it to introduce itself as MiniMind. |
| `--weight full_sft --lora_weight lora_medical` | Add-on for medical-style Q&A. |
| `--weight full_sft --lora_weight lora_exam` | Add-on for exam-style Q&A. |

Useful extra flags: `--max_new_tokens 300` (shorter replies), `--temperature 0.7` (less random), `--historys 4` (remember the last 2 exchanges).

## 4. What to expect

- It answers best in **Chinese**, its main training language. Short English questions work too.
- It's a 64M-parameter model, so it makes factual and math mistakes, and with thinking turned on it sometimes repeats itself.
  It's great for learning how LLMs work, but don't rely on its answers.

## 5. Training without a GPU

- **Small experiments** (e.g. `trainer/train_lora.py` on a tiny dataset) run on CPU, but slowly. Expect hours.
- **Full pretraining or SFT**: use a free cloud GPU instead, such as Google Colab or Kaggle Notebooks.
  Run `bash scripts/setup_cpu.sh --no-weights` there, swapping the CPU PyTorch line for the normal CUDA build.
  Datasets: https://www.modelscope.cn/datasets/gongjy/minimind_dataset/files (place them in `./dataset`).
