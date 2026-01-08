#!/bin/bash
#
# === KCStudio Launchpad v2.0 ===
#
# The Central Command Hub for the KCstudio Launchpad Bash Platform.
#
# Copyright (c) 2026 Kelvin Deen - KCStudio.nl
#

set -euo pipefail
IFS=$'\n\t'

# --- Constants ---
SECURE_STATE_FILE="/etc/kcstudio/secure_core.state"

# --- Colors (Standardized) ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[1;33m'
BLUE='\033[36m'
ORANGE='\033[0;33m'
DARKGRAY='\033[0;33m'
WHITE='\033[1;37m'
RESET='\033[0m'

# --- Helper Functions ---
log() { echo -e "\n${GREEN}[+]${RESET} $1"; }
log_ok() { echo -e "  ${GREEN}✔${RESET} $1"; }
log_warn() { echo -e "  ${YELLOW}!${RESET} $1"; }
log_err() { echo -e "\n${RED}[!]${RESET} $1"; } # No exit
warn() { echo -e "\n${YELLOW}[!]${RESET} $1"; }
err() { echo -e "\n${RED}[X]${RESET} $1" >&2; exit 1; }
prompt() { read -rp "$(echo -e "${BLUE}[?]${RESET} $1 ")" "$2"; }
pause() { echo ""; read -rp "Press [Enter] to continue..."; }

# --- Root Enforcement ---
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo ""
    echo ""
    log_err "This script must be run as root to use & enjoy all its features flawlessly."
    echo -e "Please \e[1mrun\e[0m it \e[1magain\e[0m with:"
    echo ""
    echo -e "  \e[36msudo launchpad (or kcstudio-launchpad)\e[0m"
    echo ""
    echo ""
    echo ""
    echo ""
    exit 1
fi

