#!/bin/bash

# === KCStudio Launchpad - Secure Core VPS Setup ===
# Copyright (c) 2026 Kelvin Deen - KCStudio.nl

set -euo pipefail
IFS=$'\n\t'

# --- Constants ---
SECURE_STATE_FILE="/etc/kcstudio/secure_core.state"
TOOLKIT_VERSION="v2.0"

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
die() { echo -e "\n${RED}[X]${RESET} Error: $1" >&2; exit 1; }
err() { echo -e "\n${RED}[X]${RESET} $1" >&2; exit 1; }
prompt() { read -rp "$(echo -e "${BLUE}[?]${RESET} $1 ")" "$2"; }
pause() { echo ""; read -rp "Press [Enter] to continue..."; }


# --- Root Enforcement ---
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo ""
    echo ""
    warn "This script must be run as root to use & enjoy all its features flawlessly."
    echo -e "Please \e[1mrun\e[0m it \e[1magain\e[0m with:"
    echo ""
    echo -e "  ${BLUE}sudo $(basename "$0")${RESET}"
    echo ""
    echo ""
    echo ""
    exit 1
fi

# --- State Management Functions ---
mark_setup_complete() {
    log "Finalizing setup state..."
    # Create the directory if it doesn't exist
    mkdir -p "$(dirname "$SECURE_STATE_FILE")"
    
    # Write state info to file
    cat <<EOF > "$SECURE_STATE_FILE"
SETUP_VERSION=$TOOLKIT_VERSION
SETUP_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATUS=COMPLETE
EOF
    # Secure the file so it's readable but not writable by others
    chmod 644 "$SECURE_STATE_FILE"
    log_ok "System marked as secured ($TOOLKIT_VERSION)."
}

check_setup_state() {
    if [ -f "$SECURE_STATE_FILE" ]; then
        return 0 # True, file exists
    else
        return 1 # False
    fi
}

# --- OS Verification Function ---
verify_os() {
    log "Verifying Operating System..."

    if [ ! -f /etc/os-release ]; then
        err "Cannot determine OS version: /etc/os-release not found. Aborting."
    fi

    # Source the os-release file to get variables like ID and VERSION_ID
    # This is safe as it's a standard system file.
    . /etc/os-release

    if [ "$ID" == "ubuntu" ] || [ "$VERSION_ID" == "24.04" ]; then
        log_ok "System check passed: Ubuntu 24.04 LTS detected."
    else
        # If it fails, print a detailed error message before exiting.
        echo ""
        echo -e "  ${RED}[X] Incompatible Operating System Detected.${RESET}"
        echo "  --------------------------------------------------------"
        echo -e "  ${YELLOW}Expected:${RESET} Ubuntu 24.04 LTS"
        echo -e "  ${RED}Found:${RESET}    $PRETTY_NAME"
        echo "  --------------------------------------------------------"
        # Now use the 'err' function to print the final message and exit.
        err "This toolkit is designed exclusively for Ubuntu 24.04 to ensure stability."
    fi
}

# --- Configuration ---
# A list of Cloudflare's IP ranges to correctly identify visitor IPs.
# Updated from https://www.cloudflare.com/ips/
CLOUDFLARE_IPS_V4=(
    "173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22" "103.31.4.0/22"
    "141.101.64.0/18" "108.162.192.0/18" "190.93.240.0/20" "188.114.96.0/20"
    "197.234.240.0/22" "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/13"
    "104.24.0.0/14" "172.64.0.0/13" "131.0.72.0/22"
)
CLOUDFLARE_IPS_V6=(
    "2400:cb00::/32" "2606:4700::/32" "2803:f800::/32" "2405:b500::/32"
    "2405:8100::/32" "2a06:98c0::/29" "2c0f:f248::/32"
)


# --- Setup Functions ---
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

system_setup() {
    log "Updating system and installing core packages..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y upgrade
    # Added ssl-cert for generating snakeoil certificates for NGINX 443 catch-all
    apt-get -y install nginx fail2ban lynis unattended-upgrades ufw curl git tree \
      software-properties-common certbot python3-certbot-nginx sqlite3 python3-venv litecli ssl-cert
    log_ok "System packages are up to date."
}

