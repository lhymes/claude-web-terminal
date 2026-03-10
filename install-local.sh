#!/bin/bash
set -e

# ============================================================================
# Claude Code Web Terminal — Installer / Upgrader / Uninstaller
# Multi-instance support with color theming
#
# Usage: sudo ./install-local.sh                                     # Install or upgrade
#        sudo ./install-local.sh --uninstall                         # Remove everything
#        sudo ./install-local.sh --add-instance NAME [--color COLOR] # Add instance
#        sudo ./install-local.sh --remove-instance NAME              # Remove instance
#        sudo ./install-local.sh --list-instances                    # List all instances
#        sudo ./install-local.sh --color COLOR                       # Set default color
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

# ============================================================================
# ACCENT COLOR PALETTES
# ============================================================================
AVAILABLE_COLORS="blue green purple orange red teal yellow pink"

get_color_primary() {
    case "$1" in
        blue) echo "#569cd6" ;; green) echo "#6a9955" ;;
        purple) echo "#c586c0" ;; orange) echo "#ce9178" ;;
        red) echo "#f44747" ;; teal) echo "#4ec9b0" ;;
        yellow) echo "#dcdcaa" ;; pink) echo "#d16d9e" ;;
        *) echo "#569cd6" ;;
    esac
}

get_color_dark() {
    case "$1" in
        blue) echo "#264f78" ;; green) echo "#2d4a23" ;;
        purple) echo "#5c3a58" ;; orange) echo "#5c3d30" ;;
        red) echo "#6e1e1e" ;; teal) echo "#1e5c4f" ;;
        yellow) echo "#5c5c3a" ;; pink) echo "#5c2e44" ;;
        *) echo "#264f78" ;;
    esac
}

get_color_hover() {
    case "$1" in
        blue) echo "#2d5f8a" ;; green) echo "#3a5c2e" ;;
        purple) echo "#6e4568" ;; orange) echo "#6e4a3a" ;;
        red) echo "#802828" ;; teal) echo "#286e5e" ;;
        yellow) echo "#6e6e45" ;; pink) echo "#6e3852" ;;
        *) echo "#2d5f8a" ;;
    esac
}

get_color_active() {
    case "$1" in
        blue) echo "#3a6a9e" ;; green) echo "#4a7038" ;;
        purple) echo "#7d5078" ;; orange) echo "#7d5544" ;;
        red) echo "#923232" ;; teal) echo "#32806d" ;;
        yellow) echo "#808050" ;; pink) echo "#804260" ;;
        *) echo "#3a6a9e" ;;
    esac
}

validate_color() {
    if [[ ! " $AVAILABLE_COLORS " =~ " $1 " ]]; then
        print_error "Unknown color: $1"
        print_info "Available: $AVAILABLE_COLORS"
        exit 1
    fi
}

validate_instance_name() {
    if [[ ! "$1" =~ ^[a-z][a-z0-9-]*$ ]]; then
        print_error "Instance name must be lowercase, start with a letter, contain only letters/numbers/hyphens"
        exit 1
    fi
    if [[ "$1" == "default" ]]; then
        print_error "'default' is reserved — use --color to change the default instance's theme"
        exit 1
    fi
}

# ============================================================================
# HELPER: prompt for remote sudo
# ============================================================================
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

# ============================================================================
# CONSTANTS
# ============================================================================
BASHRC_START="# --- claude-terminal-config-start ---"
BASHRC_END="# --- claude-terminal-config-end ---"
MARKER_FILE="/usr/local/share/claude-terminal/.installed"
REGISTRY_FILE="/usr/local/share/claude-terminal/instances"

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
ACTION="install"
INSTANCE_NAME=""
INSTANCE_COLOR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --uninstall)
            ACTION="uninstall"; shift ;;
        --add-instance)
            ACTION="add-instance"
            if [[ -z "${2:-}" ]]; then print_error "Missing instance name"; exit 1; fi
            INSTANCE_NAME="$2"; shift 2 ;;
        --remove-instance)
            ACTION="remove-instance"
            if [[ -z "${2:-}" ]]; then print_error "Missing instance name"; exit 1; fi
            INSTANCE_NAME="$2"; shift 2 ;;
        --list-instances)
            ACTION="list-instances"; shift ;;
        --color)
            if [[ -z "${2:-}" ]]; then print_error "Missing color name"; exit 1; fi
            INSTANCE_COLOR="$2"; shift 2 ;;
        --blue|--green|--purple|--orange|--red|--teal|--yellow|--pink)
            INSTANCE_COLOR="${1#--}"; shift ;;
        *)
            shift ;;
    esac