# --- Startup animation ---
launch_kcstudio() {
    clear

    # --- Add vertical padding ---
    blank_lines=60
    for ((i = 0; i < blank_lines; i++)); do
        echo ""
    done

    # --- Rocket ASCII ---
    rocket_lines=(
    "                                   ${YELLOW}████${RESET}                                "
    "                                  ${YELLOW}█${ORANGE}▓${YELLOW}█████${RESET}                               "
    "                                 ${YELLOW}█${ORANGE}▓${YELLOW}███████${RESET}                              "
    "                               ${YELLOW}██${ORANGE}▓▓${YELLOW}████████${RESET}                             "
    "                              ${YELLOW}██${ORANGE}▓▓▓▓${YELLOW}████████${RESET}                            "
    "                             ${DARKGRAY}▒▒▒▒▒▒▒▒▒${ORANGE}▓▓▓▓▓▓▓${RESET}                           "
    "                            ${DARKGRAY}▒▒▒▒▒▒▒▒▒▒${ORANGE}▓▓▓▓▓▓▓${RESET}                           "
    "                            ${DARKGRAY}▒▒▒▒▒▒${ORANGE}▓▓${YELLOW}███${ORANGE}▓▓▓▓▓▓▓${RESET}                          "
    "                            ${DARKGRAY}▒▒▒▒▒${ORANGE}▓${YELLOW}████████${ORANGE}▓▓▓▓${RESET}                          "
    "                           ${DARKGRAY}▒▒▒▒▒${ORANGE}▓▓${YELLOW}███████${ORANGE}▓▓▓▓${RESET}                          "
    "                           ${DARKGRAY}▒▒▒▒▒${ORANGE}▓▓${YELLOW}███████${ORANGE}▓▓▓▓▓${RESET}                        "
    "                           ${DARKGRAY}▒▒▒▒▒${ORANGE}▓${YELLOW}█████████${ORANGE}▓▓▓▓▓${RESET}                        "
    "                           ${DARKGRAY}▒▒▒▒▒▒${ORANGE}▓${YELLOW}██████${ORANGE}▓▓▓▓▓▓${RESET}                         "
    "                           ${DARKGRAY}▒▒▒▒▒▒▒▒${ORANGE}▓▓▓▓▓▓▓▓▓▓▓${RESET}                         "
    "                           ${DARKGRAY}▒▒▒▒▒▒▒▒${ORANGE}▓▓▓▓▓▓▓▓▓▓▓${RESET}                         "
    "                          ${ORANGE}▒▓▓▓${DARKGRAY}▒▒▒▒${ORANGE}▓${YELLOW}█████${ORANGE}▓▓▓▓${YELLOW}█▓▓${ORANGE}▒${RESET}                        "
    "                        ${ORANGE}▒▒▓▓▓▓${DARKGRAY}▒▒▒▒▒▒${ORANGE}▓▓▓▓▓▓▓${YELLOW}█▓▓${ORANGE}▒▓${RESET}                       "
    "                       ${ORANGE}▒▒▓▓▓▓▓▓${DARKGRAY}▒▒▒▒▒${ORANGE}▓▓▓▓▓▓${YELLOW}██▓▓▓${ORANGE}▒▓▓${RESET}                    "
    "                      ${ORANGE}▒▒▓▓▓▓▓▓▓${DARKGRAY}▒▒▒▒▒${YELLOW}▓█▓▓▓▓${YELLOW}█▓▓▓▓▓▓▓${RESET}                    "
    "                     ${ORANGE}▒▒▓▓▓▓▓▓▓▓▓${DARKGRAY}▒▒▒▒${YELLOW}▓█▓▓▓▓${YELLOW}██▓▓▓▓▓▒▓▓${RESET}                   "
    "                     ${ORANGE}▒▒▓▓▓▓▓▓▓▓▓▓${DARKGRAY}▒▒▒${YELLOW}▓██▓▓▓${YELLOW}█▓▓▓▓▓▓▓▓${RESET}                    "
    "                     ${ORANGE}▒▒▓▓▓▓▓${YELLOW} ███▓▓▓${DARKGRAY}▒${YELLOW}▓██████ ${ORANGE}▓▓▓▓▓▓${RESET}                    "
    "                     ${ORANGE}▒▒▓▓▓▓${YELLOW}   █████${DARKGRAY}▒${YELLOW}▓█████   ${ORANGE}▓▓▓▓▓▓${RESET}                    "
    "                      ${ORANGE}▒▓▓▓${YELLOW}     ▓▓▓▓${DARKGRAY}▒${YELLOW}▓▓▓▓▓     ${ORANGE}▓▓▓▓${RESET}                     "
    "                      ${ORANGE}▒▓▓▓${YELLOW}    ▓▓▓${DARKGRAY}▒▒${YELLOW}▓▓▓▓▓▓█     ${ORANGE}▓▓▓${RESET}                     "
    "                       ${ORANGE}▓▓${YELLOW}     ▓▓▓${DARKGRAY}▒▒▒${YELLOW}▓▓▓▓▓${RESET}                              "
    "                              ${YELLOW}▓▓▓▓${DARKGRAY}▒▒${YELLOW}▓▓▓▓▓${RESET}                              "
    "                              ${YELLOW}▓▓▓▓▓▓▓▓▓▓${RESET}                               "
    "                               ${YELLOW}▓▓▓▓▓▓▓▓${RESET}                                 "
    "                                 ${YELLOW}▓▓▓▓▓▓${RESET}                                 "
    "                                  ${YELLOW}▓▓▓${RESET}${ORANGE}█${RESET}                                  "
    "                                   ${YELLOW}▓${RESET}                                    "
    ""
    )

    # --- KCSTUDIO.NL Logo ASCII ---
    logo_lines=(
    "${WHITE}        ██╗  ██╗ ██████╗███████╗████████╗██╗   ██╗██████╗ ██╗ ██████╗  ${RESET}"
    "${WHITE}        ██║ ██╔╝██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║██╔═══██╗ ${RESET}"
    "${WHITE}        █████╔╝ ██║     ███████╗   ██║   ██║   ██║██║  ██║██║██║   ██║║${RESET}"
    "${WHITE}        ██╔═██╗ ██║     ╚════██║   ██║   ██║   ██║██║  ██║██║██║   ██║ ${RESET}"
    "${WHITE}        ██║  ██╗╚██████╗███████║   ██║   ╚██████╔╝██████╔╝██║╚██████╔╝ ${RESET}"
    "${WHITE}        ╚═╝  ╚═╝ ╚═════╝╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝  ${RESET}"
    ""
    )

    extra_lines_b=(
    "${WHITE}  ██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗██████╗  █████╗ ██████╗${RESET}"
    "${WHITE}  ██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║██╔══██╗██╔══██╗██╔══██╗${RESET}"
    "${WHITE}  ██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║██████╔╝███████║██║  ██║${RESET}"
    "${WHITE}  ██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║██╔═══╝ ██╔══██║██║  ██║${RESET}"
    "${WHITE}  ███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║██║     ██║  ██║██████╔╝${RESET}"
    "${WHITE}  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═════╝${RESET}"
    )

    # --- Rocket Launch Reveal ---
    for line in "${rocket_lines[@]}"; do
        echo -e "$line"
        sleep 0.02
    done

    # --- KCSTUDIO Logo Reveal ---
    sleep 0.2
    echo ""
    for line in "${logo_lines[@]}"; do
        echo -e "$line"
        sleep 0.04
    done
    # --- Launchpad Logo Reveael ---
    for line in "${extra_lines_b[@]}"; do
        echo -e "$line"
        sleep 0.04
    done
}

# --- Menu Display & Core Logic ---
show_logo() {
    clear
    echo -e '\033[1;37m'
    cat << 'EOF'

         ██╗  ██╗ ██████╗███████╗████████╗██╗   ██╗██████╗ ██╗ ██████╗   
         ██║ ██╔╝██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║██╔═══██╗ 
         █████╔╝ ██║     ███████╗   ██║   ██║   ██║██║  ██║██║██║   ██║  
         ██╔═██╗ ██║     ╚════██║   ██║   ██║   ██║██║  ██║██║██║   ██║ 
         ██║  ██╗╚██████╗███████║   ██║   ╚██████╔╝██████╔╝██║╚██████╔╝
         ╚═╝  ╚═╝ ╚═════╝╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝ 

   ██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗██████╗  █████╗ ██████╗
   ██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║██╔══██╗██╔══██╗██╔══██╗
   ██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║██████╔╝███████║██║  ██║
   ██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║██╔═══╝ ██╔══██║██║  ██║
   ███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║██║     ██║  ██║██████╔╝
   ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═════╝

EOF
    echo -e "${RESET}"
}

