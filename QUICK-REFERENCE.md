# Claude Code Web Terminal - Quick Reference

## Daily Workflow

### Starting Your Day
1. Open browser: `http://localhost:7681` (local) or your Tailscale URL (remote)
2. Type `cl` in the launcher tab
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
4. **Add to Home Screen** (Share menu)

### Using on Mobile
- **Tap numbered buttons** at top to switch sessions
- Use window 1 (launcher) to run `cl` for new projects
- Tap "ABC" for custom keyboard, long-press for iOS keyboard
- Use floating scroll arrows to browse terminal history
- Exit Claude with `/exit` if you need the shell

---

## Session Persistence

| Scenario | Sessions Survive? |
|----------|-------------------|
| Close browser | ✓ Yes |
| Switch devices | ✓ Yes |
| Lose WiFi | ✓ Yes |
| WSL/Windows reboot | ✓ Service auto-starts (run `cl` to relaunch projects) |

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

## First-Time Setup

```bash
# 1. Clone and install
git clone https://github.com/lhymes/claude-web-terminal.git
cd claude-web-terminal
sudo ./install-local.sh

# 2. Setup Tailscale (for remote access)
sudo tailscale up
tailscale serve --bg 7681

# 3. Start the service
sudo systemctl start claude-terminal

# 4. Open http://localhost:7681
```

---

## Configuration

Edit `~/.bashrc` to customize:
```bash
export CLAUDE_PROJECTS_DIR="$HOME/projects"
export CLAUDE_CMD="claude"  # Change to your alias if needed (e.g., ccc)
```
