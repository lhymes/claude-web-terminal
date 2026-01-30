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
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

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
    echo ""
    print_status "Installing new tmux-based version..."
    echo ""

    # Install dependencies if missing
    for cmd in ttyd tmux fzf; do
        if ! command -v "$cmd" &>/dev/null; then
            print_status "Installing $cmd..."
            apt-get install -y "$cmd" 2>/dev/null || print_warning "$cmd not found — install manually"
        fi
    done

    # Custom frontend
    mkdir -p /usr/local/share/claude-terminal
    if [ -f "$SCRIPT_DIR/html/index.html" ]; then
        cp "$SCRIPT_DIR/html/index.html" /usr/local/share/claude-terminal/index.html
        print_success "Custom frontend installed"
    else
        print_warning "html/index.html not found — skipping custom frontend"
    fi

    # Systemd service
    cat > /etc/systemd/system/claude-terminal.service << SVCEOF
[Unit]
Description=Claude Code Web Terminal (ttyd + tmux)
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=simple
User=$USER_NAME
Environment="HOME=$USER_HOME"
Environment="TERM=xterm-256color"
WorkingDirectory=$USER_HOME

ExecStart=/usr/bin/ttyd \\
    --writable \\
    --port 7681 \\
    --base-path / \\
    --index /usr/local/share/claude-terminal/index.html \\
    /usr/bin/tmux new-session -A -s claude

Restart=always
RestartSec=5

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$USER_HOME
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable claude-terminal
    print_success "Systemd service installed"

    # tmux config
    cat > "$USER_HOME/.tmux.conf" << 'TMUXEOF'
set -g default-terminal "xterm-256color"
set -g history-limit 50000
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g set-clipboard on

bind -n M-1 select-window -t :1
bind -n M-2 select-window -t :2
bind -n M-3 select-window -t :3
bind -n M-4 select-window -t :4
bind -n M-5 select-window -t :5
bind -n M-6 select-window -t :6
bind -n M-7 select-window -t :7
bind -n M-8 select-window -t :8
bind -n M-9 select-window -t :9

set -g status on
set -g status-position bottom
set -g status-style "bg=#1e1e1e,fg=#d4d4d4"
set -g status-left ""
set -g status-right ""
setw -g window-status-format " #I:#W "
setw -g window-status-current-format " #I:#W "
setw -g window-status-current-style "bg=#569cd6,fg=#1e1e1e,bold"
setw -g window-status-style "bg=#2d2d2d,fg=#d4d4d4"
setw -g window-status-separator ""
set -sg escape-time 10
TMUXEOF

    chown "$USER_NAME:$USER_NAME" "$USER_HOME/.tmux.conf"
    print_success "tmux config installed"

    print_success "New tmux-based version installed"
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
