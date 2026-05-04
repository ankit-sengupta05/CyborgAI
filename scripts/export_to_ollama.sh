#!/bin/bash
# export_to_ollama.sh
# Convert Hugging Face MedGemma / Gemma 4 model to Ollama-compatible GGUF

set -e

MODEL_NAME=${1:-"medgemma-4b"}
QUANT=${2:-"Q4_K_M"}
HF_REPO=${3:-"cyborg-ai/${MODEL_NAME}"}
MODELS_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/models"
LLAMA_CPP_DIR="${MODELS_DIR}/../llama.cpp"

echo "🔄 Converting ${MODEL_NAME} → ${QUANT} GGUF"
echo "   HF repo:   ${HF_REPO}"
echo "   Output:    ${MODELS_DIR}/${MODEL_NAME}-${QUANT}.gguf"
echo ""

# 1. Download from Hugging Face (if not cached)
MODEL_LOCAL="${MODELS_DIR}/${MODEL_NAME}"
if [ ! -d "${MODEL_LOCAL}" ]; then
  echo "📥 Downloading ${HF_REPO}..."
  python3 -c "
from huggingface_hub import snapshot_download
snapshot_download(repo_id='${HF_REPO}', local_dir='${MODEL_LOCAL}')
print('✅ Download complete')
"
else
  echo "✅ Model already cached at ${MODEL_LOCAL}"
fi

# 2. Clone llama.cpp if not present
if [ ! -d "${LLAMA_CPP_DIR}" ]; then
  echo "📦 Cloning llama.cpp..."
  git clone --depth 1 https://github.com/ggerganov/llama.cpp "${LLAMA_CPP_DIR}"
fi

# 3. Install llama.cpp Python deps
pip install -q -r "${LLAMA_CPP_DIR}/requirements/requirements-convert_hf_to_gguf.txt" 2>/dev/null || true

# 4. Convert to GGUF
GGUF_PATH="${MODELS_DIR}/${MODEL_NAME}-${QUANT}.gguf"
echo "🔨 Converting to GGUF (${QUANT})..."
python3 "${LLAMA_CPP_DIR}/convert_hf_to_gguf.py" "${MODEL_LOCAL}" \
  --outfile "${GGUF_PATH}" \
  --outtype "${QUANT,,}"  # lowercase for llama.cpp

echo "✅ GGUF created: ${GGUF_PATH}"

# 5. Create Ollama Modelfile
MODELFILE="${MODELS_DIR}/Modelfile.${MODEL_NAME}"
cat > "${MODELFILE}" <<EOF
FROM ./${MODEL_NAME}-${QUANT}.gguf
TEMPLATE """[INST] {{ .Prompt }} [/INST]"""
PARAMETER stop "[INST]"
PARAMETER stop "[/INST]"
PARAMETER num_ctx 4096
PARAMETER num_gpu_layers 35
SYSTEM """You are a helpful AI assistant specialized in ${MODEL_NAME%%-*} tasks. Always be accurate, safe, and compassionate."""
EOF
echo "📄 Modelfile: ${MODELFILE}"

# 6. Build Ollama model (optional — requires ollama installed)
if command -v ollama &> /dev/null; then
  echo "🚀 Registering with Ollama..."
  cd "${MODELS_DIR}"
  ollama create "${MODEL_NAME}-ollama" -f "${MODELFILE}"
  echo "✅ Ollama model ready: ollama run ${MODEL_NAME}-ollama"
else
  echo "ℹ️  Ollama not found. To register manually:"
  echo "   cd ${MODELS_DIR} && ollama create ${MODEL_NAME}-ollama -f Modelfile.${MODEL_NAME}"
fi

echo ""
echo "🎉 Done! Copy assets/models/ to your edge device and run:"
echo "   ollama serve  &&  ollama run ${MODEL_NAME}-ollama"