run_script() {
    local script_pattern="$1"
    local toolkit_dir
    # Get the directory where this script is running
    toolkit_dir=$(dirname "$(realpath "$0")")
    local script_path=""

    # ----------------------------------------------------------------
    # 1. PRIORITY: Exact Match (Fastest & Safest)
    # ----------------------------------------------------------------
    if [ -f "$toolkit_dir/${script_pattern}.sh" ]; then
        script_path="$toolkit_dir/${script_pattern}.sh"

    # ----------------------------------------------------------------
    # 2. FALLBACK: Robust Fuzzy Search with Version Sorting
    #    This handles: NameV10.sh, Namev2.5 - fix.sh, NameV12.432.3.sh
    # ----------------------------------------------------------------
    else
        local matches
        # Use mapfile to capture the output of the complex pipeline
        mapfile -t matches < <(
            find "$toolkit_dir" -maxdepth 1 -type f -iname "${script_pattern}*.sh" \
            | grep -Ei '[Vv][0-9]+(\.[0-9]+)*' \
            | sed -E 's|.*[Vv]([0-9]+(\.[0-9]+)*)|\1\t&|' \
            | sort -V \
            | tail -n 1 \
            | cut -f2-
        )

        # If grep/sort found something, matches[0] is the winner
        if [ ${#matches[@]} -gt 0 ] && [ -n "${matches[0]}" ]; then
            script_path="${matches[0]}"
        else
            err "No script matching '$script_pattern' found in $toolkit_dir"
            return 1
        fi
    fi

    # ----------------------------------------------------------------
    # 3. Execution & Permission Fixes
    # ----------------------------------------------------------------
    if [ ! -f "$script_path" ]; then
        err "Resolved script path does not exist: $script_path"
        return 1
    fi

    if [ ! -x "$script_path" ]; then
        warn "Script '$(basename "$script_path")' is not executable. Attempting to fix permissions..."
        chmod +x "$script_path" || err "Could not set execute permissions on '$script_path'"
    fi

    log "Executing $(basename "$script_path")..."
    "$script_path"
}

verify_os() {
    # log "Verifying Operating System..."

    if [ ! -f /etc/os-release ]; then
        err "Cannot determine OS version: /etc/os-release not found. Aborting."
    fi

    # Source the os-release file to get variables like ID and VERSION_ID
    . /etc/os-release

    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
        # log "System check passed: Ubuntu 24.04 LTS detected."
    # else
        # If it fails, print a detailed error message before exiting.
        echo ""
        echo -e "  \e[31m[X] Incompatible Operating System Detected.\e[0m"
        echo "  --------------------------------------------------------"
        echo -e "  \e[33mExpected:\e[0m Ubuntu 24.04 LTS"
        echo -e "  \e[31mFound:\e[0m    $PRETTY_NAME"
        echo "  --------------------------------------------------------"
        # Now use the 'err' function to print the final message and exit.
        err "This toolkit is designed exclusively for Ubuntu 24.04 to ensure stability."
    fi
}

# --- Documentation Pages ---
show_docs_main() {
    while true; do
        show_logo
        printf "  \e[1;37m%s\e[0m\n" "Documentation & User Guides"
        echo "==================================================================================="
        echo ""
        printf "  \e[1;37m%-15s\e[0m\n" "The Workflow"
        echo "  [1] Step 1: Secure Core VPS Setup (The Foundation)"
        echo "  [2] Step 2: Create Project (The Architect)"
        echo "  [3] Step 3: Manage App (The Project Manager)"
        echo "  [4] Step 4: Server Maintenance (The Operator)"
        echo ""
        printf "  \e[1;37m%-15s\e[0m\n" "Guides & Reference"
        echo "  [5] The 'Big Picture': How It All Works Together"
        echo "  [6] How to Use the Generated API"
        echo "  [7] Full API Reference"
        echo "  [8] Manual Commands & Emergency Cheatsheet"
        echo "  [9] About & The Toolkit Philosophy"
        echo ""
        echo "==================================================================================="
        printf "  \e[36m[B]\e[0m Back to Main Menu\n"
        echo "==================================================================================="
        prompt "Your choice: " choice

        case $choice in
            1) docs_secure_vps ;;
            2) docs_create_project ;;
            3) docs_manage_app ;;
            4) docs_server_maintenance ;;
            5) docs_big_picture ;;
            6) docs_how_to_use_api ;;
            7) docs_api_reference ;;
            8) docs_manual_commands ;;
            9) docs_philosophy ;;
            [Bb]) return 0 ;;
            *) warn "Invalid choice."; pause ;;
        esac
    done
}

