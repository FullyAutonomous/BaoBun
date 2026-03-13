#!/bin/bash
set -euo pipefail

# BaoBun Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/FullyAutonomous/BaoBun/main/install.sh | bash

BAOBUN_REPO="FullyAutonomous/BaoBun"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.baobun/bin}"
REPO_URL="https://github.com/$BAOBUN_REPO"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Detect OS
detect_os() {
    local os
    case "$(uname -s)" in
        Linux*)     os="linux";;
        Darwin*)    os="darwin";;
        MINGW*|MSYS*|CYGWIN*) os="windows";;
        *)          os="unknown";;
    esac
    echo "$os"
}

# Detect architecture
detect_arch() {
    local arch
    case "$(uname -m)" in
        x86_64|amd64)   arch="x64";;
        aarch64|arm64)  arch="arm64";;
        *)              arch="unknown";;
    esac
    echo "$arch"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get latest release version
get_latest_version() {
    curl -fsSL "https://api.github.com/repos/$BAOBUN_REPO/releases/latest" | 
        grep '"tag_name":' | 
        sed -E 's/.*"([^"]+)".*/\1/'
}

# Download and install BaoBun
install_baobun() {
    local os="$1"
    local arch="$2"
    local version="$3"
    
    log_info "Installing BaoBun $version for $os-$arch..."
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Determine binary name and URL
    local binary_name="baobun-$os-$arch"
    local download_url="$REPO_URL/releases/download/$version/$binary_name.zip"
    
    if [ "$os" = "windows" ]; then
        binary_name="$binary_name.exe"
    fi
    
    local temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/baobun.zip"
    
    log_info "Downloading from $download_url..."
    
    if ! curl -fsSL "$download_url" -o "$zip_file"; then
        log_error "Failed to download BaoBun"
        log_error "URL: $download_url"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_info "Extracting..."
    unzip -q "$zip_file" -d "$temp_dir"
    
    # Find the baobun binary in extracted contents
    local extracted_binary
    if [ -f "$temp_dir/$binary_name" ]; then
        extracted_binary="$temp_dir/$binary_name"
    elif [ -f "$temp_dir/bun" ]; then
        extracted_binary="$temp_dir/bun"
    else
        # Search in subdirectories for baobun-* first, then bun
        extracted_binary=$(find "$temp_dir" -name "baobun-*" -type f | head -1)
        if [ -z "$extracted_binary" ]; then
            extracted_binary=$(find "$temp_dir" -name "bun" -type f | head -1)
        fi
    fi
    
    if [ -z "$extracted_binary" ] || [ ! -f "$extracted_binary" ]; then
        log_error "Could not find BaoBun binary in downloaded archive"
        log_error "Looking for: $binary_name or bun"
        ls -la "$temp_dir"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Move binary to install location
    local target_binary="$INSTALL_DIR/bun"
    mv "$extracted_binary" "$target_binary"
    chmod +x "$target_binary"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_success "BaoBun installed to $target_binary"
}

# Add to PATH
setup_path() {
    local shell_rc=""
    local current_shell="$(basename "$SHELL")"
    
    case "$current_shell" in
        bash)   shell_rc="$HOME/.bashrc";;
        zsh)    shell_rc="$HOME/.zshrc";;
        fish)   shell_rc="$HOME/.config/fish/config.fish";;
        *)      shell_rc="$HOME/.profile";;
    esac
    
    # Check if already in PATH
    if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
        log_info "Install directory already in PATH"
        return 0
    fi
    
    log_info "Adding $INSTALL_DIR to PATH..."
    
    if [ "$current_shell" = "fish" ]; then
        echo "set -gx PATH $INSTALL_DIR \$PATH" >> "$shell_rc"
    else
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$shell_rc"
    fi
    
    log_success "Added to PATH in $shell_rc"
    log_warn "Please restart your terminal or run: source $shell_rc"
}

# Verify installation
verify_installation() {
    if command_exists bun; then
        log_success "BaoBun is ready to use!"
        echo ""
        bun --version
    else
        log_warn "BaoBun installed but not in current PATH"
        log_info "Run: export PATH=\"$INSTALL_DIR:\$PATH\""
        log_info "Or restart your terminal"
    fi
}

# Main installation flow
main() {
    echo ""
    echo "🥟 BaoBun Installer"
    echo "==================="
    echo ""
    
    # Detect platform
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    log_info "Detected platform: $os-$arch"
    
    if [ "$os" = "unknown" ]; then
        log_error "Unsupported operating system: $(uname -s)"
        exit 1
    fi
    
    if [ "$arch" = "unknown" ]; then
        log_error "Unsupported architecture: $(uname -m)"
        exit 1
    fi
    
    # Check for required tools
    if ! command_exists curl; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command_exists unzip; then
        log_error "unzip is required but not installed"
        exit 1
    fi
    
    # Get latest version
    log_info "Checking for latest release..."
    local version=$(get_latest_version)
    
    if [ -z "$version" ]; then
        log_error "Could not determine latest version"
        exit 1
    fi
    
    log_info "Latest version: $version"
    
    # Install
    install_baobun "$os" "$arch" "$version"
    
    # Setup PATH
    setup_path
    
    # Verify
    echo ""
    verify_installation
    
    echo ""
    echo "📚 Quick Start:"
    echo "   bun run index.ts    # Run TypeScript"
    echo "   bun install         # Install dependencies"
    echo "   bun test            # Run tests"
    echo ""
    echo "🎉 Happy coding with BaoBun!"
    echo ""
}

# Handle arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        --dir|-d)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "BaoBun Installer"
            echo ""
            echo "Usage:"
            echo "  curl -fsSL https://raw.githubusercontent.com/FullyAutonomous/BaoBun/main/install.sh | bash"
            echo ""
            echo "Options:"
            echo "  -v, --version VERSION    Install specific version"
            echo "  -d, --dir DIRECTORY      Install to specific directory (default: ~/.baobun/bin)"
            echo "  -h, --help              Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

main