done

[[ -n "$INSTANCE_COLOR" ]] && validate_color "$INSTANCE_COLOR"
[[ "$ACTION" == "add-instance" ]] && validate_instance_name "$INSTANCE_NAME"

# ============================================================================
# ROOT CHECK
# ============================================================================
if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install-local.sh"
    exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
CONFIG_DIR="$USER_HOME/.config/claude-terminal"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# HELPER: write tmux config with themed accent color
# ============================================================================
write_tmux_config() {
    local dest="$1" color="$2"
    local primary
    primary=$(get_color_primary "$color")
    cat > "$dest" << TMUX_CONFIG
# Claude Code Web Terminal - tmux Configuration
# Accent color: $color ($primary)

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
setw -g window-status-current-style "bg=$primary,fg=#1e1e1e,bold"
setw -g window-status-style "bg=#2d2d2d,fg=#d4d4d4"
setw -g window-status-separator ""

# Report active window index via terminal title (parsed by web frontend)
set -g set-titles on
set -g set-titles-string "#{window_index}:#{window_name}"

# Reduce escape delay for responsive feel
set -sg escape-time 10
TMUX_CONFIG
    chown "$USER_NAME:$USER_NAME" "$dest"
}

# ============================================================================
# HELPER: generate themed HTML from master
# ============================================================================
theme_html() {
    local src="$1" dest="$2" color="$3"
    local primary dark hover active
    primary=$(get_color_primary "$color")
    dark=$(get_color_dark "$color")
    hover=$(get_color_hover "$color")
    active=$(get_color_active "$color")
    cp "$src" "$dest"
    if [[ "$color" != "blue" ]]; then
        sed -i "s/#569cd6/$primary/g" "$dest"
        sed -i "s/#264f78/$dark/g" "$dest"
        sed -i "s/#2d5f8a/$hover/g" "$dest"
        sed -i "s/#3a6a9e/$active/g" "$dest"
    fi
}

