#!/bin/bash
# =============================================================================
#  ServerMGR – Automated Server Management Script
#  Author : pasinduljay
#  Repo   : https://github.com/pasinduljay/server-mgr
#  Usage  : sudo bash <(curl -Ls https://raw.githubusercontent.com/pasinduljay/server-mgr/main/server-mgr.sh)
# =============================================================================
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS – Sub-repo registry
# Add new application repos here as the project grows.
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_VERSION="1.0.0"

# Main manager repo
SERVER_MGR_REPO="https://github.com/pasinduljay/server-mgr"
SERVER_MGR_RAW="https://raw.githubusercontent.com/pasinduljay/server-mgr/main"

# Application sub-repos (clone URL → used at deploy time)
ODOO_DOCKER_REPO="https://github.com/pasinduljay/odoo-docker"
# WORDPRESS_DOCKER_REPO="https://github.com/pasinduljay/wordpress-docker"
# N8N_DOCKER_REPO="https://github.com/pasinduljay/n8n-docker"

# Raw URL of THIS script (used for self-download when auto-elevating)
SCRIPT_URL="https://raw.githubusercontent.com/pasinduljay/server-mgr/main/server-mgr.sh"

DEFAULT_INSTALL_DIR="/opt/odoo"

# ─────────────────────────────────────────────────────────────────────────────
# COLOURS & STYLES
# ─────────────────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BBLUE='\033[1;34m'
BMAGENTA='\033[1;35m'
BCYAN='\033[1;36m'
BWHITE='\033[1;37m'

BG_DARK='\033[48;5;234m'
BG_BLUE='\033[48;5;17m'
BG_CYAN='\033[48;5;23m'

# ─────────────────────────────────────────────────────────────────────────────
# HELPER – print utilities
# ─────────────────────────────────────────────────────────────────────────────
print_line() {
    echo -e "${DIM}${CYAN}$(printf '─%.0s' {1..70})${RESET}"
}

print_double_line() {
    echo -e "${CYAN}$(printf '═%.0s' {1..70})${RESET}"
}

ok()    { echo -e "  ${BGREEN}✓${RESET}  $*"; }
warn()  { echo -e "  ${BYELLOW}⚠${RESET}  $*"; }
err()   { echo -e "  ${BRED}✗${RESET}  $*"; }
info()  { echo -e "  ${BCYAN}ℹ${RESET}  $*"; }
step()  { echo -e "  ${BBLUE}⚙${RESET}  ${BOLD}$*${RESET}"; }

ask() {
    # ask <var_name> <prompt> [default]
    local __var="$1" __prompt="$2" __default="${3:-}"
    if [[ -n "$__default" ]]; then
        echo -ne "  ${BYELLOW}?${RESET}  ${BOLD}${__prompt}${RESET} ${DIM}[${__default}]${RESET}: "
    else
        echo -ne "  ${BYELLOW}?${RESET}  ${BOLD}${__prompt}${RESET}: "
    fi
    read -r __input
    if [[ -z "$__input" && -n "$__default" ]]; then
        printf -v "$__var" '%s' "$__default"
    else
        printf -v "$__var" '%s' "$__input"
    fi
}

ask_secret() {
    local __var="$1" __prompt="$2"
    echo -ne "  ${BYELLOW}?${RESET}  ${BOLD}${__prompt}${RESET}: "
    read -rs __input
    echo
    printf -v "$__var" '%s' "$__input"
}

confirm() {
    # confirm <prompt>  →  returns 0 (yes) or 1 (no)
    echo -ne "  ${BYELLOW}?${RESET}  ${BOLD}$*${RESET} ${DIM}[y/N]${RESET}: "
    read -r _ans
    [[ "$_ans" =~ ^[Yy]$ ]]
}

spinner() {
    local pid=$1 msg="${2:-Working…}"
    local sp='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % ${#sp} ))
        printf "\r  ${BCYAN}${sp:$i:1}${RESET}  ${msg}"
        sleep 0.1
    done
    printf "\r  ${BGREEN}✓${RESET}  ${msg}\n"
}

run_quietly() {
    local msg="$1"; shift
    "$@" &>/tmp/smgr_last_cmd.log &
    spinner $! "$msg"
    wait $! || { err "Command failed. Log:"; cat /tmp/smgr_last_cmd.log; return 1; }
}

pause() {
    echo
    echo -ne "  ${DIM}Press Enter to continue…${RESET}"
    read -r
}

clear_screen() { clear; }

# ─────────────────────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────────────────────
print_banner() {
    clear_screen
    echo
    echo -e "${BCYAN}$(cat <<'ASCIIART'
  ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗ ███╗   ███╗ ██████╗ ██████╗
  ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗████╗ ████║██╔════╝ ██╔══██╗
  ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝██╔████╔██║██║  ███╗██████╔╝
  ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║██╔══██╗
  ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝██║  ██║
  ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝
ASCIIART
)${RESET}"
    print_double_line
    echo -e "  ${BWHITE}Automated Server Management${RESET}  ${DIM}v${SCRIPT_VERSION}${RESET}  ${DIM}|${RESET}  ${DIM}$(date '+%Y-%m-%d %H:%M')${RESET}"
    echo -e "  ${DIM}Running as: ${BWHITE}$(whoami)${RESET}  ${DIM}|  Host: ${BWHITE}$(hostname)${RESET}"
    print_double_line
    echo
}

