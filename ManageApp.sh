#!/bin/bash

# === KCStudio Launchpad - Advanced Project Management ===
# Copyright (c) 2026 Kelvin Deen - KCStudio.nl

set -euo pipefail
IFS=$'\n\t'

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

check_dep() {
    if ! command -v "$1" &> /dev/null; then
        warn "'$1' command not found. This feature requires it."
        prompt "Would you like to try and install it now? (y/N)" choice
        if [[ "$choice" =~ ^[yY]$ ]]; then
            sudo apt-get update && sudo apt-get install -y "$1"
        else
            return 1
        fi
    fi
    return 0
}

# --- UI Functions ---
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

# --- Global & Project Variables ---
PROJECT_ROOT="/var/www"
BACKUP_ROOT="/var/backups"

# --- Startup Logic ---
list_all_domains() {
    log "Listing all managed projects and their domains..."
    echo "----------------------------------------------------------------------------------------------------"
    printf "%-30s | %-35s | %-35s\n" "PROJECT NAME" "FRONTEND DOMAIN" "API DOMAIN"
    echo "----------------------------------------------------------------------------------------------------"

    sudo find "$PROJECT_ROOT" -maxdepth 2 -type f -name "project.conf" | while read -r conf_file; do
        (
            # shellcheck source=/dev/null
            source <(sudo cat "$conf_file")
            printf "%-30s | %-35s | %-35s\n" "$PROJECT" "${FRONTEND_DOMAIN:-N/A}" "${API_DOMAIN:-N/A}"
        )
    done
    echo "----------------------------------------------------------------------------------------------------"
    pause
}