# --- Time Sync Check ---
check_ntp() {
    log "Checking time synchronization (NTP)..."

    if timedatectl show --property=NTPSynchronized | grep -q yes; then
        log_ok "Time synchronization is active."
    else
        warn "Time is NOT synchronized. This may break SSL issuance or cause token validation errors."
        echo "Attempting to enable NTP with: sudo timedatectl set-ntp true"

        if sudo timedatectl set-ntp true; then
            sleep 2
            if timedatectl show --property=NTPSynchronized | grep -q yes; then
                log_ok "Time synchronization is now active."
            else
                warn "NTP enable command ran, but time is still not syncing."
                echo "Run this manually to debug:"
                echo "  sudo timedatectl status"
                echo "  sudo systemctl restart systemd-timesyncd"
            fi
        else
            warn "Failed to run 'timedatectl set-ntp true'. Check if systemd-timesyncd is installed."
        fi
    fi

    log "NTP check completed."
}

# --- Certbot Pre-Registration ---
setup_certbot() {
    log "Pre-configuring Certbot for domain SSL automation..."

    if compgen -G "/etc/letsencrypt/accounts/*/*/regr.json" > /dev/null; then
        log_ok "Certbot is already registered. Skipping setup."
        return
    fi

    echo ""
    echo "To enable automatic HTTPS setup in future projects, Certbot must be registered now."
    echo "You must agree to the Let's Encrypt Terms of Service:"
    echo "  https://letsencrypt.org/repository/"
    prompt "Do you agree to the Let's Encrypt Terms of Service? [y/N]:" AGREE_TOS

    if [[ "$AGREE_TOS" != [yY] ]]; then
        die "Please agree to the Let's Encrypt Terms of Service to continue. Not having this will break future projects."
    fi

    prompt "Enter your email for Let's Encrypt (used for renewal notices):" CERTBOT_EMAIL

    if [ -z "$CERTBOT_EMAIL" ]; then
        warn "No email provided. Certbot will not be pre-registered. You must run 'certbot register' manually before creating projects."
    else
        if certbot register --agree-tos --no-eff-email -m "$CERTBOT_EMAIL"; then
            log_ok "Certbot is now pre-registered with Let's Encrypt. You can now create projects using KCstudio Launchpad."
        else
            warn "Certbot registration may have failed. You need to run 'certbot register' manually before using KCstudio Launchpad to create projects."
        fi
    fi
}


user_setup() {
    local deploy_user=$1
    log "Setting up deployment user '$deploy_user'..."
    if id "$deploy_user" &>/dev/null; then
        log_ok "User '$deploy_user' already exists."
    else
        adduser --disabled-password --gecos "" "$deploy_user"
        log_ok "User '$deploy_user' created."
    fi
    usermod -aG sudo "$deploy_user"
    log_ok "User '$deploy_user' added to sudo group."

    echo "$deploy_user ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/90-$deploy_user"
    chmod 440 "/etc/sudoers.d/90-$deploy_user"
    log_ok "Configured passwordless sudo for '$deploy_user'."

    local ssh_dir="/home/$deploy_user/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    if [ -f "$auth_keys_file" ] && [ -s "$auth_keys_file" ]; then
        log_ok "SSH key already exists for '$deploy_user'. Skipping key setup."
        return
    fi
    
    warn "An SSH public key is required for the '$deploy_user' user."
    echo "This key will be used for all future logins. Password login will be disabled."
    echo "If you don't have a key, generate one on your local machine now."
    echo "You can copy the following commands, depening the OS you are currently using."
    echo ""
    echo -e "  ${BLUE}On Linux/macOS:${RESET}"
    echo "    ssh-keygen -t ed25519 -C \"$deploy_user@vps\" -f ~/.ssh/${deploy_user}_vps_key"
    echo "    cat ~/.ssh/${deploy_user}_vps_key.pub"
    echo ""
    echo -e "  ${BLUE}On Windows (PowerShell):${RESET}"
    echo "    ssh-keygen -t ed25519 -C \"$deploy_user@vps\" -f \$env:USERPROFILE\\.ssh\\${deploy_user}_vps_key"
    echo "    Get-Content \$env:USERPROFILE\\.ssh\\${deploy_user}_vps_key.pub"
    echo ""
    echo ""
    
    local public_key
    prompt "Paste your single-line PUBLIC key now (starts with 'ssh-ed25519 AAAA...'):" public_key

    if [ -z "$public_key" ]; then
        die "No public key was provided. Aborting."
    fi
    
    echo "$public_key" > "$auth_keys_file"
    chmod 600 "$auth_keys_file"
    chown -R "$deploy_user:$deploy_user" "$ssh_dir"
    log_ok "SSH public key has been added for '$deploy_user'."
}

