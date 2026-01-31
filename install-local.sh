#!/bin/bash
set -e

# ============================================================================
# Claude Code Web Terminal — Installer / Upgrader / Uninstaller
# Usage: sudo ./install-local.sh            # Install or upgrade
#        sudo ./install-local.sh --uninstall # Remove everything
# ============================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_info()    { echo -e "${CYAN}[i]${NC} $1"; }
print_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
print_error()   { echo -e "${RED}[✗]${NC} $1"; }

prompt_remote_sudo() {
    echo ""
    echo -e "${YELLOW}── Remote Sudo Access ──${NC}"
    echo "Enable passwordless sudo for the web terminal?"
    echo ""
    echo -e "  ${RED}WARNING:${NC} Anyone with terminal access gets root access."
    echo "  ONLY access through Tailscale VPN. NEVER expose ttyd directly."
    echo "  Device security (screen lock, passwords) is your last defense."
    echo ""
    read -p "Enable remote sudo? [y/N]: " user_sudo < /dev/tty
    if [[ "$user_sudo" == "y" || "$user_sudo" == "Y" ]]; then
        echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/claude-terminal"
        chmod 440 "/etc/sudoers.d/claude-terminal"
        print_success "Passwordless sudo enabled for $USER_NAME"
        return 0
    fi
    return 1
}

BASHRC_START="# --- claude-terminal-config-start ---"
BASHRC_END="# --- claude-terminal-config-end ---"
MARKER_FILE="/usr/local/share/claude-terminal/.installed"

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-local.sh"
    exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
CONFIG_DIR="$USER_HOME/.config/claude-terminal"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"