# ─────────────────────────────────────────────────────────────────────────────
# PRIVILEGE CHECK + AUTO-ELEVATE
# Why not "sudo bash <(curl ...)"?
#   sudo drops the parent shell's file descriptors, so /dev/fd/63 (the process
#   substitution fd) becomes inaccessible → "No such file or directory".
# Fix: run as a normal user with  bash <(curl ...)  and let the script elevate
#   itself by saving to /tmp and re-exec'ing under sudo from a real file.
# ─────────────────────────────────────────────────────────────────────────────
check_privileges() {
    # Already root – nothing to do
    [[ $EUID -eq 0 ]] && return 0

    echo
    echo -e "  ${BYELLOW}⚠${RESET}  ${BOLD}Root privileges required. Elevating with sudo…${RESET}"
    echo

    local SELF="${BASH_SOURCE[0]:-$0}"

    # If we're running from a file descriptor (process substitution / pipe),
    # BASH_SOURCE will be something like /dev/fd/63 or /proc/.../fd/X.
    # We can't sudo a fd, so download ourselves to a real temp file first.
    if [[ "$SELF" == /dev/fd/* || "$SELF" == /proc/*/fd/* || "$SELF" == /dev/stdin || ! -f "$SELF" ]]; then
        local TMPSCRIPT
        TMPSCRIPT=$(mktemp /tmp/server-mgr-XXXXXX.sh)
        if command -v curl &>/dev/null; then
            curl -fsSL "$SCRIPT_URL" -o "$TMPSCRIPT" 2>/dev/null
        elif command -v wget &>/dev/null; then
            wget -qO "$TMPSCRIPT" "$SCRIPT_URL" 2>/dev/null
        else
            echo -e "  ${BRED}✗${RESET}  Neither curl nor wget found. Cannot auto-elevate."
            echo -e "       Please run:  ${BCYAN}sudo bash /path/to/server-mgr.sh${RESET}"
            exit 1
        fi
        chmod 755 "$TMPSCRIPT"
        exec sudo bash "$TMPSCRIPT"
        exit $?
    fi

    # Running from a real file – can exec sudo directly
    exec sudo bash "$SELF"
    exit $?
}

# Elevate all subsequent commands to root if running via sudo
maybe_sudo() {
    if [[ $EUID -ne 0 ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# DETECT OS
# ─────────────────────────────────────────────────────────────────────────────
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_LIKE="${ID_LIKE:-}"
        OS_VERSION="${VERSION_ID:-}"
        OS_PRETTY="${PRETTY_NAME:-$OS_ID}"
    else
        OS_ID="unknown"
        OS_LIKE=""
        OS_VERSION=""
        OS_PRETTY="Unknown Linux"
    fi
}

is_debian_based() { [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" || "$OS_LIKE" == *debian* ]]; }
is_fedora_based() { [[ "$OS_ID" == "fedora" || "$OS_ID" == "rhel" || "$OS_ID" == "centos" || "$OS_LIKE" == *fedora* || "$OS_LIKE" == *rhel* ]]; }

# ─────────────────────────────────────────────────────────────────────────────
# ─── MODULE: DOCKER INSTALL (DEBIAN/UBUNTU) ──────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
module_docker_debian() {
    print_banner
    echo -e "  ${BBLUE}▶  Docker Install${RESET}  ${DIM}(Debian / Ubuntu)${RESET}"
    print_line
    echo
    info "OS detected: ${OS_PRETTY}"
    echo

    if ! is_debian_based; then
        warn "This option is designed for Debian/Ubuntu systems."
        if ! confirm "Continue anyway?"; then return; fi
    fi

    step "Running Docker & Docker Compose installer…"
    echo
    bash <(curl -Ls "https://gist.githubusercontent.com/pasinduljay/02cf2effb83c771c6f302b2ba59faf74/raw/8f1a8903b11da98510bb53f452fd8a0b35f04c53/Verification%2520for%2520Docker%2520and%2520Docker-compose")

    echo
    print_line
    ok "Docker installation complete."
    if command -v docker &>/dev/null; then
        ok "Docker version: $(docker --version)"
    fi
    if command -v docker compose &>/dev/null; then
        ok "Docker Compose version: $(docker compose version --short 2>/dev/null || docker compose version)"
    fi
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── MODULE: DOCKER INSTALL (FEDORA/RHEL) ────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
module_docker_fedora() {
    print_banner
    echo -e "  ${BBLUE}▶  Docker Install${RESET}  ${DIM}(Fedora / RHEL / CentOS)${RESET}"
    print_line
    echo

    if ! is_fedora_based; then
        warn "This option is designed for Fedora/RHEL/CentOS systems."
        if ! confirm "Continue anyway?"; then return; fi
    fi

    # Remove conflicting packages
    step "Removing conflicting packages…"
    maybe_sudo dnf remove -y docker docker-client docker-client-latest \
        docker-common docker-latest docker-latest-logrotate \
        docker-logrotate docker-selinux docker-engine-selinux \
        docker-engine podman-docker 2>/dev/null || true
    ok "Conflicting packages removed."

    # Install dnf-plugins-core
    run_quietly "Installing dnf-plugins-core…" maybe_sudo dnf install -y dnf-plugins-core

    # Add Docker repo
    run_quietly "Adding Docker CE repository…" \
        maybe_sudo dnf config-manager --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo

    # Install Docker
    run_quietly "Installing Docker CE…" \
        maybe_sudo dnf install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    # Enable & start
    run_quietly "Enabling Docker service…" maybe_sudo systemctl enable --now docker

    # Add current user to docker group
    local _user="${SUDO_USER:-$USER}"
    if [[ "$_user" != "root" ]]; then
        maybe_sudo usermod -aG docker "$_user"
        ok "User '${_user}' added to docker group (re-login required to take effect)."
    fi

    echo
    print_line
    ok "Docker installed successfully."
    ok "Docker version: $(docker --version)"
    ok "Compose version: $(docker compose version --short 2>/dev/null || true)"
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── MODULE: USER MANAGEMENT ─────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
create_sudo_nopasswd_user() {
    print_banner
    echo -e "  ${BBLUE}▶  Create Privileged User${RESET}  ${DIM}(sudo without password)${RESET}"
    print_line
    echo
    info "This user will be able to run ALL sudo commands without entering a password."
    warn "Only create this for trusted administrators."
    echo

    ask USERNAME "Username"
    if [[ -z "$USERNAME" ]]; then err "Username cannot be empty."; pause; return; fi

    if id "$USERNAME" &>/dev/null; then
        warn "User '${USERNAME}' already exists."
        if ! confirm "Add to NOPASSWD sudo anyway?"; then return; fi
    else
        maybe_sudo useradd -m -s /bin/bash "$USERNAME"
        ok "User '${USERNAME}' created."
        echo -ne "  ${BYELLOW}?${RESET}  ${BOLD}Set password for '${USERNAME}'${RESET}: "
        maybe_sudo passwd "$USERNAME"
    fi

    maybe_sudo usermod -aG sudo "$USERNAME" 2>/dev/null || maybe_sudo usermod -aG wheel "$USERNAME" 2>/dev/null || true
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" | maybe_sudo tee "/etc/sudoers.d/${USERNAME}" >/dev/null
    maybe_sudo chmod 440 "/etc/sudoers.d/${USERNAME}"

    echo
    ok "User '${USERNAME}' configured with NOPASSWD sudo access."
    ok "Sudoers file: /etc/sudoers.d/${USERNAME}"
    pause
}

create_standard_sudo_user() {
    print_banner
    echo -e "  ${BBLUE}▶  Create Standard Sudo User${RESET}  ${DIM}(password required for sudo)${RESET}"
    print_line
    echo

    ask USERNAME "Username"
    if [[ -z "$USERNAME" ]]; then err "Username cannot be empty."; pause; return; fi

    if id "$USERNAME" &>/dev/null; then
        warn "User '${USERNAME}' already exists."
        if ! confirm "Add to sudo group anyway?"; then return; fi
    else
        maybe_sudo useradd -m -s /bin/bash "$USERNAME"
        ok "User '${USERNAME}' created."
        echo -ne "  ${BYELLOW}?${RESET}  ${BOLD}Set password for '${USERNAME}'${RESET}: "
        maybe_sudo passwd "$USERNAME"
    fi

    maybe_sudo usermod -aG sudo "$USERNAME" 2>/dev/null || maybe_sudo usermod -aG wheel "$USERNAME" 2>/dev/null || true

    echo
    ok "User '${USERNAME}' has sudo access (password required)."
    pause
}

delete_user() {
    print_banner
    echo -e "  ${BBLUE}▶  Delete User${RESET}"
    print_line
    echo

    ask USERNAME "Username to delete"
    if [[ -z "$USERNAME" ]]; then err "Username cannot be empty."; pause; return; fi

    if ! id "$USERNAME" &>/dev/null; then
        err "User '${USERNAME}' does not exist."
        pause; return
    fi

    warn "This will delete user '${USERNAME}' and their home directory!"
    if ! confirm "Are you sure?"; then info "Cancelled."; pause; return; fi

    maybe_sudo userdel -r "$USERNAME" 2>/dev/null || true
    if [[ -f "/etc/sudoers.d/${USERNAME}" ]]; then
        maybe_sudo rm -f "/etc/sudoers.d/${USERNAME}"
        ok "Removed sudoers file for '${USERNAME}'."
    fi

    ok "User '${USERNAME}' deleted."
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── MODULE: UFW FIREWALL ─────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
ufw_install_if_needed() {
    if ! command -v ufw &>/dev/null; then
        step "UFW not found. Installing…"
        if is_debian_based; then
            run_quietly "Installing UFW…" maybe_sudo apt-get install -y ufw
        elif is_fedora_based; then
            run_quietly "Installing UFW…" maybe_sudo dnf install -y ufw
        else
            err "Cannot auto-install UFW on this OS. Please install it manually."
            pause; return 1
        fi
    fi
    return 0
}

ufw_menu() {
    while true; do
        print_banner
        echo -e "  ${BBLUE}▶  UFW Firewall${RESET}"
        print_line
        echo
        if command -v ufw &>/dev/null; then
            local status
            status=$(maybe_sudo ufw status 2>/dev/null | head -1)
            info "Current status: ${BYELLOW}${status}${RESET}"
        fi
        echo
        echo -e "  ${BCYAN}[1]${RESET}  Enable UFW + Apply Default Rules"
        echo -e "  ${BCYAN}[2]${RESET}  Allow a Custom Port"
        echo -e "  ${BCYAN}[3]${RESET}  Show UFW Status (verbose)"
        echo -e "  ${BCYAN}[4]${RESET}  Disable UFW"
        echo -e "  ${BCYAN}[0]${RESET}  Back"
        echo
        print_line
        ask UFW_CHOICE "Select option"

        case "$UFW_CHOICE" in
            1)
                ufw_install_if_needed || continue
                step "Applying default rules…"
                maybe_sudo ufw default deny incoming
                maybe_sudo ufw default allow outgoing
                maybe_sudo ufw allow 22/tcp comment 'SSH'
                maybe_sudo ufw allow 80/tcp comment 'HTTP'
                maybe_sudo ufw allow 443/tcp comment 'HTTPS'
                maybe_sudo ufw allow 8069/tcp comment 'Odoo'
                echo "y" | maybe_sudo ufw enable
                echo
                ok "UFW enabled with default rules:"
                ok "  Allowed: 22 (SSH), 80 (HTTP), 443 (HTTPS), 8069 (Odoo)"
                pause
                ;;
            2)
                ufw_install_if_needed || continue
                ask CUSTOM_PORT "Port number (e.g. 3000 or 3000/tcp)"
                if [[ -z "$CUSTOM_PORT" ]]; then continue; fi
                maybe_sudo ufw allow "$CUSTOM_PORT"
                ok "Port ${CUSTOM_PORT} allowed."
                pause
                ;;
            3)
                ufw_install_if_needed || continue
                echo
                maybe_sudo ufw status verbose
                pause
                ;;
            4)
                ufw_install_if_needed || continue
                if confirm "Disable UFW? (all rules will be inactive)"; then
                    maybe_sudo ufw disable
                    ok "UFW disabled."
                fi
                pause
                ;;
            0|"") break ;;
            *) warn "Invalid option." ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── MODULE: ODOO LEGACY INSTALL ─────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
install_odoo_legacy() {
    print_banner
    echo -e "  ${BBLUE}▶  Install Odoo${RESET}  ${DIM}(Legacy / Bare-metal)${RESET}"
    print_line
    echo

    if ! is_debian_based; then
        err "Legacy install currently supports Debian/Ubuntu only."
        pause; return
    fi

    echo -e "  ${BWHITE}Select Odoo Version:${RESET}"
    echo -e "  ${BCYAN}[1]${RESET}  Odoo 16"
    echo -e "  ${BCYAN}[2]${RESET}  Odoo 17"
    echo -e "  ${BCYAN}[3]${RESET}  Odoo 18"
    echo -e "  ${BCYAN}[4]${RESET}  Odoo 19"
    echo
    ask ODOO_VER_CHOICE "Select version"

    case "$ODOO_VER_CHOICE" in
        1) ODOO_VERSION="16.0" ;;
        2) ODOO_VERSION="17.0" ;;
        3) ODOO_VERSION="18.0" ;;
        4) ODOO_VERSION="19.0" ;;
        *) err "Invalid selection."; pause; return ;;
    esac

    info "Installing Odoo ${ODOO_VERSION} from official packages…"
    echo

    # Dependencies
    run_quietly "Updating package index…" maybe_sudo apt-get update -qq
    run_quietly "Installing dependencies…" maybe_sudo apt-get install -y \
        curl wget gnupg2 lsb-release apt-transport-https ca-certificates \
        python3 python3-pip python3-venv python3-dev libpq-dev \
        libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev \
        libjpeg-dev zlib1g-dev libfreetype6-dev node-less \
        postgresql postgresql-client

    # wkhtmltopdf
    step "Installing wkhtmltopdf…"
    local ARCH; ARCH=$(dpkg --print-architecture)
    local WKHTML_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${ARCH}.deb"
    wget -qO /tmp/wkhtmltox.deb "$WKHTML_URL" 2>/dev/null || true
    maybe_sudo apt-get install -y /tmp/wkhtmltox.deb 2>/dev/null || \
        maybe_sudo apt-get install -y wkhtmltopdf 2>/dev/null || true
    ok "wkhtmltopdf installed."

    # Add Odoo repo
    step "Adding Odoo ${ODOO_VERSION} repository…"
    wget -qO - https://nightly.odoo.com/odoo.key | maybe_sudo gpg --dearmor -o /usr/share/keyrings/odoo-archive-keyring.gpg 2>/dev/null || \
        wget -qO - https://nightly.odoo.com/odoo.key | maybe_sudo apt-key add - 2>/dev/null || true

    local MAJOR_VER="${ODOO_VERSION%%.*}"
    echo "deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/ ./" | \
        maybe_sudo tee /etc/apt/sources.list.d/odoo.list >/dev/null

    run_quietly "Updating package index with Odoo repo…" maybe_sudo apt-get update -qq
    run_quietly "Installing Odoo ${ODOO_VERSION}…" maybe_sudo apt-get install -y odoo

    # Enable service
    maybe_sudo systemctl enable --now odoo

    echo
    print_line
    ok "Odoo ${ODOO_VERSION} installed and running as a systemd service."
    ok "Access: http://$(hostname -I | awk '{print $1}'):8069"
    warn "Default config: /etc/odoo/odoo.conf"
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── MODULE: ODOO DOCKER – Traefik dashboard toggle helper ───────────────────
# ─────────────────────────────────────────────────────────────────────────────
_traefik_dashboard_on()  { echo "true"; }
_traefik_dashboard_off() { echo "false"; }

# ─────────────────────────────────────────────────────────────────────────────
# ─── HELPER: Clone or update a git repo ──────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
clone_or_update_repo() {
    local REPO_URL="$1" TARGET_DIR="$2"

    if ! command -v git &>/dev/null; then
        step "git not found – installing…"
        if is_debian_based; then
            run_quietly "Installing git…" maybe_sudo apt-get install -y git
        elif is_fedora_based; then
            run_quietly "Installing git…" maybe_sudo dnf install -y git
        else
            err "Please install git manually and re-run."
            return 1
        fi
    fi

    if [[ -d "${TARGET_DIR}/.git" ]]; then
        step "Updating existing repo at ${TARGET_DIR}…"
        maybe_sudo git -C "$TARGET_DIR" pull --ff-only
        ok "Repo updated."
    else
        step "Cloning ${REPO_URL} → ${TARGET_DIR}…"
        maybe_sudo git clone --depth=1 "$REPO_URL" "$TARGET_DIR"
        ok "Repo cloned."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── MODULE: ODOO DOCKER INSTALL ─────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
generate_docker_compose_cloudflare() {
    local INSTALL_DIR="$1" ODOO_DOMAIN="$2" TRAEFIK_DOMAIN="$3" \
          ODOO_VERSION="$4" DASHBOARD_ENABLED="$5" DB_PASS="$6"

    cat > "${INSTALL_DIR}/docker-compose.yml" <<EODC
services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: always
    command:
      - "--api.dashboard=${DASHBOARD_ENABLED}"
      - "--api.insecure=false"
      - "--accesslog=true"
      - "--accesslog.filepath=/logs/access.log"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=traefik-odoo"
      - "--providers.file.directory=/etc/traefik/dynamic"
      - "--providers.file.watch=true"
      - "--log.level=INFO"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./traefik/logs:/logs"
      - "./traefik/certs:/etc/traefik/certs:ro"
      - "./traefik/dynamic:/etc/traefik/dynamic:ro"
    networks:
      - traefik-odoo
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(\`${TRAEFIK_DOMAIN}\`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls=true"
      - "traefik.http.routers.dashboard.service=api@internal"

  web:
    image: odoo:${ODOO_VERSION}
    restart: always
    container_name: odoo
    depends_on:
      - db
      - traefik
    volumes:
      - odoo-web-data:/var/lib/odoo
      - ./config:/etc/odoo
      - ./custom-addons:/mnt/extra-addons
    environment:
      - HOST=db
      - USER=odoo
      - PASSWORD_FILE=/run/secrets/postgresql_password
    secrets:
      - postgresql_password
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.odoo.rule=Host(\`${ODOO_DOMAIN}\`)"
      - "traefik.http.routers.odoo.entrypoints=websecure"
      - "traefik.http.routers.odoo.tls=true"
      - "traefik.http.services.odoo.loadbalancer.server.port=8069"
      - "traefik.http.middlewares.odoo-headers.headers.customResponseHeaders.X-Frame-Options=SAMEORIGIN"
      - "traefik.http.middlewares.odoo-headers.headers.customResponseHeaders.X-Content-Type-Options=nosniff"
      - "traefik.http.middlewares.odoo-headers.headers.customResponseHeaders.Strict-Transport-Security=max-age=31536000; includeSubDomains"
      - "traefik.http.routers.odoo.middlewares=odoo-headers"
    networks:
      - traefik-odoo
      - odoo-db

  db:
    image: postgres:15
    restart: always
    container_name: odoo-db
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_USER=odoo
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgresql_password
    secrets:
      - postgresql_password
    volumes:
      - odoo-db-data:/var/lib/postgresql/data
    networks:
      - odoo-db

volumes:
  odoo-web-data:
  odoo-db-data:

networks:
  traefik-odoo:
    name: traefik-odoo
    driver: bridge
  odoo-db:
    name: odoo-db
    driver: bridge

secrets:
  postgresql_password:
    file: odoo_pg_pass
EODC
}

generate_docker_compose_letsencrypt() {
    local INSTALL_DIR="$1" ODOO_DOMAIN="$2" TRAEFIK_DOMAIN="$3" \
          ODOO_VERSION="$4" DASHBOARD_ENABLED="$5" LE_EMAIL="$6"

    cat > "${INSTALL_DIR}/docker-compose.yml" <<EODC
services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: always
    command:
      - "--api.dashboard=${DASHBOARD_ENABLED}"
      - "--api.insecure=false"
      - "--accesslog=true"
      - "--accesslog.filepath=/logs/access.log"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=traefik-odoo"
      - "--providers.file.directory=/etc/traefik/dynamic"
      - "--providers.file.watch=true"
      - "--log.level=INFO"
      - "--certificatesresolvers.letsencrypt.acme.email=${LE_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/etc/traefik/acme/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./traefik/logs:/logs"
      - "./traefik/acme:/etc/traefik/acme"
      - "./traefik/dynamic:/etc/traefik/dynamic:ro"
    networks:
      - traefik-odoo
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(\`${TRAEFIK_DOMAIN}\`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls=true"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"

  web:
    image: odoo:${ODOO_VERSION}
    restart: always
    container_name: odoo
    depends_on:
      - db
      - traefik
    volumes:
      - odoo-web-data:/var/lib/odoo
      - ./config:/etc/odoo
      - ./custom-addons:/mnt/extra-addons
    environment:
      - HOST=db
      - USER=odoo
      - PASSWORD_FILE=/run/secrets/postgresql_password
    secrets:
      - postgresql_password
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.odoo.rule=Host(\`${ODOO_DOMAIN}\`)"
      - "traefik.http.routers.odoo.entrypoints=websecure"
      - "traefik.http.routers.odoo.tls=true"
      - "traefik.http.routers.odoo.tls.certresolver=letsencrypt"
      - "traefik.http.services.odoo.loadbalancer.server.port=8069"
      - "traefik.http.middlewares.odoo-headers.headers.customResponseHeaders.X-Frame-Options=SAMEORIGIN"
      - "traefik.http.middlewares.odoo-headers.headers.customResponseHeaders.X-Content-Type-Options=nosniff"
      - "traefik.http.middlewares.odoo-headers.headers.customResponseHeaders.Strict-Transport-Security=max-age=31536000; includeSubDomains"
      - "traefik.http.routers.odoo.middlewares=odoo-headers"
    networks:
      - traefik-odoo
      - odoo-db

  db:
    image: postgres:15
    restart: always
    container_name: odoo-db
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_USER=odoo
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgresql_password
    secrets:
      - postgresql_password
    volumes:
      - odoo-db-data:/var/lib/postgresql/data
    networks:
      - odoo-db

volumes:
  odoo-web-data:
  odoo-db-data:

networks:
  traefik-odoo:
    name: traefik-odoo
    driver: bridge
  odoo-db:
    name: odoo-db
    driver: bridge

secrets:
  postgresql_password:
    file: odoo_pg_pass
EODC
}

generate_traefik_dynamic_cloudflare() {
    local DYNAMIC_DIR="$1"
    mkdir -p "$DYNAMIC_DIR"
    cat > "${DYNAMIC_DIR}/certificates.yml" <<EOTLS
tls:
  certificates:
    - certFile: /etc/traefik/certs/origin-cert.pem
      keyFile: /etc/traefik/certs/origin-key.pem

  options:
    default:
      minVersion: VersionTLS12
      sniStrict: true
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
EOTLS
}

generate_traefik_dynamic_letsencrypt() {
    local DYNAMIC_DIR="$1"
    mkdir -p "$DYNAMIC_DIR"
    cat > "${DYNAMIC_DIR}/tls-options.yml" <<EOTLS
tls:
  options:
    default:
      minVersion: VersionTLS12
      sniStrict: true
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
EOTLS
}

generate_odoo_conf() {
    local CONFIG_DIR="$1"
    mkdir -p "$CONFIG_DIR"
    cat > "${CONFIG_DIR}/odoo.conf" <<EOCFG
[options]
addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons
proxy_mode = True
logfile = /etc/odoo/odoo.log
log_level = info
list_db = False
db_maxconn = 32
unaccent = True
session_timeout = 3600
secure_cookie_httponly = True
EOCFG
}

install_odoo_docker() {
    print_banner
    echo -e "  ${BBLUE}▶  Install Odoo${RESET}  ${DIM}(Docker Stack)${RESET}"
    print_line
    echo

    # Check Docker
    if ! command -v docker &>/dev/null; then
        warn "Docker is not installed."
        if confirm "Install Docker now?"; then
            if is_debian_based; then module_docker_debian
            elif is_fedora_based; then module_docker_fedora
            else err "Cannot auto-install Docker on this OS."; pause; return; fi
        else
            pause; return
        fi
    fi

    print_banner
    echo -e "  ${BBLUE}▶  Odoo Docker Stack – Deployment Wizard${RESET}"
    print_line
    echo

    # ── Version
    echo -e "  ${BWHITE}Odoo Version:${RESET}"
    echo -e "  ${BCYAN}[1]${RESET}  Odoo 16   ${BCYAN}[2]${RESET}  Odoo 17   ${BCYAN}[3]${RESET}  Odoo 18   ${BCYAN}[4]${RESET}  Odoo 19"
    echo
    ask ODOO_VER_CHOICE "Select version" "3"
    case "$ODOO_VER_CHOICE" in
        1) ODOO_VERSION="16.0" ;;  2) ODOO_VERSION="17.0" ;;
        3) ODOO_VERSION="18.0" ;;  4) ODOO_VERSION="19.0" ;;
        *) ODOO_VERSION="18.0" ;;
    esac

    # ── Domains
    echo
    ask ODOO_DOMAIN "Odoo domain" "odoo.example.com"

    # ── Install dir
    ask INSTALL_DIR "Installation directory" "$DEFAULT_INSTALL_DIR"

    # ── Traefik dashboard
    echo
    print_line
    echo -e "  ${BWHITE}Traefik Dashboard:${RESET}"
    echo -e "  ${BCYAN}[1]${RESET}  Enable   ${BCYAN}[2]${RESET}  Disable"
    ask DASH_CHOICE "Dashboard" "2"
    if [[ "$DASH_CHOICE" == "1" ]]; then
        DASHBOARD_ENABLED="true"
        ask TRAEFIK_DOMAIN "Traefik dashboard domain" "traefik.example.com"
    else
        DASHBOARD_ENABLED="false"
        TRAEFIK_DOMAIN="dashboard.disabled"
    fi

    # ── SSL Mode
    echo
    print_line
    echo -e "  ${BWHITE}SSL / TLS Certificate Mode:${RESET}"
    echo
    echo -e "  ${BCYAN}[1]${RESET}  ${BWHITE}Cloudflare${RESET} Origin Certificate"
    echo -e "       ${DIM}You provide Cloudflare Origin cert + key (PEM format)${RESET}"
    echo -e "       ${DIM}Best for: sites behind Cloudflare proxy${RESET}"
    echo
    echo -e "  ${BCYAN}[2]${RESET}  ${BWHITE}Let's Encrypt${RESET} (ACME – auto-renewing)"
    echo -e "       ${DIM}Traefik automatically obtains & renews certificates${RESET}"
    echo -e "       ${DIM}Best for: public servers with DNS pointing directly to them${RESET}"
    echo
    ask SSL_MODE "Select SSL mode" "1"

    # ── Clone the odoo-docker repo (base files: odoo.conf, custom-addons, traefik structure)
    echo
    print_line
    info "Source repo: ${ODOO_DOCKER_REPO}"
    info "Deploy dir:  ${INSTALL_DIR}"
    print_line
    echo

    local TMP_CLONE="/tmp/smgr_odoo_docker_$$"
    clone_or_update_repo "$ODOO_DOCKER_REPO" "$TMP_CLONE" || { pause; return; }

    # Copy base structure from repo (preserves custom-addons, odoo.conf, etc.)
    step "Deploying base stack to ${INSTALL_DIR}…"
    maybe_sudo mkdir -p "$INSTALL_DIR"
    maybe_sudo cp -r "${TMP_CLONE}/." "${INSTALL_DIR}/"
    # Ensure required dirs always exist
    maybe_sudo mkdir -p "${INSTALL_DIR}/traefik/certs" \
                        "${INSTALL_DIR}/traefik/logs" \
                        "${INSTALL_DIR}/traefik/dynamic" \
                        "${INSTALL_DIR}/traefik/acme"
    rm -rf "$TMP_CLONE"
    ok "Base stack deployed from ${ODOO_DOCKER_REPO}"

    # ── Generate DB password (not kept in repo – generated fresh each deploy)
    local DB_PASS
    DB_PASS=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom 2>/dev/null | head -c 32 || openssl rand -base64 24)
    echo "$DB_PASS" | maybe_sudo tee "${INSTALL_DIR}/odoo_pg_pass" >/dev/null
    maybe_sudo chmod 600 "${INSTALL_DIR}/odoo_pg_pass"
    ok "Secure database password generated."

    # ── Overwrite odoo.conf with deploy-time settings
    generate_odoo_conf "${INSTALL_DIR}/config"
    ok "Odoo config applied."

    case "$SSL_MODE" in
        2)
            # ── Let's Encrypt
            echo
            print_line
            echo -e "  ${BWHITE}Let's Encrypt Configuration${RESET}"
            print_line
            ask LE_EMAIL "Email address for Let's Encrypt notifications"

            generate_docker_compose_letsencrypt \
                "$INSTALL_DIR" "$ODOO_DOMAIN" "$TRAEFIK_DOMAIN" \
                "$ODOO_VERSION" "$DASHBOARD_ENABLED" "$LE_EMAIL"

            generate_traefik_dynamic_letsencrypt "${INSTALL_DIR}/traefik/dynamic"

            # acme.json must be 600
            maybe_sudo touch "${INSTALL_DIR}/traefik/acme/acme.json"
            maybe_sudo chmod 600 "${INSTALL_DIR}/traefik/acme/acme.json"
            ok "Let's Encrypt configuration generated."
            ;;
        *)
            # ── Cloudflare
            echo
            print_line
            echo -e "  ${BWHITE}Cloudflare Origin Certificate${RESET}"
            print_line
            echo
            info "Paste your Cloudflare Origin Certificate (PEM format)."
            info "End with a blank line when done."
            echo

            CERT_CONTENT=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && break
                CERT_CONTENT+="${line}"$'\n'
            done
            echo "$CERT_CONTENT" | maybe_sudo tee "${INSTALL_DIR}/traefik/certs/origin-cert.pem" >/dev/null

            echo
            info "Paste your Cloudflare Origin Key (PEM format)."
            info "End with a blank line when done."
            echo

            KEY_CONTENT=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && break
                KEY_CONTENT+="${line}"$'\n'
            done
            echo "$KEY_CONTENT" | maybe_sudo tee "${INSTALL_DIR}/traefik/certs/origin-key.pem" >/dev/null
            maybe_sudo chmod 600 "${INSTALL_DIR}/traefik/certs/origin-key.pem"
            ok "Cloudflare certificates saved."

            generate_docker_compose_cloudflare \
                "$INSTALL_DIR" "$ODOO_DOMAIN" "$TRAEFIK_DOMAIN" \
                "$ODOO_VERSION" "$DASHBOARD_ENABLED" "$DB_PASS"

            generate_traefik_dynamic_cloudflare "${INSTALL_DIR}/traefik/dynamic"
            ok "Cloudflare Traefik config generated."
            ;;
    esac

    # ── Start stack
    echo
    print_line
    if confirm "Start the Odoo stack now?"; then
        step "Starting Docker stack (this may take a few minutes for first pull)…"
        cd "$INSTALL_DIR"
        maybe_sudo docker compose pull 2>&1 | while read -r l; do echo -e "    ${DIM}${l}${RESET}"; done
        maybe_sudo docker compose up -d
        echo
        ok "Stack started!"
        echo
        ok "  Odoo:              https://${ODOO_DOMAIN}"
        if [[ "$DASHBOARD_ENABLED" == "true" ]]; then
            ok "  Traefik Dashboard: https://${TRAEFIK_DOMAIN}/dashboard/"
        fi
        echo
        warn "First startup may take 1–2 minutes for database initialization."
        warn "DB password saved at: ${INSTALL_DIR}/odoo_pg_pass"
    else
        info "Stack not started. To start manually:"
        echo -e "    ${BCYAN}cd ${INSTALL_DIR} && sudo docker compose up -d${RESET}"
    fi
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── MODULE: MANAGE EXISTING ODOO DOCKER STACK ───────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
manage_odoo_stack() {
    print_banner
    echo -e "  ${BBLUE}▶  Manage Odoo Docker Stack${RESET}"
    print_line
    echo

    ask STACK_DIR "Stack install directory" "$DEFAULT_INSTALL_DIR"

    if [[ ! -f "${STACK_DIR}/docker-compose.yml" ]]; then
        err "No docker-compose.yml found at ${STACK_DIR}."
        info "Use 'Install Odoo (Docker)' to deploy a new stack first."
        pause; return
    fi

    echo
    echo -e "  ${BCYAN}[1]${RESET}  Start Stack"
    echo -e "  ${BCYAN}[2]${RESET}  Stop Stack"
    echo -e "  ${BCYAN}[3]${RESET}  Restart Stack"
    echo -e "  ${BCYAN}[4]${RESET}  View Logs  (Ctrl+C to exit)"
    echo -e "  ${BCYAN}[5]${RESET}  Stack Status"
    echo -e "  ${BCYAN}[6]${RESET}  Toggle Traefik Dashboard (Enable/Disable)"
    echo -e "  ${BCYAN}[0]${RESET}  Back"
    echo
    ask STACK_CHOICE "Select option"

    case "$STACK_CHOICE" in
        1)  cd "$STACK_DIR"; maybe_sudo docker compose up -d; ok "Stack started."; pause ;;
        2)  cd "$STACK_DIR"; maybe_sudo docker compose down; ok "Stack stopped."; pause ;;
        3)  cd "$STACK_DIR"; maybe_sudo docker compose restart; ok "Stack restarted."; pause ;;
        4)  cd "$STACK_DIR"; maybe_sudo docker compose logs -f --tail=100 ;;
        5)  cd "$STACK_DIR"; maybe_sudo docker compose ps; pause ;;
        6)  _toggle_traefik_dashboard "$STACK_DIR" ;;
        0|"") return ;;
        *) warn "Invalid option."; pause ;;
    esac
}

_toggle_traefik_dashboard() {
    local DIR="$1"
    local COMPOSE="${DIR}/docker-compose.yml"
    echo
    echo -e "  ${BWHITE}Toggle Traefik Dashboard:${RESET}"
    echo -e "  ${BCYAN}[1]${RESET}  Enable   ${BCYAN}[2]${RESET}  Disable"
    ask DASH_TOGGLE "Select"

    if [[ "$DASH_TOGGLE" == "1" ]]; then
        maybe_sudo sed -i 's/--api\.dashboard=false/--api.dashboard=true/g' "$COMPOSE"
        ok "Dashboard enabled. Restart the stack to apply."
    elif [[ "$DASH_TOGGLE" == "2" ]]; then
        maybe_sudo sed -i 's/--api\.dashboard=true/--api.dashboard=false/g' "$COMPOSE"
        ok "Dashboard disabled. Restart the stack to apply."
    fi

    if confirm "Restart stack now?"; then
        cd "$DIR"; maybe_sudo docker compose restart traefik
        ok "Traefik restarted."
    fi
    pause
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── ODOO MANAGEMENT MENU ─────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
menu_odoo() {
    while true; do
        print_banner
        echo -e "  ${BMAGENTA}▶  Odoo Management${RESET}"
        print_line
        echo
        echo -e "  ${BYELLOW}── User Management ──────────────────────────────────${RESET}"
        echo -e "  ${BCYAN}[1]${RESET}  Create Privileged User     ${DIM}(sudo without password)${RESET}"
        echo -e "  ${BCYAN}[2]${RESET}  Create Standard Sudo User  ${DIM}(sudo with password)${RESET}"
        echo -e "  ${BCYAN}[3]${RESET}  Delete User"
        echo
        echo -e "  ${BYELLOW}── Odoo Installation ────────────────────────────────${RESET}"
        echo -e "  ${BCYAN}[4]${RESET}  Install Odoo  ${DIM}(Legacy / Bare-metal)${RESET}"
        echo -e "  ${BCYAN}[5]${RESET}  Install Odoo  ${DIM}(Docker Stack – Wizard)${RESET}"
        echo -e "  ${BCYAN}[6]${RESET}  Manage Existing Odoo Docker Stack"
        echo
        echo -e "  ${BYELLOW}── System ───────────────────────────────────────────${RESET}"
        echo -e "  ${BCYAN}[7]${RESET}  UFW Firewall"
        echo
        echo -e "  ${BCYAN}[0]${RESET}  ← Back to Main Menu"
        echo
        print_line
        ask ODOO_CHOICE "Select option"

        case "$ODOO_CHOICE" in
            1) create_sudo_nopasswd_user ;;
            2) create_standard_sudo_user ;;
            3) delete_user ;;
            4) install_odoo_legacy ;;
            5) install_odoo_docker ;;
            6) manage_odoo_stack ;;
            7) ufw_menu ;;
            0|"") break ;;
            *) warn "Invalid option. Please try again." ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── MAIN MENU ────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        print_banner
        echo -e "  ${DIM}OS: ${OS_PRETTY}${RESET}"
        echo
        echo -e "  ${BMAGENTA}[1]${RESET}  ${BWHITE}Odoo Management${RESET}"
        echo -e "       ${DIM}Users, install, Docker stack, firewall${RESET}"
        echo
        echo -e "  ${BMAGENTA}[2]${RESET}  ${BWHITE}Docker Install${RESET}  ${DIM}(Debian / Ubuntu)${RESET}"
        echo -e "       ${DIM}Install Docker CE + Compose plugin${RESET}"
        echo
        echo -e "  ${BMAGENTA}[3]${RESET}  ${BWHITE}Docker Install${RESET}  ${DIM}(Fedora / RHEL / CentOS)${RESET}"
        echo -e "       ${DIM}Install Docker CE via DNF${RESET}"
        echo
        echo -e "  ${BMAGENTA}[0]${RESET}  Exit"
        echo
        print_double_line
        ask MAIN_CHOICE "Select option"

        case "$MAIN_CHOICE" in
            1|odoo|Odoo)    menu_odoo ;;
            2|docker-deb)   module_docker_debian ;;
            3|docker-fed)   module_docker_fedora ;;
            0|exit|quit)
                echo
                echo -e "  ${BCYAN}Goodbye! 👋${RESET}"
                echo
                exit 0
                ;;
            *) warn "Invalid option. Please enter 1, 2, 3, or 0." ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# ─── ENTRY POINT ─────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
main() {
    detect_os
    check_privileges
    main_menu
}

main "$@"
