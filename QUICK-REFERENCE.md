# Claude Code Web Terminal - Quick Reference

## Daily Workflow

### Starting Your Day
1. Open browser: `http://localhost:7681` (local) or your Tailscale URL (remote)
2. Type `cl` in the launcher tab (or tap **+** on mobile)
3. Select projects with arrow keys, **Tab** to multi-select, **Enter** to launch

### Switching Sessions
| Method | How |
|--------|-----|
| Keyboard | `Alt+1` through `Alt+9` |
| Mobile | Tap numbered buttons in tab bar (top of screen) |
| Desktop | Click tmux tabs at bottom of terminal |

### Commands
| Command | What It Does |
|---------|--------------|
| `cl` | Interactive project picker |
| `clp ProjectName` | Quick-launch one project |
| `cnew ProjectName` | Create + launch new project |
| `cls` | Check service status |
| `tj` | Attach to tmux from another terminal |

---

## Mobile Access

### Setup (One Time)
1. Install **Tailscale app** on your phone
2. Sign in to your tailnet
3. Open your terminal URL in Safari/Chrome
4. **Add to Home Screen** (Share menu) — launches as a standalone app

### Using on Mobile
- **Tap tab numbers** at top to switch sessions
- **Tap +** on tab 1 to launch the project picker
- Tapping the terminal opens the **iOS keyboard** by default
- Tap **X** to switch to custom keyboard, long-press **X** to dismiss all keyboards
- Use the **scroll pill** on the right edge to browse terminal history (drag up/down)
- **Shortcut bar** has Esc, Tab, Enter, left/right arrows, ^C, ^D, Ctrl
- Shortcut bar buttons work without dismissing the iOS keyboard
- Exit Claude with `/exit` if you need the shell

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
# Check status
cls

# Restart service
sudo systemctl restart claude-terminal

# Clean restart (if stuck)
tmux kill-session -t claude
sudo systemctl restart claude-terminal

# View logs
sudo journalctl -u claude-terminal -n 30
```

---

## Your URLs

- **Local**: `http://localhost:7681`
- **Remote**: `https://_________________.ts.net`

Get your Tailscale URL: `tailscale serve status`

---

## Install / Upgrade / Uninstall

```bash
# First-time install
git clone https://github.com/lhymes/claude-web-terminal.git
cd claude-web-terminal
sudo ./install-local.sh
tailscale serve --bg 7681
sudo systemctl start claude-terminal

# Upgrade (settings preserved)
cd claude-web-terminal
git pull
sudo ./install-local.sh
sudo systemctl restart claude-terminal

# Uninstall (two-step confirmation, projects untouched)
sudo ./install-local.sh --uninstall
```

---

## Configuration

Settings are stored in `~/.config/claude-terminal/settings.conf`:
```bash
CLAUDE_CMD="claude"                    # Command to launch Claude Code
CLAUDE_PROJECTS_DIR="$HOME/projects"   # Where projects are stored
```

Edit the file and run `source ~/.bashrc` to apply changes.