ssh_hardening() {
    local deploy_user=$1
    local ssh_port=$2
    log "Verifying SSH key and hardening configuration..."
    
    warn "Please open a NEW terminal and test your SSH key login now."
    echo "The server has NOT been locked down yet. Use the standard port (22) for this test."
    echo "This is the most important step! Do not proceed if it fails."
    echo -e "Run this command from your local machine, replacing the path to your private key:"
    echo -e "  ${BLUE}ssh -i '/path/to/your/private_key' $deploy_user@SERVER_IP${RESET}"
    prompt "Did the SSH login for user '$deploy_user' succeed? [y/N]" confirm_ssh
    if [[ "$confirm_ssh" != [yY] ]]; then
    echo ""
    warn "SSH key login test failed."
    echo -e "  ${RED}[X]${RESET} Make sure:"
    echo "    • You copied the *entire* public key (starting with 'ssh-ed25519' or 'ssh-rsa')"
    echo "    • The correct private key is used with the ssh command"
    echo "    • Your local firewall or ISP is not blocking outbound SSH (port 22)"
    echo "    • The server's firewall (UFW) has not prematurely enabled rules"
    echo ""
    echo "🔍 You can test connectivity with:"
    echo -e "  ${BLUE}nmap SERVER_IP -p 22${RESET}   (or the custom port if changed)"
    echo ""
    echo "🛠 Still stuck?"
    echo "    • Try restarting the VPS (if firewall rules are stuck)"
    echo "    • Try using the default 22 port"
    echo "    • Try using a different SSH key"
    echo ""
    die "Aborting script. Please fix SSH access for '$deploy_user' and run again."
    fi
    log_ok "SSH key confirmed! Proceeding with server lockdown."

    local sshd_config="/etc/ssh/sshd_config"
    local temp_config
    temp_config=$(mktemp)
    cp "$sshd_config" "$temp_config"

    sed -i "s/^#*Port .*/Port $ssh_port/" "$temp_config"
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/" "$temp_config"
    sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication no/" "$temp_config"
    sed -i "s/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/" "$temp_config"
    sed -i "s/^#*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/" "$temp_config"
    sed -i "s/^#*UsePAM .*/UsePAM yes/" "$temp_config"
    
    if ! grep -q "KexAlgorithms" "$temp_config"; then
        echo "" >> "$temp_config"
        echo "# Modern, secure cryptographic algorithms to protect the connection." >> "$temp_config"
        echo "KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256" >> "$temp_config"
        echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >> "$temp_config"
        echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com" >> "$temp_config"
    fi

    # If the ssh service isn't running, the /run/sshd directory won't exist.
    # sshd -t (test mode) requires this directory to validate privilege separation.
    # could potentionally be replaced with "systemd-tmpfiles --create /usr/lib/tmpfiles.d/openssh-server.conf"
    if [ ! -d "/run/sshd" ]; then
        mkdir -p /run/sshd
        chmod 0755 /run/sshd
    fi

    sshd -t -f "$temp_config" || die "New sshd_config failed validation, please try running this script again."
    
    mv "$temp_config" "$sshd_config"
    
    # Use the systemd-recommended procedure to apply port changes
    systemctl daemon-reload
    systemctl restart ssh.socket ssh.service
    log_ok "SSH has been hardened and moved to port $ssh_port."
}

firewall_setup() {
    local ssh_port=$1
    log "Configuring UFW firewall..."
    # Reset to ensure a clean state, preventing rule buildup
    ufw --force reset
    
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "$ssh_port/tcp" comment 'Custom SSH Port'
    ufw allow 'Nginx Full' comment 'Web Traffic (HTTP/HTTPS)'
    ufw --force enable
    log_ok "Firewall is enabled and configured with minimal rules."
    
    log "Configuring Fail2Ban for SSH protection..."
    local jail_local="/etc/fail2ban/jail.local"
    # Overwrite the file to ensure the port is correct on every run
    {
        echo "[DEFAULT]"
        echo "bantime = 1d"
        echo "maxretry = 3"
        echo ""
        echo "[sshd]"
        echo "enabled = true"
        echo "port = $ssh_port"
    } > "$jail_local"
    systemctl restart fail2ban
    log_ok "Fail2Ban configured for SSH on port $ssh_port."
}

