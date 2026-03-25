#!/bin/bash
# ============================================================
# ByteHide Server Agent — One-line installer
# ============================================================
#
# Install with:
#   curl -sSL https://raw.githubusercontent.com/bytehide/monitor-dotnet-agent/main/install.sh | bash -s -- --token <token>
#
# Or download and run:
#   chmod +x install.sh
#   ./install.sh --token <token>
#
# Options:
#   --token <token>    (required) Your ByteHide API token
#   --version <ver>    Agent version (default: latest)
#   --install-dir      Custom binary install dir (default: /usr/local/bin)
#   --no-install       Only download binary, don't run install
#
# Environment overrides:
#   BYTEHIDE_AGENT_URL   Full URL to the binary archive (skips auto-detection)
#
# ============================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────
VERSION="1.0.5"
GITHUB_REPO="bytehide/monitor-dotnet-agent"
INSTALL_BIN_DIR="/usr/local/bin"
TOKEN=""
SKIP_INSTALL=false
EXTRA_ARGS=()

# ── Colors ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[ByteHide]${NC} $1"; }
ok()    { echo -e "${GREEN}[ByteHide]${NC} $1"; }
warn()  { echo -e "${YELLOW}[ByteHide]${NC} $1"; }
error() { echo -e "${RED}[ByteHide]${NC} $1" >&2; }

# ── Parse arguments ───────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --token|-t)
            TOKEN="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_BIN_DIR="$2"
            shift 2
            ;;
        --no-install)
            SKIP_INSTALL=true
            shift
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# ── Validate ──────────────────────────────────────────────
if [ -z "$TOKEN" ] && [ "$SKIP_INSTALL" = false ]; then
    error "Missing required --token argument."
    echo ""
    echo "Usage:"
    echo "  curl -sSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash -s -- --token <your-token>"
    echo ""
    echo "Get your token from: https://app.bytehide.com → Settings → API Tokens"
    exit 1
fi

# ── Detect OS and architecture ────────────────────────────
detect_platform() {
    local os arch rid

    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)
            # Check for musl (Alpine, etc.)
            if ldd --version 2>&1 | grep -qi musl; then
                os="linux-musl"
            else
                os="linux"
            fi
            ;;
        Darwin)
            os="osx"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            os="win"
            ;;
        *)
            error "Unsupported OS: $os"
            exit 1
            ;;
    esac

    case "$arch" in
        x86_64|amd64)
            arch="x64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    echo "${os}-${arch}"
}

# ── Download helper ───────────────────────────────────────
download() {
    local url="$1"
    local output="$2"

    if command -v curl &>/dev/null; then
        curl -fsSL --retry 3 -o "$output" "$url"
    elif command -v wget &>/dev/null; then
        wget -q -O "$output" "$url"
    else
        error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
}

# ── Main ──────────────────────────────────────────────────
echo ""
echo "  ██████╗ ██╗   ██╗████████╗███████╗██╗  ██╗██╗██████╗ ███████╗"
echo "  ██╔══██╗╚██╗ ██╔╝╚══██╔══╝██╔════╝██║  ██║██║██╔══██╗██╔════╝"
echo "  ██████╔╝ ╚████╔╝    ██║   █████╗  ███████║██║██║  ██║█████╗  "
echo "  ██╔══██╗  ╚██╔╝     ██║   ██╔══╝  ██╔══██║██║██║  ██║██╔══╝  "
echo "  ██████╔╝   ██║      ██║   ███████╗██║  ██║██║██████╔╝███████╗"
echo "  ╚═════╝    ╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝╚═════╝ ╚══════╝"
echo "                       Server Agent Installer"
echo ""

RID=$(detect_platform)
info "Platform: $RID"
info "Version:  $VERSION"

# Build download URL
if [ -n "${BYTEHIDE_AGENT_URL:-}" ]; then
    DOWNLOAD_URL="$BYTEHIDE_AGENT_URL"
    info "Using custom URL: $DOWNLOAD_URL"
else
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/bytehide-agent-${VERSION}-${RID}.tar.gz"
fi

# Create temp directory
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Download
info "Downloading bytehide-agent..."
ARCHIVE_PATH="$TMPDIR/bytehide-agent.tar.gz"

if ! download "$DOWNLOAD_URL" "$ARCHIVE_PATH"; then
    error "Download failed from: $DOWNLOAD_URL"
    echo ""
    error "Possible causes:"
    error "  1. Version $VERSION not available for $RID"
    error "  2. Release not published (set BYTEHIDE_AGENT_URL for custom source)"
    error "  3. Network connectivity issue"
    echo ""
    error "Manual install: download the binary and run:"
    error "  ./bytehide-agent install --token <token>"
    exit 1
fi

# Extract
info "Extracting..."
tar -xzf "$ARCHIVE_PATH" -C "$TMPDIR"

BINARY="$TMPDIR/bytehide-agent"
if [ ! -f "$BINARY" ]; then
    error "Archive does not contain 'bytehide-agent' binary."
    exit 1
fi
chmod +x "$BINARY"

# Install binary to PATH
info "Installing binary to $INSTALL_BIN_DIR..."
mkdir -p "$INSTALL_BIN_DIR" 2>/dev/null || true

if cp "$BINARY" "$INSTALL_BIN_DIR/bytehide-agent" 2>/dev/null; then
    ok "Binary installed: $INSTALL_BIN_DIR/bytehide-agent"
else
    warn "Permission denied. Trying with sudo..."
    sudo cp "$BINARY" "$INSTALL_BIN_DIR/bytehide-agent"
    sudo chmod +x "$INSTALL_BIN_DIR/bytehide-agent"
    ok "Binary installed: $INSTALL_BIN_DIR/bytehide-agent"
fi

# Run agent install
if [ "$SKIP_INSTALL" = true ]; then
    ok "Binary downloaded. Skipping agent install (--no-install)."
    echo ""
    echo "  To install the agent manually:"
    echo "    bytehide-agent install --token <your-token>"
else
    info "Running agent install..."
    echo ""
    "$INSTALL_BIN_DIR/bytehide-agent" install --token "$TOKEN" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
fi

echo ""
ok "Done! ByteHide Server Agent is ready."
echo ""
