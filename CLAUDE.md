# Claude Code Web Terminal - Project Configuration

## Overview

Web-based terminal for accessing Claude Code sessions from any browser/device. Uses ttyd + tmux + Tailscale on WSL, with a custom mobile-optimized xterm.js frontend.

## Tech Stack

```yaml
Primary Languages: Bash (scripts/installer), HTML/CSS/JavaScript (frontend)
Terminal Server: ttyd (WebSocket-based terminal)
Multiplexer: tmux (session management, window switching)
Terminal Emulator: xterm.js 5.5.0 (browser-side)
Networking: Tailscale VPN (encrypted peer-to-peer)
Service Manager: systemd (service + healthcheck timer)
Target Platform: Ubuntu 20.04+ on WSL2
Testing: Manual (no automated test framework)
```

## Project Structure

```
claude-web-terminal/
├── html/
│   ├── index.html       # Custom ttyd frontend (xterm.js + touch UI)
│   ├── icon.svg         # App icon for PWA / home screen
│   └── manifest.json    # Web app manifest
├── install-local.sh     # Installer / upgrader / uninstaller
├── upgrade.sh           # Upgrade from Zellij version
├── README.md            # Main documentation
├── QUICK-REFERENCE.md   # Printable cheat sheet
├── LICENSE              # MIT
└── .gitignore
```

## Key Commands

```bash
# Install / upgrade (settings preserved on upgrade)
sudo ./install-local.sh

# Uninstall (two-step confirmation)
sudo ./install-local.sh --uninstall

# Start / restart the terminal service
sudo systemctl start claude-terminal
sudo systemctl restart claude-terminal

# Launch Claude in a project
cl              # Interactive project picker (fzf)
clp <project>   # Quick-launch specific project
cnew <project>  # New tmux window for project
cls             # List active sessions
tj              # Attach to tmux from another terminal
```

## Development Standards

### File Size Limits
- Maximum: 600 lines per file
- Current files are all well under this limit

### Shell Scripts
- Use `#!/bin/bash` shebang
- Quote all variables: `"$VAR"` not `$VAR`
- Use `set -e` for fail-fast where appropriate
- Prefer bash builtins over external commands
- Use `[[ ]]` over `[ ]` for conditionals

### HTML/JavaScript
- Vanilla JS only (no frameworks, no build step)
- Mobile-first responsive design
- Touch-friendly UI elements (minimum 44px tap targets)
- VS Code Dark theme (#1e1e1e background, #d4d4d4 text)
- Font stack: Cascadia Code, Fira Code, Consolas, monospace

### Security
- All network access through Tailscale VPN only
- No secrets stored in code (use environment variables)
- ttyd `--writable` flag is required but mitigated by VPN-only access
- No direct internet exposure

### Before Committing
- [ ] Shell scripts tested manually
- [ ] HTML renders correctly in mobile and desktop browsers
- [ ] README and QUICK-REFERENCE.md updated if behavior changed
- [ ] No secrets or credentials in committed files
- [ ] User settings not broken by installer changes

## Architecture

```
Browser (any device)
  ↓ HTTPS
Tailscale VPN tunnel
  ↓
ttyd server (port 7681, serves html/index.html)
  ↓ WebSocket
tmux session (multiplexed windows)
  ↓
Claude Code CLI (per-project windows)
```

## Known Constraints

- Sessions survive disconnects; service auto-starts after reboot but tmux sessions are lost (run `cl` to relaunch)
- ttyd must be built from source on some systems
- Tailscale must be installed on both host and client device
- WSL2 required (WSL1 not supported)

## Critical Files

| File | Purpose | Edit Carefully |
|------|---------|----------------|
| `html/index.html` | Frontend UI, touch toolbar, WebSocket connection | Yes - affects all users |
| `html/icon.svg` | PWA app icon | Yes - visible on home screens |
| `html/manifest.json` | Web app manifest for PWA install | Yes - affects home screen behavior |
| `install-local.sh` | Installer, upgrader, uninstaller | Yes - modifies system files and user config |
| `README.md` | Primary user documentation | Keep synchronized with actual behavior |
| `QUICK-REFERENCE.md` | Quick reference card | Keep synchronized with README |
