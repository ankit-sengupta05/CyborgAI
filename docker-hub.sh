#!/bin/bash

# Docker Hub Management Script for Cyborg AGI
# Usage: ./docker-hub.sh [login|build|push|deploy|all] [tag]

set -e

# Configuration
DOCKER_USER="${DOCKER_USER:-cyborg-agi}"
IMAGE_NAME="cyborg-agi-backend"
DEFAULT_TAG="latest"
TAG="${2:-$DEFAULT_TAG}"
FULL_IMAGE_NAME="$DOCKER_USER/$IMAGE_NAME:$TAG"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    echo "Cyborg AGI Docker Hub Manager"
    echo ""
    echo "Usage: $0 [command] [tag]"
    echo ""
    echo "Commands:"
    echo "  login       Log in to Docker Hub"
    echo "  build       Build the Docker image locally"
    echo "  push        Push the image to Docker Hub (requires login)"
    echo "  deploy      Pull and run the image from Docker Hub on current machine"
    echo "  all         Build, tag, and push (complete workflow)"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 login"
    echo "  $0 build v1.0.0"
    echo "  $0 push v1.0.0"
    echo "  $0 all v1.0.0"
    echo ""
    echo "Environment Variables:"
    echo "  DOCKER_USER   Your Docker Hub username (default: cyborg-agi)"
    echo "  IMAGE_NAME    Image name (default: cyborg-agi-backend)"
    echo ""
    echo "Current Configuration:"
    echo "  Image: $FULL_IMAGE_NAME"
}

docker_login() {
    log_info "Logging in to Docker Hub..."
    if docker login; then
        log_info "Successfully logged in to Docker Hub"
    else
        log_error "Failed to log in to Docker Hub"
        exit 1
    fi
}

docker_build() {
    log_info "Building Docker image: $FULL_IMAGE_NAME"

    # Build the image
    docker build -t $FULL_IMAGE_NAME .

    # Also tag as latest if not already
    if [ "$TAG" != "latest" ]; then
        log_info "Also tagging as latest: $DOCKER_USER/$IMAGE_NAME:latest"
        docker tag $FULL_IMAGE_NAME $DOCKER_USER/$IMAGE_NAME:latest
    fi

    log_info "Build complete!"
    log_info "Image ID: $(docker images -q $FULL_IMAGE_NAME)"
}

docker_push() {
    log_info "Pushing image to Docker Hub: $FULL_IMAGE_NAME"

    # Check if logged in
    if ! docker info 2>/dev/null | grep -q "Username"; then
        log_warn "Not logged in to Docker Hub. Attempting to login..."
        docker_login
    fi

    # Push specific tag
    docker push $FULL_IMAGE_NAME

    # Push latest tag if applicable
    if [ "$TAG" != "latest" ]; then
        log_info "Pushing latest tag..."
        docker push $DOCKER_USER/$IMAGE_NAME:latest
    fi

    log_info "Push complete! Image available at: https://hub.docker.com/r/$DOCKER_USER/$IMAGE_NAME"
}

docker_deploy() {
    log_info "Deploying from Docker Hub..."

    # Stop existing container if running
    if docker ps -q --filter "name=cyborg-backend" | grep -q .; then
        log_warn "Stopping existing container..."
        docker stop cyborg-backend || true
        docker rm cyborg-backend || true
    fi

    # Pull latest image
    log_info "Pulling image: $FULL_IMAGE_NAME"
    docker pull $FULL_IMAGE_NAME

    # Run container
    log_info "Starting container..."
    docker run -d \
        --name cyborg-backend \
        --restart unless-stopped \
        -p 8765:8765 \
        --env-file .env \
        -v cyborg-data:/app/data \
        -v cyborg-models:/app/models \
        $FULL_IMAGE_NAME

    log_info "Deployment complete!"
    log_info "Container status: $(docker ps --filter "name=cyborg-backend" --format "{{.Status}}")"
    log_info "Access API at: http://localhost:8765"
}

run_all() {
    log_info "Running complete workflow: build -> push"
    docker_build
    docker_push
}

# Main command handler
case "${1:-help}" in
    login)
        docker_login
        ;;
    build)
        docker_build
        ;;
    push)
        docker_push
        ;;
    deploy)
        docker_deploy
        ;;
    all)
        run_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
