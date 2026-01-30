# Claude Code Web Terminal

Access your Claude Code sessions from any browser — phone, tablet, or laptop. Sessions persist across devices and survive disconnects.

## Features

- **Web-based** — Works from any browser, no app install needed
- **Mobile-friendly** — Custom keyboard, tab bar, and touch-optimized UI
- **Secure** — All traffic encrypted through Tailscale VPN
- **Persistent** — Sessions survive disconnects and auto-recover after reboot
- **Multi-project** — Run multiple Claude sessions in tmux windows

## Prerequisites

Complete these steps **before** running the installer.

### 1. Windows Subsystem for Linux (WSL)

You need Ubuntu running in WSL2 (20.04, 22.04, or 24.04). If you don't have it yet:

```powershell
# Run in PowerShell as Administrator
wsl --install -d Ubuntu
```

Restart your machine when prompted, then open Ubuntu from the Start menu to finish setup.

Verify systemd is enabled in `/etc/wsl.conf`:

```ini
[boot]
systemd=true

[user]
default=your-username
```

### 2. Claude Code in WSL

Install Claude Code inside your WSL Ubuntu terminal:

```bash
# Install Node.js (if not already installed)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Claude Code
npm install -g @anthropic-ai/claude-code
```

Run `claude` once to authenticate and confirm it's working before proceeding.

### 3. Dependencies

```bash
sudo apt-get install -y tmux fzf
```

ttyd must also be installed. Check if it's available:

```bash
ttyd --version   # Need 1.7.4+
```

If not installed, build from source or install from your package manager. See [ttyd releases](https://github.com/tsl0922/ttyd/releases).

### 4. Projects folder

The launcher scans `~/projects` to find your projects:

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/your-org/your-repo.git
```

### 5. Tailscale (for remote access)

Tailscale creates a private encrypted network between your devices.

**On your WSL host:**

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**On every other device (phone, tablet, laptop):**

1. Download [Tailscale](https://tailscale.com/download) for your platform
2. Sign in with the **same account** you used in WSL
3. Verify connectivity: `tailscale status`

## Install

```bash
# Clone the repo
git clone https://github.com/lhymes/claude-web-terminal.git
cd claude-web-terminal

# Run the installer (sets up tmux config, systemd service, launcher scripts, healthcheck)
sudo ./install-local.sh

# Expose over Tailscale (for remote access)
tailscale serve --bg 7681

# Start the service
sudo systemctl start claude-terminal
```

Open `http://localhost:7681` (local) or your Tailscale URL (remote).

## Configuration

The launcher scripts use environment variables. Add to `~/.bashrc`:

```bash
export CLAUDE_PROJECTS_DIR="$HOME/projects"  # Default: ~/projects
export CLAUDE_CMD="claude"                    # Change if you use an alias
```

## Daily Usage

### Launch Projects

1. Open `http://localhost:7681` (or your Tailscale URL)
2. Type `cl` in the terminal
3. Select projects with arrow keys, **Tab** to multi-select, **Enter** to launch

### Switch Between Sessions

- **Keyboard:** `Alt+1` through `Alt+9`
- **Mobile:** Tap numbered buttons in the tab bar at the top of the screen
- **Desktop:** Click tmux tabs at the bottom of the terminal

### Commands

| Command | Description |
|---------|-------------|
| `cl` | Interactive project picker (fzf) |
| `clp <project>` | Quick-launch specific project |
| `cnew <project>` | Create new project + launch |
| `cls` | Check service status and active sessions |
| `tj` | Attach to tmux session from another terminal |

## Mobile Setup

1. Install **Tailscale** app on your phone
2. Sign in to your tailnet
3. Open your terminal URL (get it with `tailscale serve status`)
4. Safari: Share > Add to Home Screen
5. Tap the icon to launch — works like a native app

### Mobile Interface

On mobile screens (<769px), the interface provides:

**Tab bar (top):** Numbered buttons 1-9 for switching tmux windows. Tap to switch — no keyboard invoked.

**Shortcut bar (bottom):** Quick access to Esc, Tab, ^C, ^D, arrow keys, Ctrl toggle, and keyboard toggle.

**Custom QWERTY keyboard:** Tap "ABC" to open a compact on-screen keyboard with:
- Full QWERTY layout with number row
- Shift and Ctrl sticky modifiers
- Long-press any letter for its symbol (shown as hints)
- Symbol layouts (#+= and 123 modes)
- Long-press "ABC" to switch to the native iOS keyboard instead

**Scroll buttons:** Floating translucent arrows on the right edge for scrolling terminal history.

All mobile UI elements are hidden on desktop browsers.

### Mobile Tips

- **Tap tab numbers** at the top to switch sessions
- Keep the **launcher** tab (window 1) for running `cl`
- Use the shortcut bar and custom keyboard instead of the iOS keyboard
- Long-press "ABC" if you need the native iOS keyboard (e.g., for dictation)
- Exit Claude with `/exit` when you need shell access

## Session Persistence

| Event | Sessions Survive? |
|-------|-------------------|
| Close browser | Yes |
| Switch devices | Yes |
| Network disconnect | Yes |
| WSL/Windows reboot | Service auto-starts; run `cl` to relaunch projects |

The systemd service auto-starts ttyd + tmux on boot. A healthcheck timer runs every 30 seconds to restart the service if ttyd dies.

## Upgrading from Zellij Version

If you previously installed the Zellij-based version:

```bash
# See what's installed (no changes)
sudo ./upgrade.sh --detect

# Upgrade: removes old Zellij components, installs new tmux version
sudo ./upgrade.sh

# Or just remove everything without reinstalling
sudo ./upgrade.sh --clean
```

The upgrade preserves your projects in `~/projects`.

## Troubleshooting

### Service won't start
```bash
cls                                       # Check status
sudo journalctl -u claude-terminal -n 30  # View logs
```

### Stale session
```bash
tmux kill-session -t claude
sudo systemctl restart claude-terminal
```

### Port in use
```bash
sudo lsof -i :7681
sudo kill <PID>
sudo systemctl restart claude-terminal
```

### Can't connect remotely
```bash
tailscale status        # Is Tailscale running?
tailscale serve status  # Is serve configured?
```

## Architecture

```
Browser (any device)
       |
Tailscale VPN (encrypted)
       |
ttyd (web terminal server, port 7681)
       |
tmux session "claude" (multiplexed windows)
       |
Claude Code CLI (per-project windows)
```

All devices connect to the same tmux session — you see identical state everywhere.

## Files

```
claude-web-terminal/
├── html/index.html      # Custom ttyd frontend (xterm.js + custom keyboard + tab bar)
├── install-local.sh     # Installer (tmux config, systemd service, launcher scripts, healthcheck)
├── upgrade.sh           # Upgrade from Zellij or reinstall
├── README.md            # This file
├── QUICK-REFERENCE.md   # Printable cheat sheet
├── LICENSE              # MIT
└── .github/workflows/   # CI
```

## Author

Created by **Larry Hymes** — [Hymes Consulting](https://www.hymesconsulting.com)

## Credits

- [ttyd](https://github.com/tsl0922/ttyd) — Terminal over web
- [tmux](https://github.com/tmux/tmux) — Terminal multiplexer
- [xterm.js](https://xtermjs.org/) — Browser-side terminal emulator
- [Tailscale](https://tailscale.com/) — Secure networking
- [fzf](https://github.com/junegunn/fzf) — Fuzzy finder

## License

MIT