docs_secure_vps() {
        show_logo
        log "Documentation: Secure Core VPS Setup"
        
        echo -e "${WHITE}I. PURPOSE${RESET}"
        echo -e "This script transforms a generic, vulnerable server into a hardened fortress."
        echo -e "It is idempotent, meaning you can run it multiple times safely."
        echo ""

        echo -e "${WHITE}II. KEY FEATURES (FIRST RUN)${RESET}"
        echo -e "  ${GREEN}1. Installation:${RESET} Upgrades OS, installs NGINX, UFW, Fail2Ban, Certbot, LiteCLI."
        echo -e "  ${GREEN}2. User Setup:${RESET} Creates a 'deploy' user with sudo access and SSH keys."
        echo -e "  ${GREEN}3. SSH Hardening:${RESET} Disables root login, disables passwords, changes port (default 2222)."
        echo -e "  ${GREEN}4. Firewall:${RESET} UFW enables only SSH and HTTP/HTTPS ports."
        echo -e "  ${GREEN}5. Security:${RESET} Enables Unattended Upgrades and configures Fail2Ban jails."
        echo -e "  ${GREEN}6. Privacy:${RESET} Configures NGINX 'Black Hole' to drop traffic to unknown domains (Error 444)."
        echo -e "  ${GREEN}7. Audit:${RESET} Runs a full 'Lynis' security scan."

        echo ""
        echo -e "${WHITE}III. DASHBOARD MODE (SUBSEQUENT RUNS)${RESET}"
        echo -e "If the server is already secured, the script opens a management menu:"
        echo -e "  ${BLUE}[1] Re-run Hardening:${RESET} Updates packages and re-applies security rules."
        echo -e "  ${BLUE}[2] Add Admin User:${RESET} Safely adds new sudo users with SSH keys."
        echo -e "  ${BLUE}[3] Delete Admin User:${RESET} Removes a user and their home directory."
        
        echo ""
        pause
}

docs_create_project() {
        show_logo
        log "Documentation: Create Project"
        
        echo -e "${WHITE}I. PURPOSE${RESET}"
        echo -e "The 'Architect'. Scaffolds high-performance, secure backend code and infrastructure."
        echo -e "It handles the boring setup so you can focus on code."
        echo ""

        echo -e "${WHITE}II. GENERATED COMPONENTS${RESET}"
        echo -e "  ${GREEN}1. Auth Service (Port 8100+):${RESET}"
        echo -e "     - Magic Link login (via Resend)."
        echo -e "     - JWT Session management."
        echo -e "     - Endpoints: /login, /verify, /me, /public-profile."
        
        echo -e "  ${GREEN}2. Database Service (Port 8101+):${RESET}"
        echo -e "     - Flexible Content API (SQLite)."
        echo -e "     - Endpoints: /create, /listall, /search, /delete (User-owned data)."
        
        echo -e "  ${GREEN}3. Storage Service (Port 8102+):${RESET}"
        echo -e "     - Secure file uploads with sanitized filenames."
        echo -e "     - Endpoints: /upload, /download/{id}, /list."
        
        echo -e "  ${GREEN}4. App Service (Port 8103+):${RESET}"
        echo -e "     - A blank canvas for your custom business logic."
        
        echo -e "  ${GREEN}5. Website:${RESET}"
        echo -e "     - Standard NGINX host for your static frontend (React/Vue/HTML)."

        echo ""
        echo -e "${WHITE}III. INFRASTRUCTURE${RESET}"
        echo -e "  - ${BLUE}Isolation:${RESET} Dedicated system user and Python venv for each project."
        echo -e "  - ${BLUE}Logs:${RESET} Dedicated NGINX access/error logs per project."
        echo -e "  - ${BLUE}Rotation:${RESET} Dual logrotate policy (7 days for app logs, 6 months for NGINX)."
        echo -e "  - ${BLUE}Manifest:${RESET} Creates 'project.conf' to track configuration."

        echo ""
        echo -e "${WHITE}IV. RESTORE MODE${RESET}"
        echo -e "  - Select '[R] Restore' to rebuild a project from a backup archive."
        echo -e "  - Supports restoring from a **Local File** or a **URL**."
        
        echo ""
        pause
}

docs_manage_app() {
        show_logo
        log "Documentation: Manage App"
        
        echo -e "${WHITE}I. PURPOSE${RESET}"
        echo -e "The 'Daily Driver'. Manages the lifecycle of a single application."
        echo ""

        echo -e "${WHITE}II. KEY WORKFLOWS${RESET}"
        echo -e "  ${BLUE}[D/U] Deploy Code:${RESET}"
        echo -e "      - **Local:** Rsyncs code from a folder on the server."
        echo -e "      - **URL:** Downloads and extracts a zip (e.g. GitHub Release)."
        echo -e "      - *Smart:* Preserves 'venv' and '.db' files automatically."
        
        echo -e "  ${BLUE}[C] Edit NGINX:${RESET}"
        echo -e "      - Opens the config in nano."
        echo -e "      - **Safety:** Runs 'nginx -t' before reloading to prevent crashes."
        
        echo -e "  ${BLUE}[E] Edit .env:${RESET}"
        echo -e "      - Securely change API Keys or Secrets."
        echo -e "      - prompts to restart the service immediately after saving."

        echo -e "  ${BLUE}[Z] Service Shell:${RESET}"
        echo -e "      - Drops you into a terminal AS the app user."
        echo -e "      - **Auto-Activates:** The Python venv is ready to use."
        echo -e "      - Use for: 'pip install', database migrations, manual scripts."

        echo -e "  ${BLUE}[DB] Explore Database:${RESET}"
        echo -e "      - Opens 'litecli' (SQL client) for the project's SQLite files."

        echo -e "  ${BLUE}[J] Rotate JWT:${RESET}"
        echo -e "      - Emergency tool. Generates new signing keys."
        echo -e "      - **Effect:** Logs out ALL users immediately."

        echo ""
        echo -e "${WHITE}III. LOGS & DEBUGGING${RESET}"
        echo -e "  - **Live Logs:** Stream stdout/stderr from the backend service."
        echo -e "  - **NGINX Logs:** Filter by Frontend vs Backend, Access vs Error."
        
        echo ""
        pause
}