# ============================================================================
# UNINSTALL
# ============================================================================
if [[ "${1:-}" == "--uninstall" ]]; then
    echo ""
    echo -e "${YELLOW}Claude Code Web Terminal — Uninstall${NC}"
    echo ""
    echo "This will remove:"
    echo "  - systemd services (claude-terminal + healthcheck timer)"
    echo "  - CLI tools (claude-launcher, clp, cnew, cls, tj)"
    echo "  - Frontend files (/usr/local/share/claude-terminal/)"
    echo "  - Configuration (~/.config/claude-terminal/)"
    echo "  - Shell configuration (bashrc block + tmux.conf)"
    echo "  - Sudoers entry (if enabled)"
    echo ""
    echo "Your project files will NOT be removed."
    echo ""
    read -p "Continue with removal? [y/N] " confirm1
    if [[ "$confirm1" != "y" && "$confirm1" != "Y" ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""
    read -p "Are you sure? This cannot be undone. Type 'REMOVE' to confirm: " confirm2
    if [[ "$confirm2" != "REMOVE" ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""

    # Stop and disable services
    systemctl stop claude-terminal-healthcheck.timer 2>/dev/null || true
    systemctl disable claude-terminal-healthcheck.timer 2>/dev/null || true
    systemctl stop claude-terminal 2>/dev/null || true
    systemctl disable claude-terminal 2>/dev/null || true
    rm -f /etc/systemd/system/claude-terminal.service
    rm -f /etc/systemd/system/claude-terminal-healthcheck.service
    rm -f /etc/systemd/system/claude-terminal-healthcheck.timer
    systemctl daemon-reload
    print_success "systemd services removed"

    # Remove CLI tools
    rm -f /usr/local/bin/claude-launcher
    rm -f /usr/local/bin/clp
    rm -f /usr/local/bin/cnew
    rm -f /usr/local/bin/cls
    rm -f /usr/local/bin/tj
    rm -f /usr/local/bin/claude-terminal-healthcheck
    print_success "CLI tools removed"

    # Remove frontend files
    rm -rf /usr/local/share/claude-terminal
    print_success "Frontend files removed"

    # Remove sudoers entry
    rm -f /etc/sudoers.d/claude-terminal
    print_success "Sudoers entry removed"

    # Remove config
    rm -rf "$CONFIG_DIR"
    print_success "Configuration removed"

    # Remove bashrc block
    if grep -qF "$BASHRC_START" "$USER_HOME/.bashrc" 2>/dev/null; then
        sed -i "/$BASHRC_START/,/$BASHRC_END/d" "$USER_HOME/.bashrc"
        print_success "Shell configuration removed from .bashrc"
    fi

    # Remove tmux.conf (warn if it has non-standard content)
    if [[ -f "$USER_HOME/.tmux.conf" ]]; then
        if grep -q "Claude Code Web Terminal" "$USER_HOME/.tmux.conf" 2>/dev/null; then
            rm -f "$USER_HOME/.tmux.conf"
            print_success "tmux.conf removed"
        else
            print_warn "~/.tmux.conf exists but appears customized — left in place"
        fi
    fi

    echo ""
    echo -e "${GREEN}Uninstall complete.${NC} Your project files were not touched."
    exit 0
fi

# ============================================================================
# INSTALL / UPGRADE
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS_UPGRADE=false
if [[ -f "$MARKER_FILE" ]] \
   || [[ -f /etc/systemd/system/claude-terminal.service ]] \
   || [[ -f "$SETTINGS_FILE" ]] \
   || [[ -f /usr/local/bin/claude-launcher ]]; then
    IS_UPGRADE=true
    print_info "Existing installation detected — upgrading (settings preserved)"
else
    print_info "Fresh installation"
fi

echo ""

# ---- tmux config ----
cat > "$USER_HOME/.tmux.conf" << 'TMUX_CONFIG'
# Claude Code Web Terminal - tmux Configuration
# Optimized for mobile/touch interaction via ttyd

# General settings
set -g default-terminal "xterm-256color"
set -g history-limit 50000
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g set-clipboard on

# Alt+1-9 to switch windows (like browser tabs)
bind -n M-1 select-window -t :1
bind -n M-2 select-window -t :2
bind -n M-3 select-window -t :3
bind -n M-4 select-window -t :4
bind -n M-5 select-window -t :5
bind -n M-6 select-window -t :6
bind -n M-7 select-window -t :7
bind -n M-8 select-window -t :8
bind -n M-9 select-window -t :9

# Status bar - claude theme colors
set -g status on
set -g status-position bottom
set -g status-style "bg=#1e1e1e,fg=#d4d4d4"
set -g status-left ""
set -g status-right ""

# Window status formatting (tab-like appearance)
setw -g window-status-format " #I:#W "
setw -g window-status-current-format " #I:#W "
setw -g window-status-current-style "bg=#569cd6,fg=#1e1e1e,bold"
setw -g window-status-style "bg=#2d2d2d,fg=#d4d4d4"
setw -g window-status-separator ""

# Report active window index via terminal title (parsed by web frontend)
set -g set-titles on
set -g set-titles-string "#{window_index}"

# Reduce escape delay for responsive feel
set -sg escape-time 10
TMUX_CONFIG

chown "$USER_NAME:$USER_NAME" "$USER_HOME/.tmux.conf"
print_success "tmux config updated"

# ---- custom ttyd frontend ----
mkdir -p /usr/local/share/claude-terminal
cp "$SCRIPT_DIR/html/"* /usr/local/share/claude-terminal/
print_success "custom ttyd frontend installed"

# ---- systemd service (tmux-based with boot recovery) ----
cat > /etc/systemd/system/claude-terminal.service << EOF
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

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$USER_HOME
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable claude-terminal
print_success "systemd service installed (tmux + boot recovery)"

# ---- claude-launcher ----
cat > /usr/local/bin/claude-launcher << 'LAUNCHER'
#!/bin/bash
# Interactive project picker - launch multiple Claude Code sessions

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$TMUX" ]; then
    echo -e "${CYAN}Starting tmux session...${NC}"
    exec tmux new-session -A -s claude
fi

# Verify tmux session is healthy
if ! tmux has-session -t claude 2>/dev/null; then
    echo -e "${YELLOW}tmux session not found. Please restart the service: sudo systemctl restart claude-terminal${NC}"
    exit 1
fi

if ! command -v fzf &> /dev/null; then
    echo "fzf not installed. Run: sudo apt install fzf"
    exit 1
fi

if [ ! -d "$PROJECTS_DIR" ]; then
    echo "Projects directory not found: $PROJECTS_DIR"
    echo "Create it with: mkdir -p $PROJECTS_DIR"
    exit 1
fi

projects=$(find "$PROJECTS_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort)

if [ -z "$projects" ]; then
    echo "No projects found in $PROJECTS_DIR"
    exit 1
fi

echo -e "${GREEN}Select projects (Tab=multi-select, Enter=launch):${NC}"
echo ""

selected=$(echo "$projects" | fzf --multi \
    --height=50% \
    --layout=reverse \
    --border \
    --prompt="Projects: " \
    --header="Tab=select, Enter=launch, Esc=cancel" \
    --preview="ls -la $PROJECTS_DIR/{}" \
    --preview-window=right:40%)

if [ -z "$selected" ]; then
    echo "No projects selected."
    exit 0
fi

echo ""
echo -e "${CYAN}Launching...${NC}"

for project in $selected; do
    echo -e "  ${GREEN}→${NC} $project"
    # Switch to existing window if project is already open, otherwise create new
    if tmux list-windows -t claude -F '#W' 2>/dev/null | grep -qx "$project"; then
        tmux select-window -t "claude:$project"
    else
        tmux new-window -a -t claude -n "$project"
        sleep 0.3
        tmux send-keys -t "claude:$project" "cd $PROJECTS_DIR/$project && $CLAUDE_CMD" Enter
    fi
    sleep 0.2
done

echo ""
echo -e "${GREEN}✓ Done! Switch tabs with Alt+1-9 or tap tab bar${NC}"
LAUNCHER
chmod +x /usr/local/bin/claude-launcher
print_success "claude-launcher updated"

# ---- clp ----
cat > /usr/local/bin/clp << 'CLP'
#!/bin/bash
# Quick launch a single project

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

if [ -z "$1" ]; then
    echo "Usage: clp <project-name>"
    echo ""
    echo "Available projects:"
    ls -1 "$PROJECTS_DIR" 2>/dev/null | sed 's/^/  /'
    exit 1
fi

PROJECT="$1"
PROJECT_PATH="$PROJECTS_DIR/$PROJECT"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Project not found: $PROJECT"
    echo ""
    echo "Similar projects:"
    ls -1 "$PROJECTS_DIR" | grep -i "$PROJECT" | sed 's/^/  /'
    exit 1
fi

if [ -z "$TMUX" ]; then
    exec tmux new-session -A -s claude
fi

if tmux list-windows -t claude -F '#W' 2>/dev/null | grep -qx "$PROJECT"; then
    tmux select-window -t "claude:$PROJECT"
    echo "Switched to: $PROJECT"
else
    tmux new-window -a -t claude -n "$PROJECT"
    sleep 0.3
    tmux send-keys -t "claude:$PROJECT" "cd $PROJECT_PATH && $CLAUDE_CMD" Enter
    echo "Launched: $PROJECT"
fi
CLP
chmod +x /usr/local/bin/clp
print_success "clp updated"

# ---- cnew ----
cat > /usr/local/bin/cnew << 'CNEW'
#!/bin/bash
# Create a new project and launch Claude Code in it

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

if [ -z "$1" ]; then
    echo "Usage: cnew <project-name>"
    echo "Creates ~/projects/<project-name> and launches Claude Code in it."
    exit 1
fi

PROJECT="$1"
PROJECT_PATH="$PROJECTS_DIR/$PROJECT"

if [ -d "$PROJECT_PATH" ]; then
    echo "Project already exists: $PROJECT_PATH"
    echo "Use 'clp $PROJECT' to launch it."
    exit 1
fi

mkdir -p "$PROJECT_PATH"
echo "Created: $PROJECT_PATH"

if [ -z "$TMUX" ]; then
    exec tmux new-session -A -s claude
fi

tmux new-window -t claude -n "$PROJECT"
sleep 0.3
tmux send-keys -t "claude:$PROJECT" "cd $PROJECT_PATH && $CLAUDE_CMD" Enter

echo "Launched: $PROJECT"
CNEW
chmod +x /usr/local/bin/cnew
print_success "cnew updated"

# ---- cls ----
cat > /usr/local/bin/cls << 'CLS'
#!/bin/bash
# Show Claude terminal service status and active sessions

echo "=== Service Status ==="
systemctl is-active --quiet claude-terminal && echo "Service: running" || echo "Service: stopped"

echo ""
echo "=== Active Sessions ==="
if tmux has-session -t claude 2>/dev/null; then
    tmux list-windows -t claude -F "  #I: #W" 2>/dev/null
else
    echo "  No active tmux session"
fi
CLS
chmod +x /usr/local/bin/cls
print_success "cls updated"

# ---- tj ----
cat > /usr/local/bin/tj << 'TJ'
#!/bin/bash
# Attach to the Claude tmux session from any terminal

if [ -n "$TMUX" ]; then
    echo "Already inside tmux."
    exit 0
fi

exec tmux attach-session -t claude 2>/dev/null || echo "No active session. Start with: sudo systemctl start claude-terminal"
TJ
chmod +x /usr/local/bin/tj
print_success "tj updated"

# ---- healthcheck script ----
cat > /usr/local/bin/claude-terminal-healthcheck << 'HEALTHCHECK'
#!/bin/bash
TMUX_SESSION="claude"
LOG_TAG="claude-healthcheck"

log() { logger -t "$LOG_TAG" "$1"; }

# Check if ttyd process is alive and listening
if systemctl is-active --quiet claude-terminal; then
    TTYD_PID=$(systemctl show claude-terminal -p MainPID --value 2>/dev/null)
    if [ -n "$TTYD_PID" ] && [ "$TTYD_PID" != "0" ] && kill -0 "$TTYD_PID" 2>/dev/null; then
        log "Service healthy (ttyd PID=$TTYD_PID)"
    else
        log "ttyd process is gone but service is active. Restarting service."
        systemctl restart claude-terminal
        log "Service restarted."
    fi
fi

# Kill orphaned 'tmux send-keys' processes running longer than 30s
while IFS= read -r pid; do
    [ -z "$pid" ] && continue
    elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$elapsed" ] && [ "$elapsed" -gt 30 ]; then
        log "Killing hung tmux send-keys process (PID=$pid, elapsed=${elapsed}s)"
        kill "$pid" 2>/dev/null
    fi
done < <(pgrep -f "tmux send-keys" 2>/dev/null)
HEALTHCHECK
chmod +x /usr/local/bin/claude-terminal-healthcheck
print_success "healthcheck script installed"

# ---- systemd timer ----
cat > /etc/systemd/system/claude-terminal-healthcheck.service << 'EOF'
[Unit]
Description=Claude Code Web Terminal Health Check

[Service]
Type=oneshot
ExecStart=/usr/local/bin/claude-terminal-healthcheck
EOF

cat > /etc/systemd/system/claude-terminal-healthcheck.timer << 'EOF'
[Unit]
Description=Run Claude terminal health check every 30 seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s
AccuracySec=5s

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable claude-terminal-healthcheck.timer
systemctl start claude-terminal-healthcheck.timer
print_success "healthcheck timer enabled"

# ---- Write install marker ----
touch "$MARKER_FILE"

# ============================================================================
# USER SETTINGS (fresh install only)
# ============================================================================
# Load existing settings as defaults (if upgrading)
user_cmd="claude"
user_projects="$USER_HOME/projects"
user_sudo_enabled="no"
if [[ -f "$SETTINGS_FILE" ]]; then
    source "$SETTINGS_FILE"
    user_cmd="${CLAUDE_CMD:-claude}"
    user_projects="${CLAUDE_PROJECTS_DIR:-$USER_HOME/projects}"
    user_sudo_enabled="${REMOTE_SUDO:-no}"
fi

CONFIGURE_SETTINGS=true
if [[ "$IS_UPGRADE" == true ]]; then
    echo ""
    print_info "Current settings:"
    echo "  Claude command:    $user_cmd"
    echo "  Projects directory: $user_projects"
    echo "  Remote sudo:       $user_sudo_enabled"
    echo ""
    read -p "Change any settings? [y/N]: " change_settings < /dev/tty
    [[ "$change_settings" != "y" && "$change_settings" != "Y" ]] && CONFIGURE_SETTINGS=false
fi

if [[ "$CONFIGURE_SETTINGS" == true ]]; then
    echo ""
    echo -e "${CYAN}── User Configuration ──${NC}"
    echo ""
    echo "Claude Code launch command (current: $user_cmd)"
    read -p "Command [$user_cmd]: " new_cmd < /dev/tty
    user_cmd="${new_cmd:-$user_cmd}"
    echo ""
    echo "Projects directory (current: $user_projects)"
    read -p "Directory [$user_projects]: " new_projects < /dev/tty
    user_projects="${new_projects:-$user_projects}"
    user_projects="${user_projects/#\~/$USER_HOME}"

    if [[ ! -d "$user_projects" ]]; then
        sudo -u "$USER_NAME" mkdir -p "$user_projects"
        print_success "Created projects directory: $user_projects"
    fi

    if prompt_remote_sudo; then
        user_sudo_enabled="yes"
    else
        # If was enabled and user declined, remove sudoers
        if [[ "$user_sudo_enabled" == "yes" ]]; then
            rm -f /etc/sudoers.d/claude-terminal
            print_info "Remote sudo disabled"
        fi
        user_sudo_enabled="no"
    fi
fi

# Write settings file
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"
cat > "$SETTINGS_FILE" << SETTINGS
# Claude Code Web Terminal — User Settings
# Edit these values to customize your setup.
# Changes take effect on next shell login.
CLAUDE_CMD="$user_cmd"
CLAUDE_PROJECTS_DIR="$user_projects"
REMOTE_SUDO="$user_sudo_enabled"
SETTINGS
chown "$USER_NAME:$USER_NAME" "$SETTINGS_FILE"
print_success "Settings saved to $SETTINGS_FILE"

# Add bashrc block (if not already present)
if ! grep -qF "$BASHRC_START" "$USER_HOME/.bashrc" 2>/dev/null; then
    cat >> "$USER_HOME/.bashrc" << 'BASHRC_BLOCK'

# --- claude-terminal-config-start ---
if [ -f "$HOME/.config/claude-terminal/settings.conf" ]; then
    source "$HOME/.config/claude-terminal/settings.conf"
fi
export CLAUDE_CMD="${CLAUDE_CMD:-claude}"
export CLAUDE_PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
alias cl='claude-launcher'
# --- claude-terminal-config-end ---
BASHRC_BLOCK
    print_success "Shell aliases added to .bashrc"
else
    print_info "Shell aliases already present in .bashrc"
fi

# ---- Done ----
echo ""
if [[ "$IS_UPGRADE" == true ]]; then
    echo -e "${GREEN}Upgrade complete.${NC} Restart the service to apply:"
else
    echo -e "${GREEN}Installation complete.${NC} Start the service:"
fi
echo "  sudo systemctl restart claude-terminal"
echo ""
