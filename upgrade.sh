#!/bin/bash
set -e

# ============================================================================
# Claude Code Web Terminal - Upgrade / Migration Script
# ============================================================================
# Detects old Zellij-based installations, cleans them up, and optionally
# installs the new tmux-based version.
#
# Usage:
#   sudo ./upgrade.sh           # Detect, clean, and install new version
#   sudo ./upgrade.sh --clean   # Only remove old installation (no reinstall)
#   sudo ./upgrade.sh --detect  # Only detect what's installed (dry run)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

MODE="${1:-upgrade}"

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./upgrade.sh"
    exit 1
fi

if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
    print_error "Please run with sudo, not as root directly"
    exit 1
fi

# ============================================================================
# Detection
# ============================================================================

FOUND_ZELLIJ=false
FOUND_TMUX=false
ZELLIJ_ITEMS=()

detect() {
    print_status "Detecting installed versions..."
    echo ""

    # Check for Zellij-based installation
    if command -v zellij &>/dev/null; then
        FOUND_ZELLIJ=true
        ZELLIJ_ITEMS+=("zellij binary: $(which zellij)")
    fi

    if [ -d "$USER_HOME/.config/zellij" ]; then
        FOUND_ZELLIJ=true
        ZELLIJ_ITEMS+=("zellij config: $USER_HOME/.config/zellij/")
    fi

    if [ -d "$USER_HOME/.cache/zellij" ]; then
        local session_count
        session_count=$(find "$USER_HOME/.cache/zellij" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
        FOUND_ZELLIJ=true
        ZELLIJ_ITEMS+=("zellij cache: $USER_HOME/.cache/zellij/ ($session_count session dirs)")
    fi

    if [ -f /etc/systemd/system/claude-terminal.service ]; then
        if grep -q "zellij" /etc/systemd/system/claude-terminal.service 2>/dev/null; then
            FOUND_ZELLIJ=true
            ZELLIJ_ITEMS+=("systemd service: references zellij")
        fi
    fi

    if grep -q "zellij" "$USER_HOME/.bashrc" 2>/dev/null; then
        FOUND_ZELLIJ=true
        ZELLIJ_ITEMS+=("bashrc: contains zellij references")
    fi

    # Check for tmux-based installation
    if [ -f /etc/systemd/system/claude-terminal.service ]; then
        if grep -q "tmux" /etc/systemd/system/claude-terminal.service 2>/dev/null; then
            FOUND_TMUX=true
        fi
    fi

    # Report
    echo "  Detection Results"
    echo "  ━━━━━━━━━━━━━━━━━"

    if [ "$FOUND_ZELLIJ" = true ]; then
        print_warning "Old Zellij-based installation detected:"
        for item in "${ZELLIJ_ITEMS[@]}"; do
            echo "    - $item"
        done
    else
        echo "  No Zellij installation found."
    fi

    echo ""

    if [ "$FOUND_TMUX" = true ]; then
        print_success "Current tmux-based installation detected."
    else
        echo "  No tmux-based installation found."
    fi

    echo ""
}

# ============================================================================
# Cleanup old Zellij installation
# ============================================================================

clean_zellij() {
    if [ "$FOUND_ZELLIJ" = false ]; then
        echo "  Nothing to clean."
        return
    fi

    print_status "Removing old Zellij-based installation..."

    # Stop any running Zellij sessions
    if command -v zellij &>/dev/null; then
        print_status "Killing Zellij sessions..."
        su -c "zellij kill-all-sessions --yes" "$USER_NAME" 2>/dev/null || true
        print_success "Zellij sessions killed"
    fi

    # Remove systemd service if it references Zellij
    if [ -f /etc/systemd/system/claude-terminal.service ]; then
        if grep -q "zellij" /etc/systemd/system/claude-terminal.service 2>/dev/null; then
            print_status "Removing old systemd service..."
            systemctl stop claude-terminal 2>/dev/null || true
            systemctl disable claude-terminal 2>/dev/null || true
            rm -f /etc/systemd/system/claude-terminal.service
            systemctl daemon-reload
            print_success "Old systemd service removed"
        fi
    fi

    # Remove old healthcheck if it references Zellij
    if [ -f /usr/local/bin/claude-terminal-healthcheck ]; then
        if grep -q "zellij" /usr/local/bin/claude-terminal-healthcheck 2>/dev/null; then
            rm -f /usr/local/bin/claude-terminal-healthcheck
            print_success "Old healthcheck removed"
        fi
    fi

    # Clean Zellij cache (dead sessions)
    if [ -d "$USER_HOME/.cache/zellij" ]; then
        local cache_size
        cache_size=$(du -sh "$USER_HOME/.cache/zellij" 2>/dev/null | cut -f1)
        rm -rf "$USER_HOME/.cache/zellij"
        print_success "Zellij cache removed ($cache_size)"
    fi

    # Remove Zellij config (preserve if user customized it)
    if [ -d "$USER_HOME/.config/zellij" ]; then
        print_status "Removing Zellij config..."
        rm -rf "$USER_HOME/.config/zellij"
        print_success "Zellij config removed"
    fi

    # Clean bashrc Zellij references
    if grep -q "zellij" "$USER_HOME/.bashrc" 2>/dev/null; then
        print_status "Cleaning Zellij references from ~/.bashrc..."
        # Remove lines containing zellij (aliases, exports, etc.)
        sed -i '/zellij/Id' "$USER_HOME/.bashrc"
        print_success "Bashrc cleaned"
    fi

    # Remove old scripts that may reference Zellij
    for script in claude-terminal-start claude-terminal-stop claude-terminal-status; do
        if [ -f "/usr/local/bin/$script" ]; then
            if grep -q "zellij" "/usr/local/bin/$script" 2>/dev/null; then
                rm -f "/usr/local/bin/$script"
                print_success "Removed old $script"
            fi
        fi
    done

    echo ""
    print_success "Zellij cleanup complete!"
}

# ============================================================================
# Remove current tmux-based installation
# ============================================================================

clean_tmux() {
    if [ "$FOUND_TMUX" = false ]; then
        return
    fi

    print_status "Removing current tmux-based installation..."

    # Use existing uninstall.sh if available (non-interactive)
    systemctl stop claude-terminal 2>/dev/null || true
    systemctl disable claude-terminal 2>/dev/null || true
    systemctl stop claude-terminal-healthcheck.timer 2>/dev/null || true
    systemctl disable claude-terminal-healthcheck.timer 2>/dev/null || true

    rm -f /etc/systemd/system/claude-terminal.service
    rm -f /etc/systemd/system/claude-terminal-healthcheck.service
    rm -f /etc/systemd/system/claude-terminal-healthcheck.timer
    systemctl daemon-reload

    rm -rf /usr/local/share/claude-terminal
    rm -f /usr/local/bin/claude-terminal-start
    rm -f /usr/local/bin/claude-terminal-stop
    rm -f /usr/local/bin/claude-terminal-status
    rm -f /usr/local/bin/claude-terminal-healthcheck
    rm -f /usr/local/bin/claude-launcher
    rm -f /usr/local/bin/clp
    rm -f /usr/local/bin/cnew
    rm -f /usr/local/bin/cls
    rm -f /usr/local/bin/tj
    rm -f /usr/local/share/clp-completion.bash
    rm -f "$USER_HOME/bin/claude-terminal-init"
    rm -f /etc/sudoers.d/claude-terminal

    # Clean bashrc markers
    sed -i '/# === Claude Code Web Terminal ===/,/# === End Claude Code ===/d' "$USER_HOME/.bashrc" 2>/dev/null

    print_success "tmux-based installation removed"
}

# ============================================================================
# Install new version
# ============================================================================

install_new() {
    if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
        print_error "install.sh not found in $SCRIPT_DIR"
        echo "  Place upgrade.sh alongside install.sh in the distribution package."
        exit 1
    fi

    echo ""
    print_status "Installing new tmux-based version..."
    echo ""

    bash "$SCRIPT_DIR/install.sh"

    if [ -f "$SCRIPT_DIR/extras/install-extras.sh" ]; then
        echo ""
        bash "$SCRIPT_DIR/extras/install-extras.sh"
    fi
}

# ============================================================================
# Main
# ============================================================================

echo ""
echo "============================================================================"
echo "  Claude Code Web Terminal — Upgrade Tool"
echo "============================================================================"
echo ""

detect

case "$MODE" in
    --detect)
        echo "Dry run complete. No changes made."
        ;;
    --clean)
        if [ "$FOUND_ZELLIJ" = false ] && [ "$FOUND_TMUX" = false ]; then
            echo "Nothing to clean."
            exit 0
        fi
        echo "This will remove all Claude terminal components."
        read -p "Continue? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
        clean_zellij
        clean_tmux
        echo ""
        print_success "All Claude terminal components removed."
        echo ""
        echo "  Note: ttyd, tmux, zellij, and Tailscale were NOT uninstalled."
        echo "  Your projects in ~/projects are untouched."
        ;;
    *)
        if [ "$FOUND_ZELLIJ" = true ]; then
            echo "This will:"
            echo "  1. Remove the old Zellij-based installation"
            echo "  2. Install the new tmux-based version"
            echo ""
            echo "  Your projects in ~/projects will NOT be touched."
            echo ""
            read -p "Continue? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 0
            fi
            clean_zellij
            clean_tmux
            install_new
        elif [ "$FOUND_TMUX" = true ]; then
            echo "Current tmux-based version is already installed."
            echo ""
            read -p "Reinstall / update? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "No changes made."
                exit 0
            fi
            clean_tmux
            install_new
        else
            echo "No existing installation found."
            echo ""
            read -p "Install fresh? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "No changes made."
                exit 0
            fi
            install_new
        fi
        echo ""
        echo "============================================================================"
        print_success "Upgrade complete!"
        echo "============================================================================"
        echo ""
        echo "  Start with: claude-terminal-start"
        echo "  Then open:  http://localhost:7681"
        echo ""
        ;;
esac
