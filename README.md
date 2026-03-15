# ServerMGR - Automated Server Management

<div align="center">

```
  ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗ ███╗   ███╗ ██████╗ ██████╗
  ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗████╗ ████║██╔════╝ ██╔══██╗
  ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝██╔████╔██║██║  ███╗██████╔╝
  ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║██╔══██╗
  ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝██║  ██║
  ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝
```

**A beautiful, menu-driven bash script to automate Linux server tasks.**

[![License: MIT](https://img.shields.io/badge/License-MIT-cyan.svg)](LICENSE)
![Platform](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu%20%7C%20Fedora-blue)
![Shell](https://img.shields.io/badge/Shell-Bash-green)

</div>

---

## ⚡ Quick Start

```bash
bash <(curl -Ls https://raw.githubusercontent.com/pasinduljay/server-mgr/main/server-mgr.sh)
```

> **No `sudo` needed on the outside.** The script detects if it's not running as root and automatically re-elevates itself via `sudo`. You'll be prompted for your password once.

---

## 📋 Features

### 🖥️ Main Menu
| Option | Description |
|--------|-------------|
| `1` | Odoo Management |
| `2` | Docker Install (Debian/Ubuntu) |
| `3` | Docker Install (Fedora/RHEL) |

### 🟣 Odoo Management
| Option | Description |
|--------|-------------|
| `1` | **Create Privileged User** — `sudo` without password (NOPASSWD) |
| `2` | **Create Standard Sudo User** — `sudo` with password |
| `3` | **Delete User** |
| `4` | **Install Odoo (Legacy)** — Bare-metal install from official packages (v16–19) |
| `5` | **Install Odoo (Docker)** — Full Docker stack wizard |
| `6` | **Manage Existing Odoo Docker Stack** — Start/stop/restart/logs/toggle dashboard |
| `7` | **UFW Firewall** — Enable, rules, custom ports |

### 🐳 Odoo Docker Wizard
The wizard walks you through:
1. **Odoo version** (16, 17, 18, 19)
2. **Domain names** for Odoo and the Traefik dashboard
3. **Traefik dashboard** enable/disable
4. **SSL mode** selection:
   - **Cloudflare Origin Certificate** — paste your cert + key, Cloudflare handles TLS termination
   - **Let's Encrypt (ACME)** — provide email, Traefik auto-obtains and renews certs

---

## 📁 Repository Structure

```
server-mgr/
├── server-mgr.sh          # Main automation script
└── app/                   # Odoo Docker stack template
    ├── docker-compose.yml          # Cloudflare SSL variant (auto-generated on deploy)
    ├── config/
    │   └── odoo.conf               # Odoo configuration
    ├── custom-addons/              # Mount point for custom Odoo modules
    ├── traefik/
    │   ├── dynamic/
    │   │   ├── certificates.yml    # Cloudflare cert config
    │   │   └── tls-options.yml     # TLS options for Let's Encrypt
    │   ├── certs/                  # Cloudflare origin certs (NOT committed)
    │   ├── acme/                   # Let's Encrypt storage (NOT committed)
    │   └── logs/                   # Access logs
    └── odoo_pg_pass                # Auto-generated at deploy time (NOT committed)
```

---

## 🔒 SSL / TLS Modes

### Cloudflare Origin Certificate
- You provide Cloudflare-issued Origin Certificate and Key (PEM format)
- Traefik serves the cert directly; Cloudflare proxies/encrypts traffic externally
- No domain validation required (works with `Full (strict)` mode in Cloudflare)

### Let's Encrypt (ACME)
- Provide your email; Traefik handles cert issuance + renewal automatically
- Domain must resolve publicly to the server IP
- HTTP challenge used (port 80 must be accessible)

---

## 🔥 UFW Firewall Default Rules
When enabled via the script:
- Default: `deny incoming`, `allow outgoing`
- Allowed ports: `22` (SSH), `80` (HTTP), `443` (HTTPS), `8069` (Odoo)

---

## 🧰 Docker Stack Details

The deployed Odoo stack includes:
- **Traefik** — Reverse proxy with automatic TLS
- **Odoo** — Selected version via official Docker image
- **PostgreSQL 15** — Database with auto-generated password

All services use Docker networks for isolation. No ports other than 80/443 are exposed publicly.

---

## ⚙️ Requirements

| Component | Minimum |
|-----------|---------|
| OS | Debian 10+ / Ubuntu 20.04+ / Fedora 36+ |
| RAM | 2 GB (4 GB recommended for Odoo) |
| Disk | 10 GB free |
| Docker | Installed (or use the script to install it) |

---

## 📜 License

MIT — see [LICENSE](LICENSE)

---

*Built with ❤️ to automate the boring server stuff.*
