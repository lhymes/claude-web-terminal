#!/bin/bash
set -e

# ============================================================================
# Claude Code Web Terminal — macOS Installer / Upgrader / Uninstaller
# Usage: sudo ./install-mac.sh            # Install or upgrade
#        sudo ./install-mac.sh --uninstall # Remove everything
#
# NOTE: macOS support is in testing. Please report issues at:
#       https://github.com/lhymes/claude-web-terminal/issues
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

SHELL_RC_START="# --- claude-terminal-config-start ---"
SHELL_RC_END="# --- claude-terminal-config-end ---"
MARKER_FILE="/usr/local/share/claude-terminal/.installed"
PLIST_LABEL="com.claude-terminal.ttyd"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

# Determine user — sudo may or may not be used on macOS
if [[ $EUID -eq 0 ]]; then
    USER_NAME="${SUDO_USER:-$USER}"
    USER_HOME=$(dscl . -read "/Users/$USER_NAME" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    USER_HOME="${USER_HOME:-/Users/$USER_NAME}"
else
    USER_NAME="$USER"
    USER_HOME="$HOME"
fi

CONFIG_DIR="$USER_HOME/.config/claude-terminal"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"

# Detect shell rc file
if [[ "$SHELL" == *"zsh"* ]] || [[ -f "$USER_HOME/.zshrc" ]]; then
    SHELL_RC="$USER_HOME/.zshrc"
else
    SHELL_RC="$USER_HOME/.bashrc"
fi

# ============================================================================
# PREFLIGHT CHECKS
# ============================================================================
if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This installer is for macOS only. Use install-local.sh for Linux/WSL."
    exit 1
fi

# ============================================================================
# UNINSTALL
# ============================================================================
if [[ "${1:-}" == "--uninstall" ]]; then
    echo ""
    echo -e "${YELLOW}Claude Code Web Terminal — Uninstall (macOS)${NC}"
    echo ""
    echo "This will remove:"
    echo "  - launchd service ($PLIST_LABEL)"
    echo "  - CLI tools (claude-launcher, clp, cnew, cls, tj)"
    echo "  - Frontend files (/usr/local/share/claude-terminal/)"
    echo "  - Configuration (~/.config/claude-terminal/)"
    echo "  - Shell configuration ($SHELL_RC block + tmux.conf)"
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

    # Stop and remove launchd service
    PLIST_PATH_ACTUAL="$USER_HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
    if launchctl list "$PLIST_LABEL" &>/dev/null; then
        launchctl unload "$PLIST_PATH_ACTUAL" 2>/dev/null || true
    fi
    rm -f "$PLIST_PATH_ACTUAL"
    print_success "launchd service removed"

    # Remove CLI tools
    rm -f /usr/local/bin/claude-launcher
    rm -f /usr/local/bin/clp
    rm -f /usr/local/bin/cnew
    rm -f /usr/local/bin/cls-claude
    rm -f /usr/local/bin/tj
    print_success "CLI tools removed"

    # Remove frontend files
    sudo rm -rf /usr/local/share/claude-terminal
    print_success "Frontend files removed"

    # Remove sudoers entry
    sudo rm -f /etc/sudoers.d/claude-terminal
    print_success "Sudoers entry removed"

    # Remove config
    rm -rf "$CONFIG_DIR"
    print_success "Configuration removed"

    # Remove shell rc block
    if grep -qF "$SHELL_RC_START" "$SHELL_RC" 2>/dev/null; then
        sed -i '' "/$SHELL_RC_START/,/$SHELL_RC_END/d" "$SHELL_RC"
        print_success "Shell configuration removed from $SHELL_RC"
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
# CHECK DEPENDENCIES
# ============================================================================
echo ""
echo -e "${CYAN}── Checking Dependencies ──${NC}"
echo ""

MISSING=()
command -v brew &>/dev/null || {
    print_error "Homebrew is required. Install from https://brew.sh"
    exit 1
}
print_success "Homebrew found"

for dep in ttyd tmux fzf; do
    if command -v "$dep" &>/dev/null; then
        print_success "$dep found"
    else
        MISSING+=("$dep")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    print_info "Installing missing dependencies: ${MISSING[*]}"
    brew install "${MISSING[@]}"
    print_success "Dependencies installed"
fi

# Check for Claude Code
if command -v claude &>/dev/null; then
    print_success "Claude Code found"
else
    print_warn "Claude Code not found. Install from https://code.claude.com/docs/en/setup"
fi

# ============================================================================
# INSTALL / UPGRADE
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS_UPGRADE=false
if [[ -f "$MARKER_FILE" ]] || [[ -f "$SETTINGS_FILE" ]] \
   || [[ -f /usr/local/bin/claude-launcher ]]; then
    IS_UPGRADE=true
    print_info "Existing installation detected — upgrading"
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

# Reduce escape delay for responsive feel
set -sg escape-time 10
TMUX_CONFIG
print_success "tmux config updated"

# ---- custom ttyd frontend ----
sudo mkdir -p /usr/local/share/claude-terminal
sudo cp "$SCRIPT_DIR/html/"* /usr/local/share/claude-terminal/
print_success "custom ttyd frontend installed"

# ---- launchd service ----
TTYD_PATH="$(command -v ttyd)"
TMUX_PATH="$(command -v tmux)"

mkdir -p "$USER_HOME/Library/LaunchAgents"
cat > "$USER_HOME/Library/LaunchAgents/$PLIST_LABEL.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TTYD_PATH</string>
        <string>--writable</string>
        <string>--port</string>
        <string>7681</string>
        <string>--base-path</string>
        <string>/</string>
        <string>--index</string>
        <string>/usr/local/share/claude-terminal/index.html</string>
        <string>$TMUX_PATH</string>
        <string>new-session</string>
        <string>-A</string>
        <string>-s</string>
        <string>claude</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$USER_HOME</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$USER_HOME</string>
        <key>TERM</key>
        <string>xterm-256color</string>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/claude-terminal.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-terminal.log</string>
</dict>
</plist>
PLIST
print_success "launchd service installed"

# ---- CLI tools ----
# claude-launcher (find uses -printf on Linux; macOS needs different syntax)
cat > /usr/local/bin/claude-launcher << 'LAUNCHER'
#!/bin/bash
# Interactive project picker - launch multiple Claude Code sessions

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$TMUX" ]; then
    echo -e "${CYAN}Starting tmux session...${NC}"
    exec tmux new-session -A -s claude
fi

if ! tmux has-session -t claude 2>/dev/null; then
    echo -e "${YELLOW}tmux session not found. Run: launchctl start com.claude-terminal.ttyd${NC}"
    exit 1
fi

if ! command -v fzf &> /dev/null; then
    echo "fzf not installed. Run: brew install fzf"
    exit 1
fi

if [ ! -d "$PROJECTS_DIR" ]; then
    echo "Projects directory not found: $PROJECTS_DIR"
    echo "Create it with: mkdir -p $PROJECTS_DIR"
    exit 1
fi

projects=$(ls -1 "$PROJECTS_DIR" | sort)

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
print_success "claude-launcher installed"

# clp
cat > /usr/local/bin/clp << 'CLP'
#!/bin/bash
PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

if [ -z "$1" ]; then
    echo "Usage: clp <project-name>"
    echo ""; echo "Available projects:"
    ls -1 "$PROJECTS_DIR" 2>/dev/null | sed 's/^/  /'
    exit 1
fi

PROJECT="$1"
PROJECT_PATH="$PROJECTS_DIR/$PROJECT"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Project not found: $PROJECT"
    echo ""; echo "Similar projects:"
    ls -1 "$PROJECTS_DIR" | grep -i "$PROJECT" | sed 's/^/  /'
    exit 1
fi

[ -z "$TMUX" ] && exec tmux new-session -A -s claude

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
print_success "clp installed"

# cnew
cat > /usr/local/bin/cnew << 'CNEW'
#!/bin/bash
PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

if [ -z "$1" ]; then
    echo "Usage: cnew <project-name>"
    exit 1
fi

PROJECT="$1"
PROJECT_PATH="$PROJECTS_DIR/$PROJECT"

if [ -d "$PROJECT_PATH" ]; then
    echo "Project already exists. Use 'clp $PROJECT' to launch it."
    exit 1
fi

mkdir -p "$PROJECT_PATH"
echo "Created: $PROJECT_PATH"
[ -z "$TMUX" ] && exec tmux new-session -A -s claude
tmux new-window -a -t claude -n "$PROJECT"
sleep 0.3
tmux send-keys -t "claude:$PROJECT" "cd $PROJECT_PATH && $CLAUDE_CMD" Enter
echo "Launched: $PROJECT"
CNEW
chmod +x /usr/local/bin/cnew
print_success "cnew installed"

# cls-claude (macOS already has 'cls' in some shells; use cls-claude to avoid conflict)
cat > /usr/local/bin/cls-claude << 'CLS'
#!/bin/bash
echo "=== Service Status ==="
if launchctl list com.claude-terminal.ttyd &>/dev/null; then
    echo "Service: running"
else
    echo "Service: stopped"
fi
echo ""
echo "=== Active Sessions ==="
if tmux has-session -t claude 2>/dev/null; then
    tmux list-windows -t claude -F "  #I: #W" 2>/dev/null
else
    echo "  No active tmux session"
fi
CLS
chmod +x /usr/local/bin/cls-claude
print_success "cls-claude installed"

# tj
cat > /usr/local/bin/tj << 'TJ'
#!/bin/bash
[ -n "$TMUX" ] && echo "Already inside tmux." && exit 0
exec tmux attach-session -t claude 2>/dev/null || \
    echo "No active session. Start with: launchctl start com.claude-terminal.ttyd"
TJ
chmod +x /usr/local/bin/tj
print_success "tj installed"

# ---- Write install marker ----
sudo touch "$MARKER_FILE"

# ============================================================================
# USER SETTINGS
# ============================================================================
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
    echo "  Claude command:     $user_cmd"
    echo "  Projects directory: $user_projects"
    echo "  Remote sudo:        $user_sudo_enabled"
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
        mkdir -p "$user_projects"
        print_success "Created projects directory: $user_projects"
    fi

    if prompt_remote_sudo; then
        user_sudo_enabled="yes"
    else
        if [[ "$user_sudo_enabled" == "yes" ]]; then
            sudo rm -f /etc/sudoers.d/claude-terminal
            print_info "Remote sudo disabled"
        fi
        user_sudo_enabled="no"
    fi
fi

# Write settings
mkdir -p "$CONFIG_DIR"
cat > "$SETTINGS_FILE" << SETTINGS
# Claude Code Web Terminal — User Settings
CLAUDE_CMD="$user_cmd"
CLAUDE_PROJECTS_DIR="$user_projects"
REMOTE_SUDO="$user_sudo_enabled"
SETTINGS
print_success "Settings saved to $SETTINGS_FILE"

# Add shell rc block
if ! grep -qF "$SHELL_RC_START" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'SHELLBLOCK'

# --- claude-terminal-config-start ---
if [ -f "$HOME/.config/claude-terminal/settings.conf" ]; then
    source "$HOME/.config/claude-terminal/settings.conf"
fi
export CLAUDE_CMD="${CLAUDE_CMD:-claude}"
export CLAUDE_PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/projects}"
alias cl='claude-launcher'
alias cls='cls-claude'
# --- claude-terminal-config-end ---
SHELLBLOCK
    print_success "Shell aliases added to $SHELL_RC"
else
    print_info "Shell aliases already present in $SHELL_RC"
fi

# ---- Done ----
echo ""
if [[ "$IS_UPGRADE" == true ]]; then
    echo -e "${GREEN}Upgrade complete.${NC} Restart the service:"
else
    echo -e "${GREEN}Installation complete.${NC} Start the service:"
fi
echo "  launchctl load ~/Library/LaunchAgents/$PLIST_LABEL.plist"
echo ""
echo "Then open http://localhost:7681"
echo ""
echo -e "${YELLOW}NOTE: macOS support is in testing. Report issues at:${NC}"
echo "  https://github.com/lhymes/claude-web-terminal/issues"
echo ""