nginx_hardening() {
    log "Hardening NGINX with modular configuration..."

    local globals_file="/etc/nginx/conf.d/00-kcstudio-globals.conf"
    cat <<EOF > "$globals_file"
# === KCStudio Global NGINX Settings ===
# This file contains global settings that apply to all sites.

EOF
    if ! grep -q -E "^\s*server_tokens\s+off;" /etc/nginx/nginx.conf; then
        echo "# Security: Conceal NGINX version number from error pages and headers." >> "$globals_file"
        echo "server_tokens off;" >> "$globals_file"
        echo "" >> "$globals_file"
    fi

    cat <<EOF >> "$globals_file"
# Limits: Set a reasonable default for maximum upload size.
# This can be overridden on a per-site basis if larger uploads are needed.
client_max_body_size 100M;

# Performance: Gzip compression settings.
# gzip on; # should be on by default in nginx.conf otherwise uncomment it
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_min_length 256;
gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/json application/xml application/xml+rss application/atom+xml application/font-woff application/font-woff2 font/woff2 image/svg+xml;

# Performance: Define buffer sizes for proxied connections to backend apps.
proxy_buffering on;
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;

# Performance Tuning: Advanced log format.
# Uncomment the following two lines to enable detailed timing information
# in your NGINX access logs. This is useful for debugging slow requests.
# log_format main_ext '\$remote_addr - \$remote_user [\$time_local] "\$request" '
#                    '\$status \$body_bytes_sent "\$http_referer" '
#                    '"\$http_user_agent" "\$http_x_forwarded_for" '
#                    'rt=\$request_time uct=\$upstream_connect_time uht=\$upstream_header_time urt=\$upstream_response_time';
# access_log /var/log/nginx/access.log main_ext;
EOF
    log_ok "Created global settings file."

    local cloudflare_file="/etc/nginx/conf.d/01-cloudflare-real-ip.conf"
    {
      echo "# Cloudflare Real IP Support"
      echo "# Ensures NGINX logs the real visitor IP address, not Cloudflare's."
      for ip in "${CLOUDFLARE_IPS_V4[@]}"; do echo "set_real_ip_from $ip;" ; done
      for ip in "${CLOUDFLARE_IPS_V6[@]}"; do echo "set_real_ip_from $ip;" ; done
      echo "" 
      echo "real_ip_header CF-Connecting-IP;"
    } > "$cloudflare_file"
    log_ok "Created Cloudflare Real-IP config."

    local ssl_params_file="/etc/nginx/snippets/ssl-params.conf"
    cat <<EOF > "$ssl_params_file"
# Modern, secure SSL/TLS parameters.
# Based on Mozilla Intermediate configuration: https://ssl-config.mozilla.org/
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;

# Use TLSv1.2 and the modern TLSv1.3 for wide compatibility and security.
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;
EOF
    log_ok "Created modern SSL parameters snippet."

    local sec_headers_file="/etc/nginx/snippets/security-headers.conf"
    cat <<EOF > "$sec_headers_file"
# Common security headers to protect against clickjacking, content type sniffing, etc.
# add_header X-Frame-Options "SAMEORIGIN" always; // commented out for now as it can break backend apps
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
# The HSTS header is best managed by Certbot via the --redirect flag.
EOF
    log_ok "Created security headers snippet."

    local catch_all_file="/etc/nginx/sites-available/000-catch-all"
    cat <<EOF > "$catch_all_file"
# This is the catch-all server block. It handles any requests to hostnames
# that are not explicitly configured on this server, including direct IP access.
# It returns a 444 (Connection Closed Without Response) to make the server
# less visible to automated scanners.

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 444;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;

    server_name _;

    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    return 444;
}
EOF
    if [ ! -L "/etc/nginx/sites-enabled/000-catch-all" ]; then
        ln -s "$catch_all_file" /etc/nginx/sites-enabled/
    fi
    rm -f /etc/nginx/sites-enabled/default
    log_ok "Configured 'black hole' default server."

    [ -d /var/www/html ] && sudo rm -r /var/www/html
    log_ok "Removed default NGINX files."
    
    if ! nginx -t; then
      warn "NGINX configuration test failed. Please review errors."
    fi

    systemctl reload nginx
    log_ok "NGINX configuration reloaded."
}

enable_unattended_security_updates() {
    log "Enabling unattended security updates..."
    {
      echo 'APT::Periodic::Update-Package-Lists "1";';
      echo 'APT::Periodic::Unattended-Upgrade "1";';
      echo 'APT::Periodic::AutocleanInterval "7";';
    } > /etc/apt/apt.conf.d/20auto-upgrades
    log_ok "Automatic security updates enabled."
}