docs_server_maintenance() {
        show_logo
        log "Documentation: Server Maintenance"
        
        echo -e "${WHITE}I. PURPOSE${RESET}"
        echo -e "The 'Operator's Dashboard'. A 360-degree view of server health and utilities."
        echo ""

        echo -e "${WHITE}II. MONITORING TOOLS${RESET}"
        echo -e "  ${BLUE}htop / Resource Overview:${RESET} Real-time CPU, RAM, and Load Average."
        echo -e "  ${BLUE}ncdu:${RESET} Interactive disk usage analyzer. Find large files fast."
        echo -e "  ${BLUE}Netstat / Ports:${RESET} See exactly which ports are open and listening."
        echo -e "  ${BLUE}Network Analysis:${RESET} View active connections by IP count (detect DDoS/Spikes)."

        echo ""
        echo -e "${WHITE}III. FILE OPERATIONS${RESET}"
        echo -e "  ${BLUE}Midnight Commander (mc):${RESET} Visual file manager (like Finder/Explorer)."
        echo -e "  ${BLUE}Upload Helper:${RESET} Select ANY file/folder, zip it (if needed), and upload to transfer service."
        echo -e "  ${BLUE}Download URL:${RESET} Wget wrapper to fetch files into a clean downloads folder."
        echo -e "  ${BLUE}Inode Usage:${RESET} Diagnose 'Disk Full' errors caused by too many small files."

        echo ""
        echo -e "${WHITE}IV. CONFIGURATION & SECURITY${RESET}"
        echo -e "  ${BLUE}Journal & Alerts:${RESET} View system logs or setup a Webhook for error notifications."
        echo -e "  ${BLUE}Fail2Ban:${RESET} View banned IPs and unban them."
        echo -e "  ${BLUE}Backup Retention:${RESET} Set a policy to auto-delete backups older than X days."
        echo -e "  ${BLUE}Backup ALL:${RESET} Create a master disaster-recovery archive of /var/www."

        echo ""
        pause
}

docs_big_picture() {
    show_logo
    log "The Big Picture: How Launchpad Fits Together"

    printf "\n"
    printf " \e[36m%s\e[0m\n" "A Structured, Sequential Workflow"
    printf " %s\n" "KCstudio Launchpad is not a random collection of tools."
    printf " %s\n" "It is designed as a clear lifecycle for running applications on a VPS."

    printf "\n \e[33m%s\e[0m\n" "Step 1: Secure the Foundation (Once per Server)"
    printf "   \e[35m->\e[0m %s\n" "Tool: SecureCoreVPS-Setup"
    printf "   \e[35m->\e[0m %s\n" "Outcome: A hardened, known-good baseline with secure access and updates."

    printf "\n \e[33m%s\e[0m\n" "Step 2: Architect Applications (Once per Project)"
    printf "   \e[35m->\e[0m %s\n" "Tool: CreateProject"
    printf "   \e[35m->\e[0m %s\n" "Outcome: A fully wired project with users, services, domains, and HTTPS."

    printf "\n \e[33m%s\e[0m\n" "Step 3: Manage Projects (Daily Operations)"
    printf "   \e[35m->\e[0m %s\n" "Tool: ManageApp"
    printf "   \e[35m->\e[0m %s\n" "Outcome: Safe deployments, log access, backups, and configuration changes."

    printf "\n \e[33m%s\e[0m\n" "Step 4: Operate the Server (As Needed)"
    printf "   \e[35m->\e[0m %s\n" "Tool: ServerMaintenance"
    printf "   \e[35m->\e[0m %s\n" "Outcome: Visibility and control over the host itself."

    printf "\n"
    printf " %s\n" "Each step builds on the previous one."
    printf " %s\n" "The result is predictability, isolation, and confidence."
    printf " %s\n" "Even when running many projects on a single machine."

    echo ""
    pause
}

