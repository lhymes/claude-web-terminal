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
| Mobile | Tap numbered buttons in tab bar (top of screen) |
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
| **Tab bar** | Top of screen | Tap numbers to switch sessions. Tab 1 shows **+** to launch picker. |
| **Shortcut bar** | Bottom of screen | Esc, Tab, Enter, arrows, ^C, ^D, Ctrl toggle, keyboard toggle |
| **Scroll pill** | Right edge | Drag up/down to scroll terminal history. Speed scales with distance. |
| **Two-finger drag** | Terminal area | Scroll through terminal history |

### Keyboards

- **Tap terminal** to open iOS/Android keyboard (default)
- **Tap ABC/X button** to toggle between native and custom keyboard
- **Long-press ABC/X** to dismiss all keyboards

### Custom Keyboard Features

- Full QWERTY with dedicated number row
- **Shift** and **Ctrl** as sticky modifiers (auto-deactivate after next key)
- **Long-press** any letter for its symbol (hint shown on key)
- **#+=** and **123** pages for full punctuation access

---

## Desktop Interface

| Feature | Details |
|---------|---------|
| **Text selection** | Click and drag to select, right-click to copy/paste |
| **Copy** | Ctrl+Shift+C, or Ctrl+C when text is selected |
| **Paste** | Ctrl+Shift+V |
| **Floating toolbar** | Bottom-right: **+ New** button and clickable tab buttons (1-9) |

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
```

Edit the file and run `source ~/.bashrc` to apply, or re-run `sudo ./install-local.sh` to change settings interactively.

**Remote sudo:** If enabled, sudo works without a password in the web terminal. Requires Tailscale VPN — never expose ttyd directly to the internet. Your device security is your last line of defense.