show_traffic_stats_all_projects() {
    log "Aggregating NGINX Traffic Statistics for all Projects..."
    warn "This can take a moment on servers with very large log files."

    local thirty_days_ago
    thirty_days_ago=$(date -d "30 days ago" +%s)
    local twenty_four_hours_ago
    twenty_four_hours_ago=$(date -d "24 hours ago" +%s)

    echo "--------------------------------------------------------------------------------------------------------"
    printf "%-35s | %-20s | %-20s | %-20s\n" "DOMAIN" "TOTAL HITS" "HITS (LAST 30D)" "HITS (LAST 24H)"
    echo "--------------------------------------------------------------------------------------------------------"

    while IFS= read -r conf_file; do
        # shellcheck source=/dev/null
        source <(sudo cat "$conf_file")

        process_log() {
            local domain_name=$1
            local log_type=$2 # 'api' or 'web'
            local log_pattern="/var/log/nginx/${PROJECT}-${log_type}.access.log*"

            if ! ls ${log_pattern} 1> /dev/null 2>&1; then return; fi

            local log_stream
            log_stream=$(sudo find /var/log/nginx/ -name "${PROJECT}-${log_type}.access.log*" -print0 | xargs -0 sudo zcat -f)

            if [ -z "$log_stream" ]; then continue; fi

            local total_hits
            total_hits=$(echo "$log_stream" | wc -l)

            local recent_hits
            recent_hits=$(echo "$log_stream" | awk -v d30="$thirty_days_ago" -v d24="$twenty_four_hours_ago" '
                BEGIN {
                    m["Jan"]=1; m["Feb"]=2; m["Mar"]=3; m["Apr"]=4; m["May"]=5; m["Jun"]=6;
                    m["Jul"]=7; m["Aug"]=8; m["Sep"]=9; m["Oct"]=10; m["Nov"]=11; m["Dec"]=12
                }
                {
                    gsub(/\[|\]/, "", $4);
                    split($4, a, /[\/:]/);
                    ts = mktime(a[3] " " m[a[2]] " " a[1] " " a[4] " " a[5] " " a[6]);
                    if (ts > d30) h30++;
                    if (ts > d24) h24++;
                }
                END { print h30+0, h24+0 }
            ')

            local hits_30d
            hits_30d=$(echo "$recent_hits" | awk '{print $1}')
            local hits_24h
            hits_24h=$(echo "$recent_hits" | awk '{print $2}')

            printf "%-35s | %-20s | %-20s | %-20s\n" "$domain_name" "$total_hits" "$hits_30d" "$hits_24h"
        }

        if [[ -n "$API_DOMAIN" ]]; then process_log "$API_DOMAIN" "api"; fi
        if [[ -n "$FRONTEND_DOMAIN" ]]; then process_log "$FRONTEND_DOMAIN" "web"; fi

    done < <(sudo find "$PROJECT_ROOT" -maxdepth 2 -type f -name "project.conf")

    echo "--------------------------------------------------------------------------------------------------------"
    pause
}

if [[ "${1-}" == "--list-all" ]]; then
    list_all_domains
    exit 0
fi

PROJECT_NAME_ARG="${1-}"

if [ -z "$PROJECT_NAME_ARG" ]; then
    clear
    show_logo

    log "Searching for available projects to manage..."
    AVAILABLE_PROJECTS=()
    while IFS= read -r -d $'\0' conf_file; do
        AVAILABLE_PROJECTS+=("$(basename "$(dirname "$conf_file")")")
    done < <(sudo find "$PROJECT_ROOT" -maxdepth 2 -type f -name "project.conf" -print0)

    if [ ${#AVAILABLE_PROJECTS[@]} -eq 0 ]; then
        err "No valid projects found in '$PROJECT_ROOT'."
    fi

    echo "Please select a project to manage (or 'A' to list all domains, or 'T' to show traffic stats): "
    select project in "${AVAILABLE_PROJECTS[@]}"; do
        if [[ "$REPLY" =~ ^[Aa]$ ]]; then
            list_all_domains
            clear; show_logo; log "Searching for available projects..."; echo "Please select a project to manage (or 'A' to list all domains, or 'T' to show traffic stats): "
            continue
        elif [[ "$REPLY" =~ ^[Tt]$ ]]; then
            show_traffic_stats_all_projects
            clear; show_logo; log "Searching for available projects..."; echo "Please select a project to manage (or 'A' to list all domains, or 'T' to show traffic stats): "
            continue
        elif [[ -n "$project" ]]; then
            PROJECT_NAME_ARG="$project"
            break
        else
            warn "Invalid choice."
        fi
    done
fi

PROJECT_CONF_PATH="$PROJECT_ROOT/$PROJECT_NAME_ARG/project.conf"
[[ -f "$PROJECT_CONF_PATH" ]] || err "Project '$PROJECT_NAME_ARG' is not a valid project (missing 'project.conf')."

log "Loading manifest for project '$PROJECT_NAME_ARG'..."
source <(sudo cat "$PROJECT_CONF_PATH")
# log_ok "Project manifest loaded successfully."

BACKEND_SERVICES=()
for comp in "${SELECTED_COMPONENTS[@]}"; do [[ "$comp" != "website" ]] && BACKEND_SERVICES+=("$comp"); done
APP_USER="app_$PROJECT"

# --- Universal Upload Helper ---
prompt_and_upload_file() {
    local file_path="$1"
    echo ""
    if [ ! -f "$file_path" ]; then
        log_err "Upload function called with invalid file: $file_path"
        return
    fi

    local filename
    filename=$(basename "$file_path")
    read -rp "$(echo -e "\e[36m[?]\e[0m Upload '$filename' and get a shareable link? [y/N] ")" choice

    if [[ "$choice" =~ ^[yY]$ ]]; then
        log "Uploading file..."
        
        local response_with_code
        response_with_code=$(curl -# -w "\n%{http_code}" -F "file=@$file_path" https://TUI-transfer.kcstudio.nl/upload?qrcode)
        
        local http_code
        http_code=$(echo "$response_with_code" | tail -n1)
        local response_body
        response_body=$(echo "$response_with_code" | sed '$d')

        echo ""

        if [ "$http_code" -eq 200 ]; then
            echo "$response_body" 
            echo ""
            log_ok "Upload complete! Your link is available above."
        else
            log_err "Upload failed. The server responded with HTTP status: $http_code"
            if [ -n "$response_body" ]; then warn "$response_body"; fi
        fi
    else
        log "Skipping upload. Your file remains locally at: $file_path"
    fi
}

# --- Menu and Action Functions ---

select_component() {
    local prompt_message="$1"
    local -n components_array=$2

    if [ ${#components_array[@]} -eq 0 ]; then
        log_err "No components available."
        return 1
    fi

    echo ""
    echo "$prompt_message"
    echo ""

    local i=1
    for comp in "${components_array[@]}"; do
        printf "  [%d] %s\n" "$i" "$comp"
        ((i++))
    done
    echo ""
    echo "  [B] Back"
    echo ""

    prompt "Your choice: " choice

    # Back
    if [[ "$choice" =~ ^[Bb]$ ]]; then
        return 1
    fi

    # Numeric selection
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local index=$((choice - 1))
        if (( index >= 0 && index < ${#components_array[@]} )); then
            REPLY="${components_array[$index]}"
            return 0
        fi
    fi

    warn "Invalid choice."
    return 1
}


# --- Helper for show components ---
print_list() {
    local label="$1"
    shift
    local items=("$@")

    printf "  %-20s:\n" "$label"
    if [ ${#items[@]} -eq 0 ]; then
        printf "    - None\n"
    else
        for item in "${items[@]}"; do
            printf "    - %s\n" "$item"
        done
    fi
}

# --- Core Functions ---
show_info() {
    log "Project Information for '$PROJECT'"
    echo "------------------------------------------"
    echo ""
    printf "  %-20s: %s\n" "Project Name" "$PROJECT"
    printf "  %-20s: %s\n" "Path" "$APP_PATH"

    if [[ "$HAS_WEBSITE" == "true" ]]; then
        printf "  %-20s: %s\n" "Frontend Domain" "https://$FRONTEND_DOMAIN"
    fi

    if [[ "$HAS_BACKEND" == "true" ]]; then
        printf "  %-20s: %s\n" "API Base URL" "https://$API_DOMAIN/v1/"
    fi

    echo ""
    print_list "Installed Components" "${SELECTED_COMPONENTS[@]}"
    echo ""
    echo "------------------------------------------"
}


restart_component() {
  if [ ${#BACKEND_SERVICES[@]} -eq 0 ]; then log_err "No backend services to restart."; return; fi
  if ! select_component "Which backend service do you want to restart?" BACKEND_SERVICES ; then return; fi
  local comp="$REPLY"
  log "Restarting '$comp' service for project '$PROJECT'..."
  sudo systemctl restart "$PROJECT-$comp.service"
  log_ok "'$comp' service has been sent the restart command."
  sleep 1
  sudo systemctl status "$PROJECT-$comp.service" --no-pager --lines=5
}

view_logs() {
  if [ ${#BACKEND_SERVICES[@]} -eq 0 ]; then
    log_err "No backend services to view logs for."
    return
  fi

  echo ""
  echo "What would you like to do?"
  echo "1) View last 10 lines of each backend's logs"
  echo "2) Tail live logs for a specific backend"
  prompt "Enter choice [1-2]: " log_choice

  case "$log_choice" in
    1)
      log "Showing last 10 lines of logs for all backend services:"
      for comp in "${BACKEND_SERVICES[@]}"; do
        echo "------------------ $comp ------------------"
        sudo tail -n 10 "$APP_PATH/logs/$comp/output.log" || warn "Could not read log for $comp"
        echo ""
      done
      ;;
    2)
      if ! select_component "Which backend service's logs do you want to view (live)?" BACKEND_SERVICES ; then return; fi
      local comp="$REPLY"
      log "Tailing logs for '$comp'. Press Ctrl+C to stop."
      sudo tail -f "$APP_PATH/logs/$comp/output.log" || true
      ;;
    *)
      warn "Invalid choice."
      ;;
  esac
}


check_health() {
  if [ ${#BACKEND_SERVICES[@]} -eq 0 ]; then log_err "No backend services to check."; return; fi
  log "Checking health of all available backend services for '$PROJECT'..."
  for comp in "${BACKEND_SERVICES[@]}"; do
    local port_var="PORT_${comp^^}"
    if [ -z "${!port_var-}" ]; then
        printf "  - %-10s => \e[31mPort not defined in manifest\e[0m\n" "$comp"
        continue
    fi
    local port="${!port_var}"

    printf "  - %-10s (Port %-5s) => Internal: " "$comp" "$port"
    if curl --fail -s -o /dev/null "http://127.0.0.1:$port/health"; then
      echo -e "\e[32mOK\e[0m"
    else
      echo -e "\e[31mFAILED\e[0m"
    fi

    local public_url="https://$API_DOMAIN/v1/$comp/health"
    printf "%26s => Full Stack: " ""
    if curl --fail -s -L -o /dev/null "$public_url"; then
      echo -e "\e[32mOK\e[0m"
    else
      echo -e "\e[31mFAILED\e[0m"
    fi
  done
}

status_all() {
  if [ ${#BACKEND_SERVICES[@]} -eq 0 ]; then log_err "No backend services to show status for."; return; fi
  log "Displaying systemd status for all project services..."
  for comp in "${BACKEND_SERVICES[@]}"; do
    echo "-------------------------------------"
    echo "Service: $PROJECT-$comp.service"
    echo "-------------------------------------"
    sudo systemctl status "$PROJECT-$comp.service" --no-pager
  done
}

reload_nginx() {
  log "Testing NGINX configuration..."
  if sudo nginx -t; then
    log_ok "Configuration is OK. Reloading NGINX..."
    sudo systemctl reload nginx
    log_ok "NGINX reloaded successfully."
  else
    log_err "NGINX configuration test failed. Not reloading."
  fi
}

# --- NGINX Log Viewer (Grouped) ---
tail_nginx_logs() {
    log "NGINX Log Viewer for '$PROJECT'"
    echo "--- Frontend ---"
    echo "  [1] Tail Access Logs"
    echo "  [2] Tail Error Logs"
    echo "--- Backend ---"
    echo "  [3] Tail Access Logs"
    echo "  [4] Tail Error Logs"
    echo "--- Everything ---"
    echo "  [5] Tail All Logs"
    echo ""
    echo "  [B] Back"
    prompt "Choice:" lchoice

    case $lchoice in
        1) sudo tail -f /var/log/nginx/${PROJECT}-web.access.log || true ;;
        2) sudo tail -f /var/log/nginx/${PROJECT}-web.error.log || true ;;
        3) sudo tail -f /var/log/nginx/${PROJECT}-api.access.log || true ;;
        4) sudo tail -f /var/log/nginx/${PROJECT}-api.error.log || true ;;
        5) sudo tail -f /var/log/nginx/${PROJECT}-*.log || true ;;
        [Bb]) return ;;
        *) warn "Invalid choice." ;;
    esac
}

# --- Edit & Reload NGINX Wrapper ---
edit_and_reload_nginx() {
    log "Edit NGINX Configuration"
    echo "Select which NGINX file to edit:"
    echo "  [1] Frontend Config for: ($FRONTEND_DOMAIN)"
    echo "  [2] Backend API Config for: ($API_DOMAIN)"
    echo ""
    prompt "Your choice: " ng_choice

    local file_to_edit=""
    case $ng_choice in
        1) file_to_edit="/etc/nginx/sites-available/${PROJECT}-web.conf" ;;
        2) file_to_edit="/etc/nginx/sites-available/${PROJECT}-api.conf" ;;
        *) warn "Cancelled."; return ;;
    esac

    if [ ! -f "$file_to_edit" ]; then warn "File $file_to_edit not found."; return; fi

    log "Opening $file_to_edit..."
    sudo nano "$file_to_edit"

    log "Testing NGINX syntax..."
    if sudo nginx -t; then
        prompt "Syntax OK. Reload NGINX now? (y/N)" reload_conf
        if [[ "$reload_conf" =~ ^[yY]$ ]]; then
            sudo systemctl reload nginx
            log_ok "NGINX reloaded."
        else
            log "Reload skipped."
        fi
    else
        err "Syntax Check FAILED. NGINX was NOT reloaded. Please fix errors."
    fi
}

reload_website() {
  if ! [[ "$HAS_WEBSITE" == "true" ]]; then
    log_err "No 'website' component found for this project."
    return
  fi
  local site_path="$APP_PATH/website"
  local web_user="web_$PROJECT"
  log "Reloading website files..."
  echo "This is useful after deploying new frontend files (e.g., via FTP, SCP, or Deploy from URL)."
  echo "It resets file ownership to the '$web_user' user and reloads NGINX."
  sudo chown -R "$web_user:$web_user" "$site_path"
  sudo chmod -R 755 "$site_path"
  reload_nginx
  log_ok "Website permissions reset and NGINX reloaded."
}

# --- Developer Experience Functions ---
show_admin_keys() {
    if [ ${#BACKEND_SERVICES[@]} -eq 0 ]; then log_err "No backend services to show keys for."; return; fi
    log "Displaying Admin API Keys"
    echo "These keys are for server-to-server or administrative tasks ONLY."
    echo "They should NEVER be used in a public frontend."
    echo "-----------------------------------------------------"
    for comp in "${BACKEND_SERVICES[@]}"; do
        local key
        key=$(sudo grep -E '^ADMIN_API_KEY=' "$APP_PATH/$comp/.env" | cut -d'=' -f2)
        printf "  - %-10s: %s\n" "$comp" "$key"
    done
    echo "-----------------------------------------------------"
}

rotate_jwt_secret() {
    if [ ${#BACKEND_SERVICES[@]} -eq 0 ]; then log_err "No backend services found to rotate JWT secret for."; return; fi

    log_err "SECURITY WARNING: JWT Secret Rotation"
    warn "This action will generate a new master key for signing all session tokens for project '$PROJECT'."
    warn "This will immediately invalidate ALL active user sessions, forcing everyone to log in again."
    echo ""
    read -rp "Are you absolutely sure you want to proceed? (y/N): " confirm
    if [[ "$confirm" != [yY] ]]; then
        echo "Operation cancelled."
        return
    fi

    log "Step 1: Generating new secure JWT secret..."
    local NEW_JWT_SECRET
    NEW_JWT_SECRET=$(openssl rand -hex 32)
    log_ok "New secret generated."

    log "Step 2: Updating .env files for all backend services..."
    for comp in "${BACKEND_SERVICES[@]}"; do
        local env_file="$APP_PATH/$comp/.env"
        sudo sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$NEW_JWT_SECRET/" "$env_file"
        log_ok "Updated secret for '$comp' service."
    done

    log "Step 3: Restarting all backend services to apply the new secret..."
    for comp in "${BACKEND_SERVICES[@]}"; do
        sudo systemctl restart "$PROJECT-$comp.service"
        log_ok "Restarted '$comp' service."
    done

    log_ok "JWT secret rotation complete. All user sessions have been invalidated."
}


deploy_code_local() {
    local all_components=("${BACKEND_SERVICES[@]}")
    if [[ "$HAS_WEBSITE" == "true" ]]; then
        all_components+=("website")
    fi

    log "Deploy New Code from Local Path"
    echo "This tool safely deploys new code from a local directory into the selected component."
    echo ""
    echo "  - For \e[36mbackend apps\e[0m, it preserves your database files (*.db) and Python venv."
    echo "  - For \e[36mwebsites\e[0m, it mirrors the build folder exactly, removing outdated files."
    echo ""
    echo "  \e[33mImportant:\e[0m Always deploy from a clean, complete copy of your code."

    if ! select_component "Which component do you want to deploy new code to?" all_components ; then return; fi
    local comp="$REPLY"

    prompt "Enter the full path to the source directory containing the new code for '$comp': " source_path
    if [ ! -d "$source_path" ]; then
        log_err "Source directory not found: $source_path"
        return
    fi

    local dest_path="$APP_PATH/$comp"

    log "Step 1: Previewing Changes"
    echo "Performing a dry-run of 'rsync' to show what would be updated..."

    if [[ "$comp" == "website" ]]; then
        sudo rsync -av --delete --dry-run "$source_path/" "$dest_path"
    else
        sudo rsync -av --exclude="venv/" --exclude="*.db" --dry-run "$source_path/" "$dest_path"
    fi

    echo ""
    log "Step 2: Confirm Deployment"
    echo "The following 'rsync' command will be executed to synchronize the directories:"
    if [[ "$comp" == "website" ]]; then
        echo -e "  \e[36msudo rsync -av --delete \"$source_path/\" \"$dest_path\"\e[0m"
    else
        echo -e "  \e[36msudo rsync -av \"$source_path/\" \"$dest_path\" --exclude=\"venv/\" --exclude=\"*.db\"\e[0m"
    fi

    prompt "Are you sure you want to proceed with deployment to '$comp'? (y/N): " confirm
    if [[ "$confirm" != [yY] ]]; then
        echo "Deployment cancelled."
        return
    fi

    log "Step 3: Deploying Files"
    if [[ "$comp" == "website" ]]; then
        sudo rsync -av --delete "$source_path/" "$dest_path"
        local web_user="web_$PROJECT"
        sudo chown -R "$web_user:$web_user" "$dest_path"
        sudo chmod -R 755 "$dest_path"
        reload_nginx
        log_ok "Website files deployed, permissions set, and NGINX reloaded."
    else
        sudo rsync -av --exclude="venv/" --exclude="*.db" "$source_path/" "$dest_path"
        sudo chown -R "$APP_USER:$APP_USER" "$dest_path"
        log_ok "Files synchronized and permissions set."

        log "Step 4: Restarting Service..."
        sudo systemctl restart "$PROJECT-$comp.service"
        log_ok "'$comp' service restarted to apply changes."
        sleep 1
        sudo systemctl status "$PROJECT-$comp.service" --no-pager --lines=5
    fi
}


deploy_code_url() {
    if ! check_dep "wget" || ! check_dep "tree"; then return; fi

    log "Deploy New Code from URL"
    echo "This tool downloads an archive (zip, tar.gz), shows its contents, and deploys it to a component."
    echo ""
    log "💡 Recommended Method: Use the KCstudio Transfer Service"
    printf "\n\e[33m%s\e[0m\n" "To easily get a URL for your local deployment archive, use:"
    printf "  - \e[36mhttps://TUI-transfer.kcstudio.nl\e[0m\n"
    printf "\nSimply upload your .zip or .tar.gz file there, and paste the generated URL below.\n"


    if ! select_component "Which component do you want to deploy to?" SELECTED_COMPONENTS ; then return; fi
    local comp="$REPLY"

    prompt "Enter the URL of the archive file (e.g., .zip, .tar.gz): " url
    if [ -z "$url" ]; then log_warn "No URL provided."; return; fi

    local temp_dir
    temp_dir=$(mktemp -d)
    trap '[[ -n "${temp_dir:-}" ]] && sudo rm -rf "$temp_dir"' EXIT RETURN

    log "Step 1: Downloading archive..."
    if ! sudo wget -O "$temp_dir/archive" "$url"; then
        log_err "Download failed. Please check the URL."
        return
    fi
    log_ok "Download complete."

    log "Step 2: Extracting archive..."
    if file "$temp_dir/archive" | grep -q 'gzip compressed data'; then
        sudo tar -xzf "$temp_dir/archive" -C "$temp_dir"
    elif file "$temp_dir/archive" | grep -q 'Zip archive data'; then
        if ! check_dep "unzip"; then return; fi
        sudo unzip "$temp_dir/archive" -d "$temp_dir"
    else
        log_err "Unsupported archive type. Only .zip and .tar.gz are supported."
        return
    fi
    sudo rm "$temp_dir/archive" # Clean up the downloaded archive file
    log_ok "Extraction complete."

    log "Step 3: Previewing Contents"
    echo "The following files were extracted from the archive:"
    echo "--------------------------------------------------------"
    sudo tree "$temp_dir"
    echo "--------------------------------------------------------"

    local dest_path="$APP_PATH/$comp/"
    log "Step 4: Confirm Deployment"
    echo "The contents of the archive will be copied to '$dest_path'."
    log_warn "This will overwrite any existing files with the same names."
    prompt "Are you sure you want to proceed with deployment to '$comp'? (y/N): " confirm
    if [[ "$confirm" != [yY] ]]; then echo "Deployment cancelled."; return; fi

    log "Step 5: Deploying..."

    if [[ "$comp" == "website" ]]; then
        log_warn "This is a full sync. Files in the website folder that are NOT in the archive will be deleted."
        prompt "Are you absolutely sure you want to continue? This will delete unmatched files. [y/N]: " confirm_website
        if [[ "$confirm_website" != [yY] ]]; then
            echo "Website deployment cancelled."
            return
        fi
        sudo rsync -av --delete "$temp_dir/" "$dest_path"
    else
        sudo rsync -av "$temp_dir/" "$dest_path"
    fi

    log_ok "Files copied successfully."

    log "Step 6: Setting Permissions and Reloading"
    if [[ "$comp" == "website" ]]; then
            local web_user="web_$PROJECT"
        sudo chown -R "$web_user:$web_user" "$dest_path"
        sudo chmod -R 755 "$dest_path"
        log_ok "Website permissions set. Reloading NGINX..."
        reload_website
    else
        sudo chown -R "$APP_USER:$APP_USER" "$dest_path"
        log_ok "Backend permissions set. Restarting service..."
        sudo systemctl restart "$PROJECT-$comp.service"
        log_ok "Service '$comp' restarted."
        sleep 1
        sudo systemctl status "$PROJECT-$comp.service" --no-pager --lines=5
    fi
}

# --- Direct Env Manager ---
manage_env() {
    if [ ${#BACKEND_SERVICES[@]} -eq 0 ]; then log_err "No backend services found."; return; fi

    log "Manage Environment Variables (.env)"
    echo "Select service to edit .env:"
    select comp in "${BACKEND_SERVICES[@]}"; do
        if [[ -n "$comp" ]]; then
            local env_file="$APP_PATH/$comp/.env"
            log "Opening $env_file in nano..."
            sudo -E "${EDITOR:-nano}" "$env_file"
            
            prompt "Restart service '$comp' to apply changes? (y/N): " restart_confirm
            if [[ "$restart_confirm" == [yY] ]]; then
                sudo systemctl restart "$PROJECT-$comp.service"
                log_ok "Service '$comp' restarted."
            fi
            break
        else
            warn "Invalid choice."
        fi
    done
}

explore_database() {
    if ! check_dep "litecli" || ! check_dep "fzf"; then return; fi

    log "Searching for databases within project '$PROJECT'..."
    local db_files
    db_files=$(sudo find "$APP_PATH" -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \))

    if [ -z "$db_files" ]; then
        log_warn "No database files found for this project."
        return
    fi

    local selected_db
    if ! selected_db=$(echo "$db_files" | fzf --prompt="Select a database to explore > " --height=40% --border); then return; fi

    if [ -z "$selected_db" ]; then echo "No database selected."; return; fi

    log "Selected database: $selected_db"
    echo
    printf "\e[33m%s\e[0m\n" "--- HOW TO USE LITECLI ---"
    printf " You are about to enter an interactive SQL client for SQLite.\n"
    printf "\n\e[36m%s\e[0m\n" "ESSENTIAL COMMANDS (start with a dot '.'):"
    printf "  - \e[32m.tables\e[0m          List all tables in the database.\n"
    printf "  - \e[32m.schema <table_name>\e[0m Show the structure of a specific table.\n"
    printf "  - \e[32mquit or \\q\e[0m      \e[31mExit the client and return to this script.\e[0m\n"
    printf "\n\e[36m%s\e[0m\n" "EXAMPLE SQL QUERIES (end with a semicolon ';'):"
    printf "  - \e[32mSELECT * FROM users LIMIT 10;\e[0m\n"
    printf "  - \e[32mSELECT count(*) FROM items;\e[0m\n"
    printf "\n\e[33m%s\e[0m\n" "TIPS:"
    printf "  - Use the \e[36mTab\e[0m key for smart auto-completion of commands and table/column names.\n"
    printf "  - Use \e[36mUp/Down\e[0m arrow keys to navigate command history.\n"

    echo ""
    read -rp "Press [Enter] to launch litecli..."

    sudo litecli "$selected_db"
}

view_tree() {
    if ! check_dep "tree"; then
        return
    fi
    log "Displaying directory tree for '$PROJECT' (max depth: 3, ignoring venv):"
    tree -L 3 -I 'venv' "$APP_PATH"
}

edit_component_file_fzf() {
    if ! check_dep "fzf"; then return; fi

    log "Scanning all component files..."
    local file_list=()
    local -A file_to_comp_map

    # --- Backend services (if present) ---
    for comp in "${BACKEND_SERVICES[@]}"; do
        local comp_path="$APP_PATH/$comp"
        [ -d "$comp_path" ] || continue

        while IFS= read -r file; do
            local rel_path="${file#$comp_path/}"
            local display="[${comp}] $rel_path"
            file_list+=("$display")
            file_to_comp_map["$display"]="$comp:$file"
        done < <(
            sudo find "$comp_path" -type f \
                ! -path "*/venv/*" \
                ! -path "*/__pycache__/*"
        )
    done

    # --- Website (if present) ---
    if [[ "$HAS_WEBSITE" == "true" && -d "$APP_PATH/website" ]]; then
        local site_path="$APP_PATH/website"
        while IFS= read -r file; do
            local rel_path="${file#$site_path/}"
            local display="[website] $rel_path"
            file_list+=("$display")
            file_to_comp_map["$display"]="website:$file"
        done < <(sudo find "$site_path" -type f)
    fi

    if [ ${#file_list[@]} -eq 0 ]; then
        log_warn "No editable files found."
        return
    fi

    local selection
    if ! selection=$(printf '%s\n' "${file_list[@]}" | fzf \
        --prompt="Select a file to edit > " \
        --height=80% \
        --border); then
        return
    fi

    [ -n "$selection" ] || return

    IFS=':' read -r comp full_path <<< "${file_to_comp_map["$selection"]}"

    log "Editing '$full_path' from component '$comp'..."
    sudo -E "${EDITOR:-nano}" "$full_path"

    echo ""

    # --- Post-edit action ---
    if [[ "$comp" == "website" ]]; then
        prompt "Reload NGINX to apply website changes? (y/N): " reload_confirm
        if [[ "$reload_confirm" == [yY] ]]; then
            reload_nginx
        else
            log "NGINX reload skipped."
        fi
    else
        prompt "Restart service '$comp' to apply changes? (y/N): " restart_confirm
        if [[ "$restart_confirm" == [yY] ]]; then
            sudo systemctl restart "$PROJECT-$comp.service"
            log_ok "Service '$comp' restarted."
        else
            log "No restart performed."
        fi
    fi
}


# --- Maintenance & Danger Zone Functions ---
backup_menu() {
    log "Project Backup Menu"
    echo "This tool creates a compressed archive of your project's files."
    sudo mkdir -p "$BACKUP_ROOT"
    log_ok "Backups will be stored in '$BACKUP_ROOT'."
    echo ""
    echo "1) Backup FULL Project (Code + Data + Logs)"
    echo "2) Backup DATABASES Only"
    echo "3) Return to Main Menu"
    prompt "Your choice: " choice

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")

    case $choice in
        1)
            local backup_file="$BACKUP_ROOT/${PROJECT}-full-backup-${timestamp}.tar.gz"
            log "Starting full project backup..."
            echo "This will archive the entire '$APP_PATH' directory, excluding 'venv' directories."
            if sudo tar --exclude='**/venv' -czf "$backup_file" -C "$(dirname "$APP_PATH")" "$(basename "$APP_PATH")"; then
                log_ok "Full project backup complete!"
                echo "Archive created at: $backup_file"
                prompt_and_upload_file "$backup_file"
            else
                log_err "Backup command failed. Please check permissions and disk space."
            fi
            ;;
        2)
            if ! check_dep "sqlite3" || ! check_dep "fzf"; then return; fi
            log "Searching for databases within project '$PROJECT'..."
            local db_files
            db_files=($(sudo find "$APP_PATH" -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \)))

            if [ ${#db_files[@]} -eq 0 ]; then
                log_warn "No database files found for this project."
                return
            fi

            echo "Found the following databases:"
            for db in "${db_files[@]}"; do
                echo "  - $(basename "$db")"
            done
            
            echo ""
            echo "What would you like to back up?"
            echo "  1) Backup ALL databases into a single archive"
            echo "  2) Select a SPECIFIC database to back up"
            prompt "Your choice: " db_backup_choice

            local temp_db_dir
            temp_db_dir=$(mktemp -d)
            trap 'sudo rm -rf "$temp_db_dir"' RETURN

            if [[ "$db_backup_choice" == "1" ]]; then
                log "Backing up all databases..."
                for db_file in "${db_files[@]}"; do
                    local rel_path
                    rel_path=$(realpath --relative-to="$APP_PATH" "$db_file")
                    sudo mkdir -p "$temp_db_dir/$(dirname "$rel_path")"
                    sudo sqlite3 "$db_file" ".backup '$temp_db_dir/$rel_path'"
                    log_ok "Backed up: $rel_path"
                done
                
                local backup_file="$BACKUP_ROOT/${PROJECT}-db-all-backup-${timestamp}.tar.gz"
                sudo tar -czf "$backup_file" -C "$temp_db_dir" .
                echo ""
                log_ok "All databases backed up into a single archive!"
                echo ""
                echo "Archive created at: $backup_file"
                prompt_and_upload_file "$backup_file"

            elif [[ "$db_backup_choice" == "2" ]]; then
                local selected_db
                if ! selected_db=$(printf '%s\n' "${db_files[@]}" | fzf --prompt="Select a database to back up > " --height=40% --border); then return; fi

                if [ -n "$selected_db" ]; then
                    local backup_file="$BACKUP_ROOT/${PROJECT}-db-$(basename "$selected_db")-${timestamp}.db.bak"
                    log "Creating a safe backup copy of $(basename "$selected_db")..."
                    sudo sqlite3 "$selected_db" ".backup '$backup_file'"
                    echo ""
                    log_ok "Database backup complete!"
                    echo ""
                    echo "Backup file created at: $backup_file"
                    prompt_and_upload_file "$backup_file"
                else
                    log_warn "No database selected. Operation cancelled."
                fi
            else
                warn "Invalid choice."
            fi
            ;;
        3) return ;;
        *) warn "Invalid choice." ;;
    esac
}

delete_project() {
    log_err "DANGER ZONE: This will permanently delete the '$PROJECT' project."
    echo "This includes all code, databases, logs, users, system services, and NGINX configurations."
    log_warn "This action CANNOT BE UNDONE. It is recommended to create a backup first."

    prompt "To confirm, please type the project name ('$PROJECT'): " confirm_name

    if [[ "$confirm_name" != "$PROJECT" ]]; then
        err "Confirmation failed. Project deletion aborted."
    fi

    log "Proceeding with deletion..."

    for comp in "${BACKEND_SERVICES[@]}"; do
        local service_file="/etc/systemd/system/$PROJECT-$comp.service"
        log "Stopping, disabling, and deleting service: $PROJECT-$comp.service"
        sudo systemctl disable --now "$PROJECT-$comp.service" &>/dev/null || true
        if [ -f "$service_file" ]; then
            sudo rm -f "$service_file"
        fi
    done
    sudo systemctl daemon-reload
    log_ok "All systemd services stopped and deleted."

    if [[ "$HAS_WEBSITE" == "true" ]]; then sudo rm -f "/etc/nginx/sites-enabled/${PROJECT}-web.conf" "/etc/nginx/sites-available/${PROJECT}-web.conf"; fi
    if [[ "$HAS_BACKEND" == "true" ]]; then sudo rm -f "/etc/nginx/sites-enabled/${PROJECT}-api.conf" "/etc/nginx/sites-available/${PROJECT}-api.conf"; fi
    sudo nginx -t && sudo systemctl reload nginx &>/dev/null || log_warn "NGINX reload may fail if other configs are broken, this is OK during deletion."
    log_ok "NGINX configurations removed."

    if [ -f "/etc/logrotate.d/$PROJECT" ]; then
        log "Removing logrotate config..."
        sudo rm -f "/etc/logrotate.d/$PROJECT"
    fi

    local web_user="web_$PROJECT"
    sudo userdel -r "$APP_USER" &>/dev/null || true; log_ok "User '$APP_USER' deleted."
    if [[ "$HAS_WEBSITE" == "true" ]]; then
        sudo userdel -r "$web_user" &>/dev/null || true; log_ok "User '$web_user' deleted."
    fi

    log "Deleting project directory: $APP_PATH"
    sudo rm -rf "$APP_PATH"
    log_ok "Project directory deleted."

    log_ok "Project '$PROJECT' has been completely and permanently deleted."
    exit 0
}

show_help() {
    (
        show_logo
        echo -e "${WHITE}PROJECT MANAGER: ${GREEN}$PROJECT${RESET}"
        echo -e "This dashboard handles the lifecycle of a single application."
        echo -e "Below is a guide on the recommended workflow."
        echo ""

        echo -e "${WHITE}--- 1. THE DEPLOYMENT CYCLE ---${RESET}"
        echo -e "  ${BLUE}[D] Deploy (Local):${RESET}"
        echo -e "      ${GREEN}Use Case:${RESET} You uploaded code to the server via FTP/SCP."
        echo -e "      ${GREEN}Action:${RESET} Syncs files to the app folder (ignoring venv/db) and restarts the service."
        echo -e "  ${BLUE}[U] Deploy (URL):${RESET}"
        echo -e "      ${GREEN}Use Case:${RESET} You want to deploy a GitHub Release .zip."
        echo -e "      ${GREEN}Action:${RESET} Downloads, unzips, and deploys the code in one step."
        echo -e "  ${BLUE}[R] Restart Service:${RESET}"
        echo -e "      ${GREEN}Use Case:${RESET} You edited a Python file manually via CLI."
        echo -e "      ${GREEN}Action:${RESET} Restarts the Systemd service to load the new code."

        echo ""
        echo -e "${WHITE}--- 2. DEBUGGING & LOGS ---${RESET}"
        echo -e "  ${BLUE}[L] Live Service Logs:${RESET}"
        echo -e "      ${GREEN}Why:${RESET} The #1 tool for fixing 500 Errors. Shows the 'print()' output of your app in real-time."
        echo -e "  ${BLUE}[N] NGINX Logs:${RESET}"
        echo -e "      ${GREEN}Why:${RESET} Shows traffic."
        echo -e "      - ${YELLOW}Access Log:${RESET} Who is visiting? (200 OK)"
        echo -e "      - ${YELLOW}Error Log:${RESET} Why did Nginx reject a request? (502 Bad Gateway, 413 Payload Too Large)."
        echo -e "  ${BLUE}[2] Health Check:${RESET}"
        echo -e "      ${GREEN}Why:${RESET} Pings your app internally (127.0.0.1) and externally (public domain) to confirm connectivity."

        echo ""
        echo -e "${WHITE}--- 3. CONFIGURATION & SECRETS ---${RESET}"
        echo -e "  ${BLUE}[E] Edit .env:${RESET}"
        echo -e "      ${GREEN}Why:${RESET} Securely change API Keys, Database passwords, or Debug settings."
        echo -e "      ${GREEN}Note:${RESET} Automatically asks to restart the app after saving."
        echo -e "  ${BLUE}[C] Edit NGINX:${RESET}"
        echo -e "      ${GREEN}Why:${RESET} Change domain names, upload limits, or routing rules."
        echo -e "      ${GREEN}Safety:${RESET} It runs 'nginx -t' before reloading to prevent crashing the web server with a typo."

        echo ""
        echo -e "${WHITE}--- 4. ADVANCED DEVELOPER TOOLS ---${RESET}"
        echo -e "  ${BLUE}[Z] Service Shell:${RESET}"
        echo -e "      ${GREEN}Power Feature:${RESET} drops you into a terminal acting AS the app user."
        echo -e "      ${GREEN}Bonus:${RESET} It automatically activates the Python Virtual Environment (venv)."
        echo -e "      ${GREEN}Use for:${RESET} Running 'pip install', 'flask db upgrade', or management scripts."
        echo -e "  ${BLUE}[DB] Explore Databases:${RESET}"
        echo -e "      ${GREEN}Why:${RESET} Opens a SQL client (LiteCLI) connected to your project's SQLite files."
        echo -e "  ${BLUE}[F] Edit Any File:${RESET}"
        echo -e "      ${GREEN}Why:${RESET} Uses a fuzzy-finder (fzf) to quickly locate and edit any file in the project folder."

        echo ""
        echo -e "${WHITE}--- 5. MAINTENANCE ---${RESET}"
        echo -e "  ${BLUE}[A] Archive/Backup:${RESET} Snapshot your code and database before making risky changes."
        echo -e "  ${BLUE}[J] Rotate JWT:${RESET} ${RED}Danger Zone.${RESET} Generates a new signing key. Forces ALL users to log in again."
        echo ""
        echo -e "${YELLOW}(Press 'q' to quit help)${RESET}"
    ) | less -R
}


show_menu() {
  clear
  show_logo
  echo -e "${WHITE}===================================================================================${RESET}"
  echo -e "  Manage Project: ${GREEN}$PROJECT${RESET}"
  echo -e "${WHITE}===================================================================================${RESET}"
  echo ""
  echo -e "  ${WHITE}--- INSIGHTS ---${RESET}"
  echo -e "  ${BLUE}[1]${RESET} Show Project Info"
  echo -e "  ${BLUE}[2]${RESET} Health Check (Endpoints)"
  echo -e "  ${BLUE}[3]${RESET} Service Status (Systemd)"
  echo -e "  ${BLUE}[4]${RESET} View Directory Tree"
  echo ""
  echo -e "  ${WHITE}--- LOGS & TRAFFIC ---${RESET}"
  echo -e "  ${BLUE}[L]${RESET} View Live Service Logs"
  echo -e "  ${BLUE}[N]${RESET} NGINX Logs (Frontend/Backend)"
  echo ""
  echo -e "  ${WHITE}--- OPERATIONS ---${RESET}"
  echo -e "  ${BLUE}[R]${RESET} Restart Services"
  echo -e "  ${BLUE}[W]${RESET} Reload Website (Perms)"
  echo -e "  ${BLUE}[C]${RESET} Edit & Reload NGINX Config"
  echo ""
  echo -e "  ${WHITE}--- DEVELOPER ---${RESET}"
  echo -e "  ${BLUE}[D]${RESET} Deploy Code (Local Path)"
  echo -e "  ${BLUE}[U]${RESET} Deploy Code (URL)"
  echo -e "  ${BLUE}[E]${RESET} Edit .env Variables"
  echo -e "  ${BLUE}[Z]${RESET} Open Service Shell"
  echo -e "  ${BLUE}[F]${RESET} Edit Any File (fzf)"
  echo -e "  ${BLUE}[DB]${RESET}Explore Databases"
  echo ""
  echo -e "  ${WHITE}--- MAINTENANCE ---${RESET}"
  echo -e "  ${BLUE}[A]${RESET} Archive/Backup Project"
  echo -e "  ${BLUE}[K]${RESET} Show Admin API Keys"
  echo -e "  ${BLUE}[J]${RESET} Rotate JWT Secret"
  echo -e "  ${RED}[X]${RESET} DELETE Project"
  echo ""
  echo -e "${WHITE}===================================================================================${RESET}"
  echo -e "  ${BLUE}[B]${RESET} Back to Hub              ${BLUE}[H]${RESET} Help"
  echo -e "${WHITE}===================================================================================${RESET}"
  prompt "Your choice: " choice
}

# --- Main Menu Loop ---
while true; do
  show_menu
  case $choice in
    1) show_info; pause ;;
    2) check_health; pause ;;
    3) status_all; pause ;;
    4) view_tree; pause ;;
    
    [Ll]) view_logs; pause ;;
    [Nn]) tail_nginx_logs; pause ;;
    
    [Rr]) restart_component; pause ;;
    [Ww]) reload_website; pause ;;
    [Cc]) edit_and_reload_nginx; pause ;;

    [Dd]) deploy_code_local; pause ;;
    [Uu]) deploy_code_url; pause ;;
    [Ee]) manage_env; pause ;;
    [Kk]) show_admin_keys; pause ;;
    [Jj]) rotate_jwt_secret; pause ;;
    DB|db) explore_database; pause ;;
    [Zz])
        if [ ${#BACKEND_SERVICES[@]} -eq 0 ]; then log_err "No backend services found."; pause; continue; fi
        if ! select_component "Which service's shell do you want to open?" BACKEND_SERVICES ; then return; fi
        comp="$REPLY"
        comp_path="$APP_PATH/$comp"

        log "Opening shell for '$comp'. Type 'exit' to return."
        echo "You are now operating as the '$APP_USER' user, in the correct directory, with the Python venv activated."
        warn "The user's HOME is temporarily set to '$comp_path' for this session."
        
        # Set the HOME environment variable for the sudo session.
        # This gives programs like nano and pip a writable directory for their cache/config files.
        # Use --init-file to ensure the (venv) prompt is displayed correctly.
        sudo -u "$APP_USER" HOME="$comp_path" bash -c "cd '$comp_path' && bash --init-file venv/bin/activate -i"
        ;;
    [Ff]) edit_component_file_fzf; pause ;;

    [Aa]) backup_menu; pause ;;
    [Xx]) delete_project ;;

    [Hh]) show_help ;;
    [Bb]) exit 0 ;;
    *) warn "Invalid choice."; pause ;;
  esac
done