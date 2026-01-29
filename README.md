# Claude Code Web Terminal

Access your Claude Code sessions from any browser — phone, tablet, or laptop. Sessions persist across devices and survive disconnects.

## Features

- 🌐 **Web-based** — Works from any browser, no app install needed
- 📱 **Mobile-friendly** — Touch-optimized, tap tabs to switch sessions
- 🔒 **Secure** — All traffic encrypted through Tailscale
- 💾 **Persistent** — Sessions survive disconnects
- 🚀 **Multi-project** — Run multiple Claude sessions in tabs

## Prerequisites

Complete these steps **before** running the installer.

### 1. Windows Subsystem for Linux (WSL)

You need Ubuntu running in WSL (20.04, 22.04, or 24.04). If you don't have it yet:

```powershell
# Run in PowerShell as Administrator
wsl --install -d Ubuntu
```

Restart your machine when prompted, then open Ubuntu from the Start menu to finish setup.

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

### 3. Projects folder

All your projects must live in `~/projects` inside WSL. The launcher scans this folder to find your projects.

```bash
mkdir -p ~/projects
```

Move or clone your project repositories into this folder:

```bash
cd ~/projects
git clone https://github.com/your-org/your-repo.git
```

### 4. Tailscale setup (all devices)

Tailscale creates a private encrypted network between your devices. You need it installed and authenticated on **every device** you want to access the terminal from.

**On your WSL host (required):**

```bash
# Install Tailscale in WSL
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate — this opens a browser link to sign in
sudo tailscale up
```

**On every other device (phone, tablet, laptop, etc.):**

1. Download [Tailscale](https://tailscale.com/download) for your platform
2. Install and open the app
3. Sign in with the **same account** you used in WSL
4. Verify the device appears in your tailnet (`tailscale status` in WSL)

All devices must be on the same Tailscale account to reach each other.

## Install

Once all prerequisites are complete:

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

# Expose the terminal over Tailscale
tailscale serve --bg 7681

# Start
claude-terminal-start
```

Open `http://localhost:7681` (local) or your Tailscale URL (remote) — you're ready!

## Configuration

The default settings expect your projects in `~/projects` and use `claude` as the launch command. To change these, edit `~/.bashrc`:

```bash
export CLAUDE_PROJECTS_DIR="$HOME/projects"  # Default: ~/projects
export CLAUDE_CMD="claude"                    # Change to your alias if needed (e.g., ccc)
```

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
