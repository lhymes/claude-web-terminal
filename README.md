# Claude Code Web Terminal

Access your Claude Code sessions from any browser — phone, tablet, or laptop. Sessions persist across devices and survive disconnects.

## Features

- 🌐 **Web-based** — Works from any browser, no app install needed
- 📱 **Mobile-friendly** — Touch-optimized, tap tabs to switch sessions
- 🔒 **Secure** — All traffic encrypted through Tailscale
- 💾 **Persistent** — Sessions survive disconnects
- 🚀 **Multi-project** — Run multiple Claude sessions in tabs

## Requirements

- Ubuntu WSL (20.04, 22.04, or 24.04)
- [Tailscale](https://tailscale.com) account (free)
- Claude Code installed
- sudo access

## Quick Install

```bash
# Extract
tar -xzf claude-terminal-setup.tar.gz
cd claude-terminal-setup

# Install base
sudo ./install.sh

# Install launcher tools
cd extras
sudo ./install-extras.sh
source ~/.bashrc

# Setup Tailscale (if not already done)
sudo tailscale up
tailscale serve --bg 7681

# Start
claude-terminal-start
```

Open `http://localhost:7681` — you're ready!

## Configuration

Edit `~/.bashrc` to customize:

```bash
export CLAUDE_PROJECTS_DIR="$HOME/projects"  # Your projects folder
export CLAUDE_CMD="ccc"                       # Your Claude command
```

Options for `CLAUDE_CMD`: `claude`, `ccc`, or any alias you use.

## Daily Usage

### Launch Projects

1. Open `http://localhost:7681`
2. You land in the **launcher** tab
3. Type `cl`
4. Select projects (Tab for multi-select)
5. Press Enter

### Switch Between Sessions

- **Keyboard:** `Alt+1` through `Alt+9`
- **Touch/Mouse:** Tap the tab bar at the bottom

### Commands

| Command | Description |
|---------|-------------|
| `cl` | Interactive project picker |
| `clp ProjectName` | Quick-launch specific project |
| `cnew ProjectName` | Create new project + launch |
| `cls` | Check service status |
| `zj` | Attach to Zellij from terminal |

## Mobile Setup

1. Install **Tailscale** app on your phone
2. Sign in to your tailnet
3. Open your terminal URL (get it with `tailscale serve status`)
4. Safari: Share → Add to Home Screen
5. Tap the icon to launch — works like a native app

### Mobile Tips

- **Tap tabs** at the bottom to switch sessions
- Keep the **launcher** tab for running `cl`
- Exit Claude with `/exit` when you need shell access

## Session Persistence

| Event | Sessions Survive? |
|-------|-------------------|
| Close browser | ✓ Yes |
| Switch devices | ✓ Yes |
| Network disconnect | ✓ Yes |
| WSL/Windows reboot | ✗ No |

After a reboot, just open the browser and run `cl` to relaunch.

## Troubleshooting

### Service won't start
```bash
cls                                    # Check status
sudo journalctl -u claude-terminal -n 30  # View logs
```

### Stale session
```bash
zellij delete-session claude
sudo systemctl restart claude-terminal
```

### Port in use
```bash
sudo lsof -i :7681                    # Find what's using it
sudo kill <PID>                        # Kill it
sudo systemctl restart claude-terminal
```

### Can't connect remotely
```bash
tailscale status      # Is Tailscale running?
tailscale serve status  # Is serve configured?
```

## Architecture

```
Browser (any device)
       ↓
Tailscale (encrypted)
       ↓
ttyd (web terminal, port 7681)
       ↓
Zellij (session "claude")
       ↓
Multiple tabs with Claude Code
```

All devices connect to the same Zellij session — you see identical state everywhere.

## Uninstall

```bash
sudo ./uninstall.sh
```

## Files

```
claude-terminal-setup/
├── install.sh           # Main installer
├── uninstall.sh         # Removal script
├── QUICK-REFERENCE.md   # Printable cheat sheet
├── README.md            # This file
└── extras/
    └── install-extras.sh  # Launcher tools
```

## Author

Created by **Larry Hymes** — [Hymes Consulting](https://www.hymesconsulting.com)

## Credits

- [ttyd](https://github.com/tsl0922/ttyd) — Terminal over web
- [Zellij](https://zellij.dev/) — Terminal multiplexer
- [Tailscale](https://tailscale.com/) — Secure networking
- [fzf](https://github.com/junegunn/fzf) — Fuzzy finder

## License

MIT — Use it, share it, modify it.