# ============================================================================
# INSTANCE REGISTRY HELPERS
# ============================================================================
get_next_port() {
    local max_port=7681
    if [[ -f "$REGISTRY_FILE" ]]; then
        while IFS=: read -r name port color; do
            [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
            (( port > max_port )) && max_port=$port
        done < "$REGISTRY_FILE"
    fi
    echo $(( max_port + 1 ))
}

register_instance() {
    local name="$1" port="$2" color="$3"
    mkdir -p "$(dirname "$REGISTRY_FILE")"
    # Remove existing entry for this name, then append
    if [[ -f "$REGISTRY_FILE" ]]; then
        sed -i "/^${name}:/d" "$REGISTRY_FILE"
    fi
    echo "${name}:${port}:${color}" >> "$REGISTRY_FILE"
}

unregister_instance() {
    if [[ -f "$REGISTRY_FILE" ]]; then
        sed -i "/^${1}:/d" "$REGISTRY_FILE"
    fi
}

get_instance_port() {
    if [[ -f "$REGISTRY_FILE" ]]; then
        grep "^${1}:" "$REGISTRY_FILE" 2>/dev/null | cut -d: -f2
    fi
}

get_instance_color() {
    if [[ -f "$REGISTRY_FILE" ]]; then
        grep "^${1}:" "$REGISTRY_FILE" 2>/dev/null | cut -d: -f3
    fi
}

# ============================================================================
# HELPER: create systemd service for an instance
# ============================================================================
write_instance_service() {
    local name="$1" port="$2" index_path="$3" tmux_cmd="$4" home_dir="${5:-$USER_HOME}"
    local svc_name="claude-terminal"
    [[ "$name" != "default" ]] && svc_name="claude-terminal-${name}"

    cat > "/etc/systemd/system/${svc_name}.service" << EOF
[Unit]
Description=Claude Code Web Terminal — ${name} (port ${port})
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=simple
User=$USER_NAME
Environment="HOME=$home_dir"
Environment="TERM=xterm-256color"
WorkingDirectory=$USER_HOME

ExecStart=/usr/bin/ttyd \\
    --writable \\
    --port ${port} \\
    --base-path / \\
    --index ${index_path} \\
    ${tmux_cmd}

Restart=always
RestartSec=5

# Security hardening
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$USER_HOME
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$svc_name" 2>/dev/null
}

# ============================================================================
# ACTION: --list-instances
# ============================================================================
if [[ "$ACTION" == "list-instances" ]]; then
    echo ""
    echo -e "${CYAN}Claude Code Web Terminal — Instances${NC}"
    echo ""
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        if systemctl is-active --quiet claude-terminal 2>/dev/null; then
            echo -e "  default    port 7681  blue    ${GREEN}running${NC}"
        else
            echo "  No instances found. Install first: sudo ./install-local.sh"
        fi
    else
        printf "  %-12s %-12s %-10s %s\n" "NAME" "PORT" "COLOR" "STATUS"
        printf "  %-12s %-12s %-10s %s\n" "────" "────" "─────" "──────"
        while IFS=: read -r name port color; do
            [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
            local_svc="claude-terminal"
            [[ "$name" != "default" ]] && local_svc="claude-terminal-${name}"
            if systemctl is-active --quiet "$local_svc" 2>/dev/null; then
                printf "  %-12s %-12s %-10s " "$name" "$port" "$color"
                echo -e "${GREEN}running${NC}"
            else
                printf "  %-12s %-12s %-10s " "$name" "$port" "$color"
                echo -e "${RED}stopped${NC}"
            fi
        done < "$REGISTRY_FILE"
    fi
    echo ""
    exit 0
fi

# ============================================================================
# ACTION: --add-instance
# ============================================================================
if [[ "$ACTION" == "add-instance" ]]; then
    echo ""
    echo -e "${CYAN}Claude Code Web Terminal — Add Instance: ${INSTANCE_NAME}${NC}"
    echo ""

    # Check for existing instance
    existing_port=$(get_instance_port "$INSTANCE_NAME")
    if [[ -n "$existing_port" ]]; then
        print_error "Instance '$INSTANCE_NAME' already exists (port $existing_port)"
        print_info "Remove first: sudo ./install-local.sh --remove-instance $INSTANCE_NAME"
        exit 1
    fi

    # Check master HTML exists
    MASTER_HTML="/usr/local/share/claude-terminal/index.html"
    if [[ ! -f "$MASTER_HTML" ]]; then
        print_error "Default installation not found. Run 'sudo ./install-local.sh' first."
        exit 1
    fi

    # Determine color (prompt if not specified)
    if [[ -z "$INSTANCE_COLOR" ]]; then
        echo "Available colors: $AVAILABLE_COLORS"
        echo ""
        read -p "Color for $INSTANCE_NAME [blue]: " INSTANCE_COLOR < /dev/tty
        INSTANCE_COLOR="${INSTANCE_COLOR:-blue}"
        validate_color "$INSTANCE_COLOR"
    fi

    # Assign port
    PORT=$(get_next_port)
    print_info "Assigning port $PORT"

    # Create themed HTML
    INST_DIR="/usr/local/share/claude-terminal/instances.d/${INSTANCE_NAME}"
    mkdir -p "$INST_DIR"
    theme_html "$MASTER_HTML" "$INST_DIR/index.html" "$INSTANCE_COLOR"
    print_success "Themed frontend created ($INSTANCE_COLOR)"

    # Create tmux config
    TMUX_CONF_DIR="$CONFIG_DIR/instances/${INSTANCE_NAME}"
    sudo -u "$USER_NAME" mkdir -p "$TMUX_CONF_DIR"
    write_tmux_config "$TMUX_CONF_DIR/tmux.conf" "$INSTANCE_COLOR"
    print_success "tmux config created"

    # Create instance home directory (isolates Claude Code auth)
    INST_HOME="$USER_HOME/.${INSTANCE_NAME}-home"
    sudo -u "$USER_NAME" mkdir -p "$INST_HOME"

    # Detect paths from main user's environment
    CLAUDE_BIN_DIR=$(sudo -u "$USER_NAME" bash -lc 'dirname "$(which claude 2>/dev/null)"' 2>/dev/null || echo "")
    NODE_BIN_DIR=$(sudo -u "$USER_NAME" bash -lc 'dirname "$(which node 2>/dev/null)"' 2>/dev/null || echo "")
    NVM_DIR_DETECT=$(sudo -u "$USER_NAME" bash -lc 'echo "$NVM_DIR"' 2>/dev/null || echo "")

    # Generate .bashrc with correct PATH
    cat > "$INST_HOME/.bashrc" << INST_BASHRC
# Claude Web Terminal — ${INSTANCE_NAME} instance
export PATH="${CLAUDE_BIN_DIR}:${NODE_BIN_DIR}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/snap/bin:\$PATH"
export CLAUDE_CMD="\${CLAUDE_CMD:-claude}"
export CLAUDE_PROJECTS_DIR="\${CLAUDE_PROJECTS_DIR:-${USER_HOME}/projects}"
alias cl='claude-launcher'
INST_BASHRC

    # Add nvm support if detected
    if [[ -n "$NVM_DIR_DETECT" && -d "$NVM_DIR_DETECT" ]]; then
        cat >> "$INST_HOME/.bashrc" << INST_NVM
export NVM_DIR="$NVM_DIR_DETECT"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
INST_NVM
    fi

    # Generate .profile to source .bashrc
    cat > "$INST_HOME/.profile" << 'INST_PROFILE'
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
INST_PROFILE

    chown -R "$USER_NAME:$USER_NAME" "$INST_HOME"
    print_success "Instance home created ($INST_HOME)"

    # Create systemd service
    TMUX_CMD="/usr/bin/tmux -L claude-${INSTANCE_NAME} -f ${TMUX_CONF_DIR}/tmux.conf new-session -A -s claude-${INSTANCE_NAME}"
    write_instance_service "$INSTANCE_NAME" "$PORT" "$INST_DIR/index.html" "$TMUX_CMD" "$INST_HOME"
    print_success "systemd service created: claude-terminal-${INSTANCE_NAME}"

    # Register
    register_instance "$INSTANCE_NAME" "$PORT" "$INSTANCE_COLOR"
    print_success "Instance registered"

    # Start service
    systemctl start "claude-terminal-${INSTANCE_NAME}"
    print_success "Service started"

    echo ""
    echo -e "${GREEN}Instance '${INSTANCE_NAME}' is ready!${NC}"
    echo ""
    echo "  Local access:  http://localhost:${PORT}"
    echo ""
    echo "  Tailscale (remote access):"
    echo "    tailscale serve --bg --https $((8000 + PORT - 7681)) ${PORT}"
    echo ""
    echo "  Service control:"
    echo "    sudo systemctl {start|stop|restart} claude-terminal-${INSTANCE_NAME}"
    echo ""
    exit 0
fi

# ============================================================================
# ACTION: --remove-instance
# ============================================================================
if [[ "$ACTION" == "remove-instance" ]]; then
    echo ""
    echo -e "${YELLOW}Claude Code Web Terminal — Remove Instance: ${INSTANCE_NAME}${NC}"
    echo ""

    existing_port=$(get_instance_port "$INSTANCE_NAME")
    if [[ -z "$existing_port" ]]; then
        print_error "Instance '$INSTANCE_NAME' not found"
        print_info "List instances: sudo ./install-local.sh --list-instances"
        exit 1
    fi

    echo "This will remove:"
    echo "  - Service: claude-terminal-${INSTANCE_NAME}"
    echo "  - Port: ${existing_port}"
    echo "  - Themed frontend and tmux config"
    echo "  - Instance home (~/.${INSTANCE_NAME}-home/) including Claude Code credentials"
    echo ""
    read -p "Continue? [y/N]: " confirm < /dev/tty
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Stop and remove service
    SVC="claude-terminal-${INSTANCE_NAME}"
    systemctl stop "$SVC" 2>/dev/null || true
    systemctl disable "$SVC" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SVC}.service"
    systemctl daemon-reload
    print_success "Service removed"

    # Kill tmux server for this instance
    sudo -u "$USER_NAME" tmux -L "claude-${INSTANCE_NAME}" kill-server 2>/dev/null || true
    print_success "tmux session killed"

    # Remove themed frontend
    rm -rf "/usr/local/share/claude-terminal/instances.d/${INSTANCE_NAME}"
    print_success "Themed frontend removed"

    # Remove tmux config
    rm -rf "$CONFIG_DIR/instances/${INSTANCE_NAME}"
    print_success "tmux config removed"

    # Remove instance home directory
    INST_HOME="$USER_HOME/.${INSTANCE_NAME}-home"
    if [[ -d "$INST_HOME" ]]; then
        rm -rf "$INST_HOME"
        print_success "Instance home removed ($INST_HOME)"
    fi

    # Unregister
    unregister_instance "$INSTANCE_NAME"
    print_success "Instance unregistered"

    echo ""
    echo -e "${GREEN}Instance '${INSTANCE_NAME}' removed.${NC}"
    echo ""
    print_info "If Tailscale was configured: tailscale serve --https=443 off"
    echo ""
    exit 0
fi

# ============================================================================
# UNINSTALL
# ============================================================================
if [[ "$ACTION" == "uninstall" ]]; then
    echo ""
    echo -e "${YELLOW}Claude Code Web Terminal — Uninstall${NC}"
    echo ""
    echo "This will remove:"
    echo "  - All systemd services (default + all instances)"
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

    # Stop and disable all instance services from registry
    if [[ -f "$REGISTRY_FILE" ]]; then
        while IFS=: read -r name port color; do
            [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
            svc="claude-terminal"
            [[ "$name" != "default" ]] && svc="claude-terminal-${name}"
            systemctl stop "$svc" 2>/dev/null || true
            systemctl disable "$svc" 2>/dev/null || true
            rm -f "/etc/systemd/system/${svc}.service"
            if [[ "$name" != "default" ]]; then
                sudo -u "$USER_NAME" tmux -L "claude-${name}" kill-server 2>/dev/null || true
                rm -rf "$USER_HOME/.${name}-home" 2>/dev/null || true
            fi
        done < "$REGISTRY_FILE"
    fi

    # Also clean defaults (in case registry is missing)
    systemctl stop claude-terminal-healthcheck.timer 2>/dev/null || true
    systemctl disable claude-terminal-healthcheck.timer 2>/dev/null || true
    systemctl stop claude-terminal 2>/dev/null || true
    systemctl disable claude-terminal 2>/dev/null || true
    rm -f /etc/systemd/system/claude-terminal.service
    rm -f /etc/systemd/system/claude-terminal-healthcheck.service
    rm -f /etc/systemd/system/claude-terminal-healthcheck.timer
    rm -f /etc/systemd/system/claude-terminal-*.service
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

    # Remove frontend files (includes all instance themes)
    rm -rf /usr/local/share/claude-terminal
    print_success "Frontend files removed"

    # Remove sudoers entry
    rm -f /etc/sudoers.d/claude-terminal
    print_success "Sudoers entry removed"

    # Remove config (includes instance configs)
    rm -rf "$CONFIG_DIR"
    print_success "Configuration removed"

    # Remove bashrc block
    if grep -qF "$BASHRC_START" "$USER_HOME/.bashrc" 2>/dev/null; then
        sed -i "/$BASHRC_START/,/$BASHRC_END/d" "$USER_HOME/.bashrc"
        print_success "Shell configuration removed from .bashrc"
    fi

    # Remove tmux.conf
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
# INSTALL / UPGRADE (default instance)
# ============================================================================
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

# Determine default instance color (preserve existing on upgrade)
DEFAULT_COLOR="${INSTANCE_COLOR:-blue}"
if [[ "$IS_UPGRADE" == true && -z "$INSTANCE_COLOR" ]]; then
    existing_color=$(get_instance_color "default")
    [[ -n "$existing_color" ]] && DEFAULT_COLOR="$existing_color"
fi

# ---- tmux config (default instance) ----
write_tmux_config "$USER_HOME/.tmux.conf" "$DEFAULT_COLOR"
print_success "tmux config updated ($DEFAULT_COLOR)"

# ---- custom ttyd frontend (master copy, always blue) ----
mkdir -p /usr/local/share/claude-terminal
cp "$SCRIPT_DIR/html/"* /usr/local/share/claude-terminal/
print_success "custom ttyd frontend installed"

# Generate themed default HTML if non-blue
DEFAULT_INDEX="/usr/local/share/claude-terminal/index.html"
if [[ "$DEFAULT_COLOR" != "blue" ]]; then
    THEMED_DIR="/usr/local/share/claude-terminal/instances.d/default"
    mkdir -p "$THEMED_DIR"
    theme_html "/usr/local/share/claude-terminal/index.html" "$THEMED_DIR/index.html" "$DEFAULT_COLOR"
    DEFAULT_INDEX="$THEMED_DIR/index.html"
    print_success "Default theme applied ($DEFAULT_COLOR)"
fi

# ---- systemd service (default instance) ----
write_instance_service "default" "7681" "$DEFAULT_INDEX" "/usr/bin/tmux new-session -A -s claude"
print_success "systemd service installed (tmux + boot recovery)"

# Register default instance
register_instance "default" "7681" "$DEFAULT_COLOR"

# ---- Session-aware CLI tools ----

cat > /usr/local/bin/claude-launcher << 'LAUNCHER'
#!/bin/bash
# Interactive project picker - launch multiple Claude Code sessions

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Auto-detect current tmux session
if [ -n "$TMUX" ]; then
    SESSION=$(tmux display-message -p '#S')
else
    SESSION="claude"
    echo -e "${CYAN}Starting tmux session...${NC}"
    exec tmux new-session -A -s "$SESSION"
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${YELLOW}tmux session not found. Restart the service.${NC}"
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
    if tmux list-windows -t "$SESSION" -F '#W' 2>/dev/null | grep -qx "$project"; then
        tmux select-window -t "$SESSION:$project"
    else
        tmux new-window -a -t "$SESSION" -n "$project"
        sleep 0.3
        tmux send-keys -t "$SESSION:$project" "cd $PROJECTS_DIR/$project && $CLAUDE_CMD" Enter
    fi
    sleep 0.2
done

echo ""
echo -e "${GREEN}Done! Switch tabs with Alt+1-9 or tap tab bar${NC}"
LAUNCHER
chmod +x /usr/local/bin/claude-launcher
print_success "claude-launcher updated"

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

# Auto-detect current tmux session
if [ -n "$TMUX" ]; then
    SESSION=$(tmux display-message -p '#S')
else
    SESSION="claude"
    exec tmux new-session -A -s "$SESSION"
fi

if tmux list-windows -t "$SESSION" -F '#W' 2>/dev/null | grep -qx "$PROJECT"; then
    tmux select-window -t "$SESSION:$PROJECT"
    echo "Switched to: $PROJECT"
else
    tmux new-window -a -t "$SESSION" -n "$PROJECT"
    sleep 0.3
    tmux send-keys -t "$SESSION:$PROJECT" "cd $PROJECT_PATH && $CLAUDE_CMD" Enter
    echo "Launched: $PROJECT"
fi
CLP
chmod +x /usr/local/bin/clp
print_success "clp updated"

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

# Auto-detect current tmux session
if [ -n "$TMUX" ]; then
    SESSION=$(tmux display-message -p '#S')
else
    SESSION="claude"
    exec tmux new-session -A -s "$SESSION"
fi

tmux new-window -t "$SESSION" -n "$PROJECT"
sleep 0.3
tmux send-keys -t "$SESSION:$PROJECT" "cd $PROJECT_PATH && $CLAUDE_CMD" Enter

echo "Launched: $PROJECT"
CNEW
chmod +x /usr/local/bin/cnew
print_success "cnew updated"

cat > /usr/local/bin/cls << 'CLS'
#!/bin/bash
# Show Claude terminal instance status and active sessions

REGISTRY="/usr/local/share/claude-terminal/instances"

echo "=== Instances ==="
if [[ -f "$REGISTRY" ]]; then
    while IFS=: read -r name port color; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        svc="claude-terminal"
        [[ "$name" != "default" ]] && svc="claude-terminal-${name}"
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo "  $name: running (port $port, $color)"
        else
            echo "  $name: stopped (port $port, $color)"
        fi
    done < "$REGISTRY"
else
    systemctl is-active --quiet claude-terminal 2>/dev/null \
        && echo "  default: running" || echo "  default: stopped"
fi

echo ""
echo "=== Active Sessions ==="

# Default instance
if tmux has-session -t claude 2>/dev/null; then
    echo "  [default]"
    tmux list-windows -t claude -F "    #I: #W" 2>/dev/null
fi

# Additional instances from registry
if [[ -f "$REGISTRY" ]]; then
    while IFS=: read -r name port color; do
        [[ "$name" =~ ^#.*$ || -z "$name" || "$name" == "default" ]] && continue
        sess="claude-${name}"
        if tmux -L "$sess" has-session -t "$sess" 2>/dev/null; then
            echo "  [$name]"
            tmux -L "$sess" list-windows -t "$sess" -F "    #I: #W" 2>/dev/null
        fi
    done < "$REGISTRY"
fi
CLS
chmod +x /usr/local/bin/cls
print_success "cls updated"

cat > /usr/local/bin/tj << 'TJ'
#!/bin/bash
# Attach to a Claude tmux session from any terminal
# Usage: tj          (attach to default)
#        tj <name>   (attach to named instance)

if [ -n "$TMUX" ]; then
    echo "Already inside tmux."
    exit 0
fi

if [ -n "$1" ]; then
    exec tmux -L "claude-$1" attach-session -t "claude-$1" 2>/dev/null \
        || echo "No active session for '$1'. Start: sudo systemctl start claude-terminal-$1"
else
    exec tmux attach-session -t claude 2>/dev/null \
        || echo "No active session. Start: sudo systemctl start claude-terminal"
fi
TJ
chmod +x /usr/local/bin/tj
print_success "tj updated"

# ---- healthcheck script (multi-instance aware) ----
cat > /usr/local/bin/claude-terminal-healthcheck << 'HEALTHCHECK'
#!/bin/bash
LOG_TAG="claude-healthcheck"
REGISTRY="/usr/local/share/claude-terminal/instances"

log() { logger -t "$LOG_TAG" "$1"; }

check_service() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        TTYD_PID=$(systemctl show "$svc" -p MainPID --value 2>/dev/null)
        if [ -n "$TTYD_PID" ] && [ "$TTYD_PID" != "0" ] && kill -0 "$TTYD_PID" 2>/dev/null; then
            log "$svc healthy (PID=$TTYD_PID)"
        else
            log "$svc: ttyd gone. Restarting."
            systemctl restart "$svc"
            log "$svc restarted."
        fi
    fi
}

# Check default
check_service "claude-terminal"

# Check additional instances
if [ -f "$REGISTRY" ]; then
    while IFS=: read -r name port color; do
        [[ "$name" =~ ^#.*$ || -z "$name" || "$name" == "default" ]] && continue
        check_service "claude-terminal-${name}"
    done < "$REGISTRY"
fi

# Kill orphaned 'tmux send-keys' processes running longer than 30s
while IFS= read -r pid; do
    [ -z "$pid" ] && continue
    elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$elapsed" ] && [ "$elapsed" -gt 30 ]; then
        log "Killing hung tmux send-keys (PID=$pid, ${elapsed}s)"
        kill "$pid" 2>/dev/null
    fi
done < <(pgrep -f "tmux send-keys" 2>/dev/null)
HEALTHCHECK
chmod +x /usr/local/bin/claude-terminal-healthcheck
print_success "healthcheck script installed (multi-instance)"

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
# UPGRADE ADDITIONAL INSTANCES
# ============================================================================
if [[ "$IS_UPGRADE" == true && -f "$REGISTRY_FILE" ]]; then
    MASTER_HTML="/usr/local/share/claude-terminal/index.html"
    instance_count=0
    while IFS=: read -r name port color; do
        [[ "$name" =~ ^#.*$ || -z "$name" || "$name" == "default" ]] && continue
        instance_count=$((instance_count + 1))

        # Regenerate themed HTML from updated master
        INST_DIR="/usr/local/share/claude-terminal/instances.d/${name}"
        mkdir -p "$INST_DIR"
        theme_html "$MASTER_HTML" "$INST_DIR/index.html" "$color"

        # Regenerate tmux config
        TMUX_CONF="$CONFIG_DIR/instances/${name}/tmux.conf"
        if [[ -d "$(dirname "$TMUX_CONF")" ]]; then
            write_tmux_config "$TMUX_CONF" "$color"
        fi

        # Regenerate service file
        TMUX_CMD="/usr/bin/tmux -L claude-${name} -f ${CONFIG_DIR}/instances/${name}/tmux.conf new-session -A -s claude-${name}"
        write_instance_service "$name" "$port" "$INST_DIR/index.html" "$TMUX_CMD"
    done < "$REGISTRY_FILE"
    if [[ $instance_count -gt 0 ]]; then
        print_success "Upgraded $instance_count additional instance(s)"
    fi
fi

# ============================================================================
# USER SETTINGS
# ============================================================================
# Load existing settings as defaults (if upgrading)
user_cmd="claude"
user_projects="$USER_HOME/projects"
user_sudo_enabled="no"
user_sudo_locked="no"
if [[ -f "$SETTINGS_FILE" ]]; then
    source "$SETTINGS_FILE"
    user_cmd="${CLAUDE_CMD:-claude}"
    user_projects="${CLAUDE_PROJECTS_DIR:-$USER_HOME/projects}"
    user_sudo_enabled="${REMOTE_SUDO:-no}"
    user_sudo_locked="${REMOTE_SUDO_LOCKED:-no}"
fi

CONFIGURE_SETTINGS=true
if [[ "$IS_UPGRADE" == true ]]; then
    echo ""
    print_info "Current settings:"
    echo "  Claude command:     $user_cmd"
    echo "  Projects directory: $user_projects"
    echo "  Default color:      $DEFAULT_COLOR"
    if [[ "$user_sudo_locked" == "yes" ]]; then
        echo "  Remote sudo:        disabled (locked)"
    else
        echo "  Remote sudo:        $user_sudo_enabled"
    fi
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

    if [[ "$user_sudo_locked" == "yes" ]]; then
        echo ""
        echo -e "${YELLOW}── Remote Sudo Access ──${NC}"
        echo -e "  Remote sudo is ${RED}permanently disabled (locked)${NC}."
        echo "  To change this, uninstall first: sudo ./install-local.sh --uninstall"
        echo ""
    else
        if prompt_remote_sudo; then
            user_sudo_enabled="yes"
        else
            # If was enabled and user declined, remove sudoers
            if [[ "$user_sudo_enabled" == "yes" ]]; then
                rm -f /etc/sudoers.d/claude-terminal
                print_info "Remote sudo disabled"
            fi
            user_sudo_enabled="no"

            echo ""
            echo "  Lock this setting permanently? Future upgrades will skip this prompt."
            echo "  To enable sudo later, you must uninstall and reinstall."
            read -p "  Lock sudo off? [y/N]: " lock_sudo < /dev/tty
            if [[ "$lock_sudo" == "y" || "$lock_sudo" == "Y" ]]; then
                user_sudo_locked="yes"
                print_success "Remote sudo permanently locked off"
            fi
        fi
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
REMOTE_SUDO_LOCKED="$user_sudo_locked"
SETTINGS
chown "$USER_NAME:$USER_NAME" "$SETTINGS_FILE"
print_success "Settings saved to $SETTINGS_FILE"

# Apply NoNewPrivileges based on remote sudo setting
SERVICE_FILE="/etc/systemd/system/claude-terminal.service"
if [[ "$user_sudo_enabled" == "yes" ]]; then
    sed -i '/^NoNewPrivileges=/d' "$SERVICE_FILE"
    print_success "NoNewPrivileges disabled (remote sudo enabled)"
else
    if ! grep -q '^NoNewPrivileges=' "$SERVICE_FILE"; then
        sed -i '/^# Security hardening/a NoNewPrivileges=true' "$SERVICE_FILE"
    fi
fi
systemctl daemon-reload

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

# Show instance summary if any exist
if [[ -f "$REGISTRY_FILE" ]]; then
    extra_count=0
    while IFS=: read -r name port color; do
        [[ "$name" =~ ^#.*$ || -z "$name" || "$name" == "default" ]] && continue
        extra_count=$((extra_count + 1))
    done < "$REGISTRY_FILE"
    if [[ $extra_count -gt 0 ]]; then
        echo "  Also restart $extra_count additional instance(s):"
        while IFS=: read -r name port color; do
            [[ "$name" =~ ^#.*$ || -z "$name" || "$name" == "default" ]] && continue
            echo "    sudo systemctl restart claude-terminal-${name}"
        done < "$REGISTRY_FILE"
        echo ""
    fi
fi
