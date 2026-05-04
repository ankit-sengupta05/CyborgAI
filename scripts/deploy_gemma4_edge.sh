#!/bin/bash
# Gemma 4 Health & Education Edge Deployment Script
# One-command setup for Raspberry Pi, Jetson, Android, or laptop

set -e

echo "🚀 Cyborg AGI: Gemma 4 Edge Deployment"
echo "======================================"
echo ""

# Configuration
MODEL_DIR="${MODEL_DIR:-./assets/models}"
PYTHON_ENV="${PYTHON_ENV:-venv}"
HEALTH_PORT="${HEALTH_PORT:-7860}"
EDUCATION_PORT="${EDUCATION_PORT:-7861}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}✅${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."

    # Check Python version
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        log_info "Python: $PYTHON_VERSION"
    else
        log_error "Python 3 required. Please install Python 3.8+"
        exit 1
    fi

    # Check RAM (minimum 2GB recommended)
    if command -v free &> /dev/null; then
        RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$RAM_GB" -lt 2 ]; then
            log_warn "Low RAM detected ($RAM_GB GB). Consider using Q2_K quantized models."
        else
            log_info "RAM: ${RAM_GB}GB"
        fi
    fi

    # Check disk space
    AVAILABLE_SPACE=$(df -h . | awk 'NR==2{print $4}')
    log_info "Available disk space: $AVAILABLE_SPACE"
}

# Create virtual environment
setup_environment() {
    log_info "Setting up Python environment..."

    if [ ! -d "$PYTHON_ENV" ]; then
        python3 -m venv $PYTHON_ENV
        log_info "Created virtual environment: $PYTHON_ENV"
    fi

    source $PYTHON_ENV/bin/activate

    log_info "Upgrading pip..."
    pip install --upgrade pip

    log_info "Installing dependencies..."
    pip install -r requirements.txt

    # Install edge-specific packages
    pip install ollama llama-cpp-python pillow torchvision transformers
}

# Download models (optional - can be done manually)
download_models() {
    log_info "Model directory: $MODEL_DIR"

    if [ ! -d "$MODEL_DIR" ]; then
        mkdir -p $MODEL_DIR
    fi

    echo ""
    echo "📦 Model Download Options:"
    echo "1. Download MedGemma 4B (Health Track) - ~3GB"
    echo "2. Download Gemma 4 4B (Education Track) - ~3GB"
    echo "3. Skip model download (manual installation)"
    echo ""

    read -p "Select option (1/2/3): " model_choice

    case $model_choice in
        1)
            log_info "Downloading MedGemma 4B (quantized)..."
            # In production, use actual download URLs
            # wget -O $MODEL_DIR/medgemma-4b-Q4_K_M.gguf "URL_HERE"
            log_warn "Manual download required. Visit Hugging Face for models."
            ;;
        2)
            log_info "Downloading Gemma 4 4B (quantized)..."
            log_warn "Manual download required. Visit Hugging Face for models."
            ;;
        3)
            log_info "Skipping model download"
            ;;
        *)
            log_warn "Invalid option. Skipping model download."
            ;;
    esac
}

# Setup Ollama (optional)
setup_ollama() {
    echo ""
    log_info "Setting up Ollama runtime (optional)..."

    read -p "Install Ollama? (y/n): " install_ollama

    if [ "$install_ollama" = "y" ]; then
        if command -v ollama &> /dev/null; then
            log_info "Ollama already installed"
        else
            curl -fsSL https://ollama.com/install.sh | sh
            log_info "Ollama installed successfully"
        fi

        # Pull models if available
        echo "Available models to pull:"
        echo "- medgemma:4b (health track)"
        echo "- gemma:4b-it (education track)"

        read -p "Pull a model now? (y/n): " pull_model
        if [ "$pull_model" = "y" ]; then
            read -p "Enter model name (e.g., gemma:4b-it): " model_name
            ollama pull $model_name
        fi
    fi
}

# Start demos
start_demos() {
    echo ""
    log_info "Starting demo servers..."
    echo ""
    echo "🏥 Health Demo:   http://localhost:$HEALTH_PORT"
    echo "🎓 Education Demo: http://localhost:$EDUCATION_PORT"
    echo ""
    echo "Press Ctrl+C to stop all servers"
    echo ""

    # Start health demo in background
    python assets/demos/health_demo.py &
    HEALTH_PID=$!

    sleep 3

    # Start education demo in background
    python assets/demos/education_demo.py &
    EDUCATION_PID=$!

    # Wait for both processes
    wait $HEALTH_PID $EDUCATION_PID
}

# Main execution
main() {
    check_requirements
    setup_environment
    download_models
    setup_ollama
    start_demos
}

# Run main function
main

echo ""
log_info "Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Download models from Hugging Face (if not done automatically)"
echo "2. Place GGUF models in: $MODEL_DIR"
echo "3. Run demos:"
echo "   python assets/demos/health_demo.py"
echo "   python assets/demos/education_demo.py"
echo ""
echo "Documentation: README.md"
echo "Support: GitHub Issues"