docs_how_to_use_api() {
    show_logo
    log "Guide: How to Use the Generated API"
    printf "\e[36m%s\e[0m\n" "--- I. WHAT IS AN API? ---"
    printf " %s\n" "An API (Application Programming Interface) is a set of rules that allows your"
    printf " %s\n" "frontend (like a React or Vue app) to talk to your backend services."
    printf " %s\n" "Your frontend sends requests (e.g., 'get me this user's data'), and the API"
    printf " %s\n" "sends back responses (usually in a format called JSON)."

    printf "\n\e[36m%s\e[0m\n" "--- II. TESTING WITH CURL ---"
    printf " %s\n" "\`curl\` is a command-line tool for making web requests. It's perfect for testing."
    printf " %s\n" "Let's say your API domain is \`api.example.com\`. Here's how to test a public endpoint:"
    printf "   \e[35m$\e[0m \e[32mcurl https://api.example.com/v1/app/public-info\e[0m\n"
    printf "   \e[90m=> {\"message\":\"This is a public endpoint...\"}\e[0m\n"

    printf "\n\e[36m%s\e[0m\n" "--- III. AUTHENTICATION: TWO TYPES OF KEYS ---"
    printf " %s\n" "Your API has two levels of security:"
    printf "  \e[33m1. JWT (JSON Web Token)\e[0m: %s\n" "A temporary key for a specific user's session."
    printf "     - \e[90m%s\e[0m\n" "This is what your frontend uses after a user logs in."
    printf "     - \e[90m%s\e[0m\n" "You send it in a special 'Authorization' header."
    printf "   \e[35m$\e[0m \e[32mcurl -H \"Authorization: Bearer <your_jwt_here>\" https://api.example.com/v1/app/user/secret-data\e[0m\n"
    printf "  \e[33m2. Admin API Key\e[0m: %s\n" "A permanent, powerful key for server-to-server tasks."
    printf "     - \e[90m%s\e[0m\n" "NEVER use this in a public frontend. It has admin privileges."
    printf "     - \e[90m%s\e[0m\n" "You send it in a special 'X-Admin-API-Key' header."
    printf "   \e[35m$\e[0m \e[32mcurl -H \"X-Admin-API-Key: <your_admin_key_here>\" https://api.example.com/v1/app/admin/system-status\e[0m\n"
    printf "\n %s\n" "You can find your Admin API keys using the 'Manage App' script."
    echo ""
    pause
}

_display_styled_api_reference() {
    (
    printf "\n"
    printf "  \e[1;36m%s\e[0m\n" "🚀 KCStudio Launchpad API Reference"
    printf "  %s\n" "A comprehensive reference for all auto-generated API endpoints."
    printf "  %s\n" "Check launchpad.kcstudio.nl/api-docs for full documentation."
    printf "\n"
    printf "  \e[1;33m%s\e[0m\n" "General Notes"
    printf "  \e[90m%s\e[0m\n" "----------------------------------------------------------------"
    printf "  \e[32m%s\e[0m \e[37m%s\e[0m\n" "∙" "Authentication: JWT requires \`Authorization: Bearer <token>\`."
    printf "  \e[32m%s\e[0m \e[37m%s\e[0m\n" "∙" "Admin Key requires \`X-Admin-API-Key: <key>\`."
    printf "  \e[32m%s\e[0m \e[37m%s\e[0m\n" "∙" "Base URL: All paths are prefixed with \`/v1\`."
    printf "\n"
    printf "\n"

    # --- AUTH SERVICE ---
    printf "  \e[1;36m%s\e[0m\n" "/v1/auth"
    printf "  \e[37m%s\e[0m\n" "Handles user authentication, registration, and profile management."
    printf "  \e[90m%s\e[0m\n" "----------------------------------------------------------------"
    printf "    \e[1;37m%s\e[0m\n" "GET /health"
    printf "    \e[90m%s\e[0m\n" "  Checks the health of the authentication service."
    printf "    \e[1;37m%s\e[0m\n" "POST /login"
    printf "    \e[90m%s\e[0m\n" "  Initiates a passwordless \"magic link\" login process for a user."
    printf "    \e[1;37m%s\e[0m\n" "POST /verify"
    printf "    \e[90m%s\e[0m\n" "  Verifies a magic link token to complete login and issue a JWT."
    printf "    \e[1;37m%s\e[0m\n" "GET /me"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Retrieves the profile of the currently authenticated user."
    printf "    \e[1;37m%s\e[0m\n" "PUT /me"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Updates the profile of the currently authenticated user."
    printf "    \e[1;37m%s\e[0m\n" "GET /public-profile/{user_id}"
    printf "    \e[90m%s\e[0m\n" "  Retrieves the public portions of a user's profile."
    printf "    \e[1;37m%s\e[0m\n" "DELETE /delete-me"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Permanently deletes the current user's account."
    printf "\n\n"

    # --- DATABASE SERVICE ---
    printf "  \e[1;36m%s\e[0m\n" "/v1/database"
    printf "  \e[37m%s\e[0m\n" "A general-purpose data API for creating and managing structured content."
    printf "  \e[90m%s\e[0m\n" "----------------------------------------------------------------"
    printf "    \e[1;37m%s\e[0m\n" "GET /health"
    printf "    \e[90m%s\e[0m\n" "  Checks the health of the database service."
    printf "    \e[1;37m%s\e[0m\n" "GET /listall"
    printf "    \e[90m%s\e[0m\n" "  (Admin Key Auth) Retrieves all entries with admin filtering."
    printf "    \e[1;37m%s\e[0m\n" "GET /listpublic"
    printf "    \e[90m%s\e[0m\n" "  Retrieves a paginated list of 'published' entries."
    printf "    \e[1;37m%s\e[0m\n" "GET /search"
    printf "    \e[90m%s\e[0m\n" "  Searches published entries by a keyword."
    printf "    \e[1;37m%s\e[0m\n" "GET /retrieve/{slug}"
    printf "    \e[90m%s\e[0m\n" "  Retrieves a single published entry by its slug."
    printf "    \e[1;37m%s\e[0m\n" "POST /create"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Creates a new entry owned by the user."
    printf "    \e[1;37m%s\e[0m\n" "PUT /update/{slug}"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Updates an entry if the user is the owner."
    printf "    \e[1;37m%s\e[0m\n" "DELETE /delete/{slug}"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Deletes an entry if the user is the owner."
    printf "\n\n"

    # --- STORAGE SERVICE ---
    printf "  \e[1;36m%s\e[0m\n" "/v1/storage"
    printf "  \e[37m%s\e[0m\n" "Handles secure file uploads, downloads, and management."
    printf "  \e[90m%s\e[0m\n" "----------------------------------------------------------------"
    printf "    \e[1;37m%s\e[0m\n" "GET /health"
    printf "    \e[90m%s\e[0m\n" "  Checks the health of the storage service."
    printf "    \e[1;37m%s\e[0m\n" "POST /upload"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Uploads a file via multipart/form-data."
    printf "    \e[1;37m%s\e[0m\n" "GET /download/{file_id}"
    printf "    \e[90m%s\e[0m\n" "  Downloads a file publicly by its ID."
    printf "    \e[1;37m%s\e[0m\n" "GET /list"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Lists metadata for all files owned by the user."
    printf "    \e[1;37m%s\e[0m\n" "DELETE /delete/{file_id}"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) Deletes a file if the user is the owner."
    printf "\n\n"

    # --- APP SERVICE ---
    printf "  \e[1;36m%s\e[0m\n" "/v1/app"
    printf "  \e[37m%s\e[0m\n" "Your core business logic. A template for you to build upon."
    printf "  \e[90m%s\e[0m\n" "----------------------------------------------------------------"
    printf "    \e[1;37m%s\e[0m\n" "GET /health"
    printf "    \e[90m%s\e[0m\n" "  Checks the health of the main application service."
    printf "    \e[1;37m%s\e[0m\n" "GET /public-info"
    printf "    \e[90m%s\e[0m\n" "  An example public endpoint."
    printf "    \e[1;37m%s\e[0m\n" "GET /user/secret-data"
    printf "    \e[90m%s\e[0m\n" "  (JWT Auth) An example endpoint protected by user authentication."
    printf "    \e[1;37m%s\e[0m\n" "GET /admin/system-status"
    printf "    \e[90m%s\e[0m\n" "  (Admin Key Auth) An example endpoint protected by the Admin API Key."
    printf "\n"
    ) | less -R
}

