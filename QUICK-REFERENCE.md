# Claude Code Web Terminal - Quick Reference

## Getting Started

1. Open browser: `http://localhost:7681` (local) or your Tailscale URL (remote)
2. Type `cl` to open the project picker (or click **+ New** on desktop, or tap **+** on mobile)
3. Select projects with arrow keys, **Tab** to multi-select, **Enter** to launch

---

## Switching Sessions

| Method | How |
|--------|-----|
| Keyboard | `Alt+1` through `Alt+9` |
| Mobile | Tap **⌨** to switch shortcut bar to tabs mode, then tap 1-9 |
| Desktop | Click tab buttons in floating toolbar (bottom-right) |
| New session | Click **+ New** in desktop toolbar (or tap **+** on mobile) |

---

## Commands

| Command | What It Does |
|---------|--------------|
| `cl` | Interactive project picker (multi-select with fzf) |
| `clp ProjectName` | Quick-launch one project |
| `cnew ProjectName` | Create + launch new project |
| `cls` | Check service status and active sessions |
| `tj` | Attach to tmux from another terminal |

---

## Mobile Interface

### Setup (One Time)
1. Install **Tailscale app** on your phone
2. Sign in to your tailnet
3. Open your terminal URL in Safari/Chrome
4. **Add to Home Screen** (Share menu) — launches as a full-screen standalone app

### Touch Controls

| Control | Where | What It Does |
|---------|-------|--------------|
| **Input bubble** | Above shortcut bar | Tap pill to expand, type/dictate, tap Send to paste into terminal |
| **Shortcut bar** (keys mode) | Bottom of screen | Tab, ↑↓←→ (hold to repeat), ^C, +, ◀▶ tab nav, ⌨ swap |
| **Shortcut bar** (tabs mode) | Bottom of screen | 1-9 session buttons (active highlighted), ⌨ swap |
| **Bubble tabs** | Top-right of bubble | Esc and Enter — always visible |
| **Single-finger swipe** | Terminal area | Scroll through terminal history |

### Input Bubble

- **Tap pill** to expand and open native keyboard (with dictation)
- **Enter** sends text; **Shift+Enter** adds newline
- **Esc / Enter tabs** on top-right of bubble — send keys without expanding
- **Minimize** (▼) collapses back to pill with text preview
- **Clear** empties the textarea
- Terminal is read-only on mobile — swipe to scroll, bubble to type

---

## Desktop Interface

| Feature | Details |
|---------|---------|
| **Text selection** (default) | Click and drag to select text, right-click to copy/paste |
| **Scroll mode** | Click mode icon in toolbar — enables scroll wheel through terminal history |
| **Copy** | Ctrl+Shift+C, or Ctrl+C when text is selected |
| **Paste** | Ctrl+Shift+V |
| **Floating toolbar** | Bottom-right: Mode icon, **+ New**, tab buttons (1-9), collapse arrow |
| **Collapsed toolbar** | Four mini buttons: mode icon, +, ◀ prev tab, ▶ next tab |

---

## Session Persistence

| Scenario | Sessions Survive? |
|----------|-------------------|
| Close browser | Yes |
| Switch devices | Yes |
| Lose WiFi | Yes |
| WSL/Windows reboot | Service auto-starts (run `cl` to relaunch projects) |

---

## After a Reboot

1. Open any Ubuntu terminal (service auto-starts)
2. Open `http://localhost:7681`
3. Run `cl` to launch projects

---

## Troubleshooting

```bash
cls                                       # Check status
sudo systemctl restart claude-terminal    # Restart service
tmux kill-session -t claude               # Clean restart (if stuck)
sudo journalctl -u claude-terminal -n 30  # View logs
```

---

## Your URLs

- **Local**: `http://localhost:7681`
- **Remote**: `https://_________________.ts.net`

Get your Tailscale URL: `tailscale serve status`

---

## Install / Upgrade / Uninstall

```bash
# Linux / WSL
git clone https://github.com/lhymes/claude-web-terminal.git
cd claude-web-terminal
sudo ./install-local.sh
sudo systemctl start claude-terminal
tailscale serve --bg 7681

# macOS (in testing)
git clone https://github.com/lhymes/claude-web-terminal.git
cd claude-web-terminal
brew install ttyd tmux fzf
./install-mac.sh
launchctl load ~/Library/LaunchAgents/com.claude-terminal.ttyd.plist
tailscale serve --bg 7681

# Upgrade (any platform — shows settings, offers to change)
cd claude-web-terminal && git pull
sudo ./install-local.sh    # Linux/WSL
./install-mac.sh           # macOS

# Uninstall (two-step confirmation, projects untouched)
sudo ./install-local.sh --uninstall    # Linux/WSL
./install-mac.sh --uninstall           # macOS
```

---

## Configuration

Settings are stored in `~/.config/claude-terminal/settings.conf`:
```bash
CLAUDE_CMD="claude"                    # Command to launch Claude Code
CLAUDE_PROJECTS_DIR="$HOME/projects"   # Where projects are stored
REMOTE_SUDO="no"                       # Passwordless sudo (yes/no)
REMOTE_SUDO_LOCKED="no"               # Lock sudo off permanently (yes/no)
```

Edit the file and run `source ~/.bashrc` to apply, or re-run `sudo ./install-local.sh` to change settings interactively. When sudo is locked off, upgrades skip the sudo prompt. Uninstall and reinstall to change a locked setting.

**Security:** Tailscale protects your terminal from outside access. Only devices on your personal Tailscale network can connect — nothing is exposed to the public internet.

**Remote sudo:** If enabled, sudo works without a password in the web terminal. Requires Tailscale VPN — never expose ttyd directly to the internet. Your device security is your last line of defense.
