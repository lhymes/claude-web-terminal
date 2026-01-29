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
| Mouse/Touch | Click tab names at bottom |

### Commands
| Command | What It Does |
|---------|--------------|
| `cl` | Interactive project picker |
| `clp ProjectName` | Quick-launch one project |
| `cnew ProjectName` | Create + launch new project |
| `cls` | Check service status |

---

## Mobile Access

### Setup (One Time)
1. Install **Tailscale app** on your phone
2. Sign in to your tailnet
3. Open your terminal URL in Safari/Chrome
4. **Add to Home Screen** (Share menu)

### Using on Mobile
- **Tap tabs** at bottom to switch sessions
- Use `launcher` tab to run `cl` for new projects
- Exit Claude with `/exit` if you need the shell

---

## Session Persistence

| Scenario | Sessions Survive? |
|----------|-------------------|
| Close browser | ✓ Yes |
| Switch devices | ✓ Yes |
| Lose WiFi | ✓ Yes |
| WSL/Windows reboot | ✗ No (run `cl` to relaunch) |

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
zellij delete-session claude
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
# 1. Extract and install
tar -xzf claude-terminal-setup.tar.gz
cd claude-terminal-setup
sudo ./install.sh

# 2. Install launcher tools
cd extras && sudo ./install-extras.sh
source ~/.bashrc

# 3. Setup Tailscale
sudo tailscale up
tailscale serve --bg 7681

# 4. Start terminal
claude-terminal-start

# 5. Open http://localhost:7681
```

---

## Configuration

Edit `~/.bashrc` to customize:
```bash
export CLAUDE_PROJECTS_DIR="$HOME/projects"
export CLAUDE_CMD="claude"  # Change to your alias if needed (e.g., ccc)
```
