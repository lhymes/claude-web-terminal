#!/bin/bash
set -e

# ============================================================================
# Local-only installer — applies latest scripts to this machine
# Usage: sudo ./install-local.sh
# Usage: sudo ./install-local.sh
# ============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-local.sh"
    exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

GREEN='\033[0;32m'
NC='\033[0m'
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }

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

# Reduce escape delay for responsive feel
set -sg escape-time 10
TMUX_CONFIG

chown "$USER_NAME:$USER_NAME" "$USER_HOME/.tmux.conf"
print_success "tmux config updated"

# ---- custom ttyd frontend ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p /usr/local/share/claude-terminal
cp "$SCRIPT_DIR/html/index.html" /usr/local/share/claude-terminal/index.html
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
    tmux new-window -t claude -n "$project"
    sleep 0.3
    tmux send-keys -t "claude:$project" "cd $PROJECTS_DIR/$project && $CLAUDE_CMD" Enter
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

tmux new-window -t claude -n "$PROJECT"
sleep 0.3
tmux send-keys -t "claude:$PROJECT" "cd $PROJECT_PATH && $CLAUDE_CMD" Enter

echo "Launched: $PROJECT"
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
# Note: tmux runs as a child of ttyd, so 'tmux has-session' won't find it.
# Instead, check that the ttyd process exists and its port is open.
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

echo ""
echo "All done. Local scripts updated (cl, clp, cnew, cls, tj + healthcheck)."