docs_api_reference() {
    show_logo
    echo ""
    log "Full API Reference"
    printf " %s\n" "This is a summary of all API endpoints for the generated services."
    printf " %s\n" "For full request/response models, please see the OpenAPI .yml file."
    echo ""
    read -p "Press [Enter] to display the reference (scroll with mouse or keys, press 'q' to quit)..."
    _display_styled_api_reference
}

docs_manual_commands() {
    show_logo
    log "Documentation: Manual Commands & Emergency Cheatsheet"
    printf "\e[36m%s\e[0m\n" "--- WHEN THE BUTLER ISN'T ENOUGH ---"
    printf " %s\n" "This toolkit covers 95% of common tasks. For fine-grained control or"
    printf " %s\n" "emergencies, you need to use the command line. All commands should be run"
    printf " %s\n" "as your deploy user, using \`sudo\` when necessary."

    printf "\n\e[33m%s\e[0m\n" "Networking & Firewall"
    printf "  %-40s %s\n" "sudo ufw status verbose" "See detailed firewall rules."
    printf "  %-40s %s\n" "sudo ufw allow 5432/tcp" "Example: Open a port (e.g., for PostgreSQL)."
    printf "  %-40s %s\n" "sudo ufw delete allow 5432/tcp" "Example: Close a port."
    printf "  %-40s %s\n" "curl ifconfig.me" "Quickly find your server's public IP address."
    printf "  %-40s %s\n" "ss -tulnp" "See all listening ports and the programs using them."


    printf "\n\e[33m%s\e[0m\n" "Services & Processes"
    printf "  %-40s %s\n" "sudo systemctl status <service>" "Check if a service is running (e.g., \`nginx.service\`)."
    printf "  %-40s %s\n" "sudo journalctl -fu <service>" "Follow the live systemd journal for a service."
    printf "  %-40s %s\n" "htop" "An interactive process viewer (better than \`top\`)."

    printf "\n\e[33m%s\e[0m\n" "File System"
    printf "  %-40s %s\n" "ls -la /path/to/dir" "List files with permissions, owner, and size."
    printf "  %-40s %s\n" "sudo chown user:group /path/to/file" "Change a file's owner."
    printf "  %-40s %s\n" "sudo chmod 755 /path/to/file" "Change a file's permissions."
    printf "  %-40s %s\n" "scp -P <port> user@ip:/remote/path ." "Copy a file FROM the server."
    printf "  %-40s %s\n" "scp -P <port> local_file user@ip:/path/" "Copy a file TO the server."
    echo ""
    pause
}