lynis_audit() {
    log "Running Lynis security audit (this may take a minute)..."
    local report_file="/root/lynis-report-$(date +%Y%m%d).txt"
    lynis audit system --quiet --no-colors > "$report_file"
    log_ok "Lynis audit complete. Report saved to $report_file"
    warn "Review important suggestions from Lynis:"
    grep -E "Suggestion|Warning" "$report_file" | cut -c 2- || echo "  No high-priority suggestions or warnings found."
}

# --- Detection Logic ---
get_human_users() {
    # Returns a list of users who have directories in /home, excluding lost+found
    if [ -d "/home" ]; then
        ls -1 /home | grep -v "lost+found" || true
    fi
}

count_human_users() {
    get_human_users | wc -l
}

# --- Action Routines ---

# Routine to just add a user (for the "Add User" menu option)
add_new_user() {
    local DEPLOY_USER
    
    echo ""
    log "--- User Creation Wizard ---"
    prompt "Enter the desired username for the new admin/deploy user:" DEPLOY_USER
    
    if [ -z "$DEPLOY_USER" ]; then die "Username cannot be empty."; fi

    user_setup "$DEPLOY_USER"

    # Reminder to test login
    local ssh_port
    ssh_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
    echo ""
    warn "IMPORTANT: Test the new user login before closing this session!"
    echo -e "  ${BLUE}ssh -p $ssh_port -i /path/to/key $DEPLOY_USER@SERVER_IP${RESET}"
}

