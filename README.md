# Claude Code Web Terminal

Access your Claude Code sessions from any browser — phone, tablet, or laptop. Sessions persist across devices and survive disconnects.

## Features

- **Web-based** — Works from any browser, no app install needed
- **Mobile-optimized** — iOS keyboard integration, touch toolbar, tab bar, scroll pill
- **Desktop-friendly** — Text selection, copy/paste, floating toolbar with session launcher
- **Installable** — Add to Home Screen for a native app experience (PWA)
- **Secure** — All traffic encrypted through Tailscale VPN
- **Persistent** — Sessions survive disconnects and auto-recover after reboot
- **Multi-project** — Run multiple Claude sessions in tmux windows
- **Upgrade-safe** — User settings preserved across upgrades

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

### 4. Tailscale (for remote access)

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

# Run the installer
sudo ./install-local.sh

# Expose over Tailscale (for remote access)
tailscale serve --bg 7681

# Start the service
sudo systemctl start claude-terminal
```

The installer will prompt you to configure:
- **Claude command** — The command to launch Claude Code (default: `claude`). Use this if you have a custom alias.
- **Projects directory** — Where your projects live (default: `~/projects`).
- **Remote sudo** — Optionally enable passwordless sudo for the web terminal (requires Tailscale VPN).

Settings are saved to `~/.config/claude-terminal/settings.conf` and sourced via `~/.bashrc`.

Open `http://localhost:7681` (local) or your Tailscale URL (remote).

## Upgrading

Pull the latest code and re-run the installer. Your settings are preserved automatically:

```bash
cd claude-web-terminal
git pull
sudo ./install-local.sh
sudo systemctl restart claude-terminal
```

## Uninstalling

```bash
sudo ./install-local.sh --uninstall
```

This prompts for two confirmations before removing services, scripts, configuration, and shell aliases. Your project files are not touched.

## Configuration

User settings are stored in `~/.config/claude-terminal/settings.conf`:

```bash
CLAUDE_CMD="claude"                    # Command to launch Claude Code
CLAUDE_PROJECTS_DIR="$HOME/projects"   # Where projects are stored
REMOTE_SUDO="no"                       # Passwordless sudo (yes/no)
```

Edit this file directly to change settings. Changes take effect on next shell login (or run `source ~/.bashrc`).

To enable or disable remote sudo after installation:

```bash
# Enable
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/claude-terminal
sudo chmod 440 /etc/sudoers.d/claude-terminal

# Disable
sudo rm /etc/sudoers.d/claude-terminal
```

**Warning:** Remote sudo means anyone with access to your terminal session has root access. Only use this with Tailscale VPN — never expose ttyd directly to the internet.

## Daily Usage

### Launch Projects

1. Open `http://localhost:7681` (or your Tailscale URL)
2. Type `cl` in the terminal
3. Select projects with arrow keys, **Tab** to multi-select, **Enter** to launch

### Switch Between Sessions

- **Keyboard:** `Alt+1` through `Alt+9`
- **Mobile:** Tap numbered buttons in the tab bar at the top of the screen
- **Desktop:** Click tab buttons in the floating toolbar (bottom-right corner)

### New Session (Desktop)

Click the **+ New** button in the desktop toolbar to launch the project picker. This switches to tmux window 1, clears the screen, and runs `cl`. If window 1 was closed, it is recreated automatically.

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
4. Safari: Share > Add to Home Screen (launches as a standalone app with custom icon)

### Mobile Interface

On mobile screens (<769px), the interface provides:

**Tab bar (top):** Buttons for switching tmux windows. Tab 1 is context-aware: shows **+** when you're on it (tap to launch the project picker), shows **1** when you're on another tab (tap to navigate back).

**Shortcut bar (bottom):** Quick access to Esc, Tab, Enter, left/right arrows, ^C, ^D, Ctrl toggle, and keyboard toggle.

**iOS keyboard (default):** Tapping the terminal opens the native iOS keyboard. The ABC/X button cycles between keyboards:
- Tap to switch between iOS keyboard and custom keyboard
- Long-press to dismiss all keyboards

**Custom QWERTY keyboard:** A compact on-screen keyboard with:
- Full QWERTY layout with number row
- Shift and Ctrl sticky modifiers
- Long-press any letter for its symbol (shown as hints)
- Symbol layouts (#+= and 123 modes)

**Scroll pill:** A touch-drag control on the right edge for scrolling terminal history. Drag up to scroll up, drag down to scroll down. Speed increases the further you drag from center.

Mobile UI elements are hidden on desktop browsers. Desktop gets its own floating toolbar instead (see below).

### Desktop Interface

On desktop screens (769px+), the interface provides:

**Native text selection and copy/paste:** Mouse mode is disabled in xterm.js so you can select text, right-click to copy/paste, and use Ctrl+Shift+C/V.

**Floating toolbar (bottom-right):** A compact overlay with:
- **+ New** button to launch the project picker (creates/switches to window 1, clears, runs `cl`)
- Clickable tab buttons (1-9) to switch tmux windows
- Active tab is highlighted

### Mobile Tips

- **Tap tab numbers** at the top to switch sessions
- Tap **+** on tab 1 to pick a new project
- The iOS keyboard stays open while using shortcut bar buttons
- Use the scroll pill on the right edge to browse history
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
├── html/
│   ├── index.html       # Custom ttyd frontend (xterm.js + touch UI)
│   ├── icon.svg         # App icon for PWA / home screen
│   └── manifest.json    # Web app manifest
├── install-local.sh     # Installer / upgrader / uninstaller
├── upgrade.sh           # Upgrade from Zellij version
├── README.md            # This file
├── QUICK-REFERENCE.md   # Printable cheat sheet
└── LICENSE              # MIT
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