docs_philosophy() {
    show_logo
    log "About & The Toolkit Philosophy"

    printf "\n"
    printf " \e[1;33m%s\e[0m\n" "Control, Not Complexity."
    printf "  %s\n" "KCstudio Launchpad exists to solve a very specific problem:"
    printf "  %s\n" "running multiple real applications on a single VPS safely and predictably."
    printf "  %s\n" "Not by abstracting the server away - but by structuring it properly."

    printf "\n"
    printf " \e[1;33m%s\e[0m\n" "Built From Repetition, Not Theory"
    printf "  %s\n" "This toolkit is the result of doing the same work over and over:"
    printf "  %s\n" "hardening servers, provisioning users, wiring services, debugging failures,"
    printf "  %s\n" "and cleaning up mistakes."
    printf "  %s\n" "Eventually, those workflows were systematized into something repeatable."

    printf "\n"
    printf " \e[1;33m%s\e[0m\n" "Host-Native by Design"
    printf "  %s\n" "Launchpad uses standard Linux primitives:"
    printf "  %s\n" "users, files, systemd, NGINX, and SSH."
    printf "  %s\n" "No containers by default - not because they are bad,"
    printf "  %s\n" "but because many projects do not require that level of indirection."

    printf "\n"
    printf " \e[1;33m%s\e[0m\n" "Automation Without Obscurity"
    printf "  %s\n" "Every action is scripted, visible, and auditable."
    printf "  %s\n" "Repetitive tasks are automated."
    printf "  %s\n" "Critical decisions are surfaced, not hidden."

    printf "\n"
    printf " \e[1;33m%s\e[0m\n" "What This Is - and What It Isn't"
    printf "  %s\n" "This is not a managed platform."
    printf "  %s\n" "It is not a multi-server orchestration system."
    printf "  %s\n" "It is a deliberate, opinionated toolkit for people who want"
    printf "  %s\n" "to own and understand their infrastructure."

    echo ""
    pause
}



# --- Main Menu Loop ---
main() {

    # Check if server is secured by KCstudio Launchpad for conditional red arrow
    local SECURE_CORE_READY=false
    [ -f "$SECURE_STATE_FILE" ] && SECURE_CORE_READY=true

    while true; do
        show_logo
        printf "%s\n" "==================================================================================="
        printf "                           \e[1;37m%s\e[0m\n" "KCStudio Launchpad V2.0"
        printf "                       \e[90m%s\e[0m\n" "The Developer's Launch Platform"
        printf "%s\n" "==================================================================================="
        printf "\n"

        # Conditional red arrow        
        if [ "$SECURE_CORE_READY" = false ]; then
            printf "  \e[36m[1]\e[0m \e[1;37mPrepare This Server For First Use\e[0m \e[31m◀ (run this first)\e[0m\n"
            printf "      \e[90m%s\e[0m\n" "(Required on a fresh VPS before using other features)"
        else
            printf "  \e[36m[1]\e[0m \e[1;37mPrepare This Server For First Use\e[0m\n"
            printf "      \e[90m%s\e[0m\n" "(Already hardened, select to manage Admins)"
        fi

        printf "\n"
        printf "  \e[36m[2]\e[0m \e[1;37mArchitect a New Full-Stack Project\e[0m\n"
        printf "      \e[90m%s\e[0m\n" "(Run for each new project you want to build)"
        printf "\n"
        printf "  \e[36m[3]\e[0m \e[1;37mManage an Existing Project\e[0m\n"
        printf "      \e[90m%s\e[0m\n" "(Deploy code, view logs, backup a specific project)"
        printf "\n"
        printf "  \e[36m[4]\e[0m \e[1;37mOperate the Server\e[0m\n"
        printf "      \e[90m%s\e[0m\n" "(Check server health, manage swap, analyze traffic, etc.)"
        printf "\n"
        printf "%s\n" "-----------------------------------------------------------------------------------"
        printf "  \e[36m[H]\e[0m Documentation & User Guides         \e[36m[Q]\e[0m Quit\n"
        printf "%s\n" "==================================================================================="
        prompt "Your choice: " main_choice

        case $main_choice in
            1) run_script "SecureCoreVPS-Setup" ; pause ;;
            2) run_script "CreateProject" ; pause ;;
            3) run_script "ManageApp" ; pause ;;
            4) run_script "ServerMaintenance" ; pause ;;
            [Hh]) show_docs_main ;;
            [Qq]) echo "Exiting." && exit 0 ;;
            *) warn "Invalid choice." ; pause ;;
        esac
    done
}

# --- Run Launch Animation Once ---
launch_kcstudio
verify_os
sleep 0.5

# --- Execute Main ---
main