# Routine to delete a user (for the "Delete User" menu option)
delete_a_user() {
    echo ""
    log "--- Delete User Wizard ---"
    
    local users
    users=($(get_human_users))
    
    if [ ${#users[@]} -eq 0 ]; then
        warn "No human users found to delete."
        return
    fi

    echo "Existing users:"
    echo ""
    local i=1
    for u in "${users[@]}"; do
        echo "  [$i] $u"
        ((i++))
    done

    echo ""
    prompt "Select number of user to DELETE (empty to cancel):" choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#users[@]} ]; then
        log "Cancelled."
        return
    fi

    local target_user="${users[$((choice-1))]}"
    
    # Safety Check
    if [ "$target_user" == "root" ]; then die "Cannot delete root."; fi
    
    warn "WARNING: You are about to permanently delete user '$target_user' and their /home directory."
    prompt "Are you absolutely sure? Type the username to confirm:" confirm_name

    if [ "$confirm_name" == "$target_user" ]; then
        log "Deleting user '$target_user'..."
        
        # Remove sudoers file first
        if [ -f "/etc/sudoers.d/90-$target_user" ]; then
            rm "/etc/sudoers.d/90-$target_user"
            log "Removed sudoers configuration."
        fi

        # Kill processes
        pkill -u "$target_user" || true
        
        # Delete user and home
        deluser --remove-home "$target_user"
        log_ok "User '$target_user' deleted."
    else
        warn "Confirmation failed. Aborting deletion."
    fi
}

# Main logic, wrapped in a function for reuse in menus
run_full_hardening() {
    log "Starting Secure VPS Setup..."
    echo "This script will perform a full, secure setup of this server."
    echo "It focuses on the essentials to create a stable and secure foundation."
    read -p "$(echo -e "${BLUE}[?]${RESET} Press [Enter] to begin the setup. ")"

    verify_os
    system_setup
    check_ntp
    setup_certbot

    log "Moving on to SSH setup..."
    
    local DEPLOY_USER SSH_PORT
    prompt "Enter the desired username for the administrative/deploy user [default: deploy]:" DEPLOY_USER
    DEPLOY_USER=${DEPLOY_USER:-deploy}
    
    echo ""
    warn "The default SSH port (22) is a constant target for bots."
    echo "It is highly recommended to use a different port (e.g., above 1024)."
    prompt "Enter the desired SSH port [default: 2222]:" SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}
    
    user_setup "$DEPLOY_USER"
    ssh_hardening "$DEPLOY_USER" "$SSH_PORT"
    firewall_setup "$SSH_PORT"
    nginx_hardening
    enable_unattended_security_updates

    echo ""
    warn "The next step is to run a full Lynis security audit."
    echo "This scan verifies the server's hardened state but can take a minute or two."
    
    prompt "Run the security audit now? (This is recommended for the first time) [Y/n]:" RUN_LYNIS_CONFIRM
    if [[ -z "$RUN_LYNIS_CONFIRM" || "$RUN_LYNIS_CONFIRM" == [yY] || "$RUN_LYNIS_CONFIRM" == [yY][eE][sS] ]]; then
        lynis_audit
    else
        log "Skipping Lynis audit."
        echo "You can always run a new audit later from the 'ServerMaintenance' toolkit."
    fi
    
    # Leave a mark of success
    mark_setup_complete
    
    log "✅ Secure VPS setup complete!"
    warn "A reboot is recommended to apply all kernel and system changes."
    
    echo ""
    echo -e "\e[1;37m--- CRITICAL: NEW LOGIN DETAILS ---\e[0m"
    printf "Your server is now hardened. Password login is disabled.\n"
    printf "➡ Your new SSH port is: \e[1;33m%s\e[0m\n" "$SSH_PORT"
    printf "➡ Log in as the new user: \e[1;33m%s\e[0m\n" "$DEPLOY_USER"
    echo ""
    echo "Use this command from YOUR LOCAL machine to log back in:"
    echo -e "  ${BLUE}ssh -p $SSH_PORT -i /path/to/your/private_key $DEPLOY_USER@SERVER_IP${RESET}"
    echo "-------------------------------------"
    
    echo ""
    log "Next Steps After Reboot:"
    echo "1. Log back into the server using the new details above."
    echo "2. Start KCstudio Launchpad again with 'launchpad' or 'kcstudio-launchpad':"
    echo ""
    echo "From the main menu, you can:"
    echo "  - Architect new applications."
    echo "  - Manage existing projects."
    echo "  - Perform server-wide tasks."
    
    echo ""
    echo "For more information and documentation, visit:"
    echo "https://launchpad.kcstudio.nl" 
    echo "https://github.com/kelvincdeen/KCstudio-Launchpad"
    
    echo ""
    echo ""

    prompt "The server setup is complete. It is highly recommended to reboot now. Reboot now? [y/N]:" REBOOT_CONFIRM
    if [[ "$REBOOT_CONFIRM" == [yY] || "$REBOOT_CONFIRM" == [yY][eE][sS] ]]; then
        log "Rebooting server now...log back in as the '$DEPLOY_USER' user after the reboot."
        sleep 3
        reboot
    else
        warn "Reboot cancelled by user."
        echo "Please remember to manually reboot the server soon by typing 'reboot' to apply all changes."
        echo "You can log back in as '$DEPLOY_USER' now."
        exit 0
    fi
}

# --- Main Logic Execution ---
main() {
    if [ "$(id -u)" -ne 0 ]; then
      die "This script must be run as root."
    fi

    show_logo
    
    log "Checking system state..."
    local user_count
    user_count=$(count_human_users)
    local existing_users
    existing_users=$(get_human_users | tr '\n' ' ')
    
    if [ "$user_count" -eq 0 ]; then
        # Fresh Install (No human users found)
        # Run standard linear flow
        run_full_hardening

    else
        # Check for Configured / Multi-User
        
        local status_msg="${YELLOW}Unverified${RESET}"
        if check_setup_state; then
            status_msg="${GREEN}Secure & Hardened${RESET}"
        else
            warn "Users found, but can't determine hardened state. Please run full hardening."
            echo ""
        fi

        echo "==================================================================================="
        echo "  Secure Core VPS - System Dashboard"
        echo "==================================================================================="
        echo ""
        printf "  %-20s %b\n" "System Status:" "$status_msg"
        printf "  %-20s %s\n" "Active Admins:" "$existing_users"
        echo ""
        echo "==================================================================================="
        echo ""
        echo "  [1] Re-run Full System Hardening & Updates"
        echo "  [2] Add a New Admin User"
        # Only show this option if there are more than 1 user
        if [ "$user_count" -gt 1 ]; then
            echo "  [3] Delete an Admin User"
        fi
        echo ""
        echo "==================================================================================="
        printf "  \e[36m[B]\e[0m Back to Hub\n"
        echo "==================================================================================="
        prompt "Select an option:" choice
        
        case $choice in
            1) run_full_hardening ;;
            2) add_new_user ;;
            3) 
                if [ "$user_count" -gt 1 ]; then
                    delete_a_user 
                else
                    warn "Invalid choice."
                fi
                ;;
            [Bb]) exit 0 ;;
            *) warn "Invalid choice."; exit 0 ;;
        esac
    fi
}

# --- Execute Main ---
main