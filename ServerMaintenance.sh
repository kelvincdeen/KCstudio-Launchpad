#!/bin/bash

# === KCStudio Launchpad - Server Maintenance & Utilities ===
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

# --- Global Variables & Setup ---
REPORTS_DIR="/var/www/kcstudio/reports"
DOWNLOADS_DIR="/var/www/kcstudio/downloads"
sudo mkdir -p "$REPORTS_DIR"
sudo mkdir -p "$DOWNLOADS_DIR"
sudo chown "$(whoami):$(whoami)" "$DOWNLOADS_DIR" # Give current user ownership
sudo chmod 755 "$REPORTS_DIR"
sudo chmod 775 "$DOWNLOADS_DIR"

# --- Dependency Check Function ---
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
    prompt "Upload '$filename' and get a shareable link? [y/N]" choice

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

# --- Health & Status Functions ---
health_overview() {
    log "System Resource Overview"
    echo "--- Load Average (1, 5, 15 minutes) ---"
    echo "This number should ideally be below the number of CPU cores on your server."
    uptime | awk -F'load average:' '{ print $2 }' | sed 's/^[ \t]*//'
    echo -e "\n--- Memory Usage ---"
    free -h
    echo -e "\n--- Filesystem Usage ---"
    df -h /
    
    echo -e "\n--- Top 10 Processes by CPU ---"
    ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -n 11
    
    echo -e "\n--- Top 10 Processes by Memory ---"
    ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%mem | head -n 11
}

health_htop() {
    log "Launching Interactive Process Viewer (htop)"
    if ! check_dep "htop"; then return; fi
    echo "Press 'q' or F10 to quit htop and return to the menu."
    sudo htop
}

health_ncdu() {
    log "Launching Interactive Disk Usage Analyzer (ncdu)"
    if ! check_dep "ncdu"; then return; fi

    local scan_path
    prompt "Enter the directory to analyze [default: /]:" scan_path
    scan_path=${scan_path:-/}

    if [ ! -d "$scan_path" ]; then
        log_err "Directory '$scan_path' not found."
        return
    fi

    warn "Starting scan of '$scan_path'. This might take a while..."
    echo "Use arrow keys to navigate. Press 'q' to quit ncdu."
    echo ""
    read -rp "Press [Enter] to continue..."

    sudo ncdu "$scan_path"
}

health_disk_usage() {
    log "Analyzing Disk Usage of Top-Level Directories in / (Static)"
    warn "This may take a moment..."
    sudo du -h / --max-depth=1 2>/dev/null | sort -rh | head -n 20
}

health_net_listeners() {
    log "Active Network Listeners (TCP/UDP)"
    if ! check_dep "ss"; then return; fi
    sudo ss -tulnp
}

health_ssh_log() {
    log "Viewing Last 50 SSHD Authentication Log Entries"
    echo "Log file: /var/log/auth.log"
    echo "----------------------------------------------------------------------"
    if sudo test -f /var/log/auth.log; then
        sudo grep -a -i 'sshd' /var/log/auth.log | tail -n 50
    else
        warn "/var/log/auth.log not found or no sshd entries."
    fi
    echo "----------------------------------------------------------------------"
}

health_ufw_log() {
    log "Viewing Last 50 UFW Firewall Log Entries"
    local log_file="/var/log/ufw.log"
    echo "Log file: $log_file"
    echo "----------------------------------------------------------------------"
    if sudo test -f "$log_file"; then
        if [ ! -s "$log_file" ]; then
            warn "Log file is empty. UFW logging might be off. Enable with: sudo ufw logging on"
        else
            sudo tail -n 50 "$log_file"
        fi
    else
        warn "Log file not found. UFW logging might be off. Enable with: sudo ufw logging on"
    fi
    echo "----------------------------------------------------------------------"
}

health_sudo_history() {
    log "Recent 'sudo' Command History from Auth Logs"
    sudo grep 'sudo:' /var/log/auth.log | tail -n 20 || echo "No recent sudo activity found."
}

health_scan_project_logs() {
    log "Scanning All Project Logs for Recent Errors/Warnings"

    prompt "How many lines of output per log file? [default: 15]: " max_lines
    max_lines=${max_lines:-15}

    local found_errors=false

    sudo find /var/www -maxdepth 2 -type f -name "project.conf" | while read -r conf_file; do
        local project_path
        project_path=$(dirname "$conf_file")
        local project_name
        project_name=$(basename "$project_path")
        
        echo -e "\n\e[1;34m========== Project: $project_name ==========\e[0m"
        echo -e "Path: \e[90m$project_path\e[0m"

        if [ ! -d "$project_path/logs" ]; then
            echo "(No logs directory found)"
            continue
        fi

        for component_log_dir in "$project_path"/logs/*; do
            [ -d "$component_log_dir" ] || continue
            local component
            component=$(basename "$component_log_dir")

            echo -e "\n\e[1;33m--- Component: $component ---\e[0m"

            shopt -s nullglob
            local log_files=(
                "$component_log_dir"/output.log
                "$component_log_dir"/output.log.1
            )

            if [ ${#log_files[@]} -eq 0 ]; then
                echo "(No output.log or output.log.1 files found)"
                continue
            fi

            for log_file in "${log_files[@]}"; do
                echo -e "\n\e[90mFile: $(basename "$log_file")\e[0m"
                if sudo grep -q -i -E "error|warning|failed|exception|traceback|unhandled|critical|panic|fatal|segfault|locked" "$log_file" 2>/dev/null; then
                    sudo grep --color=always -i -C 2 -E "error|warning|failed|exception|traceback|unhandled|critical|panic|fatal|segfault|locked" "$log_file" 2>/dev/null | tail -n "$max_lines"
                    found_errors=true
                else
                    echo "(No errors found.)"
                fi
            done
        done
    done

    if ! $found_errors; then
        log_ok "Scan complete. No obvious errors found in recent logs."
    fi
}


lynis_audit() {
    log "Running Lynis security audit (this may take a minute)..."
    local report_file="/root/lynis-report-$(date +%Y%m%d).txt"
    lynis audit system --quiet --no-colors > "$report_file"
    log_ok "Lynis audit complete. Report saved to $report_file"
    echo ""
    warn "Review important suggestions from Lynis:"
    grep -E "Suggestion|Warning" "$report_file" | cut -c 2- || echo "  No high-priority suggestions or warnings found."
    echo ""
    
    # Add the upload prompt
    prompt_and_upload_file "$report_file"
}


# --- Utility Functions ---
util_manage_systemd() {
    if ! check_dep "fzf"; then return; fi
    log "Interactive Systemd Service Manager"

    local service_list
    service_list=$(systemctl list-units --type=service --all --no-pager --plain | \
                   sed -E 's/( loaded +active +running.*)/\x1b[32m\1\x1b[0m/' | \
                   sed -E 's/( loaded +inactive +dead.*)/\x1b[90m\1\x1b[0m/' | \
                   sed -E 's/( loaded +failed.*)/\x1b[31m\1\x1b[0m/')

    local service_name
    service_name=$(echo -e "$service_list" | \
                   fzf --ansi --prompt="Search for a service > " \
                       --header="[ENTER] to select, [CTRL-C] to cancel" \
                       --preview="systemctl status {1}" --preview-window=right:60%:wrap | awk '{print $1}')

    if [ -n "$service_name" ]; then
        log "Selected service: $service_name"
        sudo systemctl status "$service_name" --no-pager
        echo ""
        prompt "Action: (st)atus, (r)estart, (s)top, (e)nable, (d)isable, (l)ogs? " action
        case $action in
            st) sudo systemctl status "$service_name" --no-pager ;;
            r) sudo systemctl restart "$service_name" && log_ok "Service restarted." ;;
            s) sudo systemctl stop "$service_name" && log_ok "Service stopped." ;;
            e) sudo systemctl enable "$service_name" && log_ok "Service enabled." ;;
            d) sudo systemctl disable "$service_name" && log_ok "Service disabled." ;;
            l) log "Showing logs for $service_name. Press Ctrl+C to exit."; sudo journalctl -fu "$service_name" ;;
            *) warn "Invalid action." ;;
        esac
    else
        echo "No service selected."
    fi
}

util_manage_cron() {
    log "Manage User Cron Jobs"

    local users_with_crons
    users_with_crons=$(sudo find /var/spool/cron/crontabs -type f -printf "%f\n" 2>/dev/null || true)
    echo "Users with existing crontabs:"
    if [ -n "$users_with_crons" ]; then echo "$users_with_crons"; else echo "None"; fi
    echo "---"

    echo "1) Edit a user's crontab manually (with nano)"
    echo "2) Add a new simple cron job (wizard)"
    prompt "Your choice: " cron_choice

    if [[ "$cron_choice" == "1" ]]; then
        prompt "Enter the username whose crontab you want to edit: " cron_user
        if ! id "$cron_user" &>/dev/null; then log_err "User '$cron_user' does not exist."; return; fi
        export EDITOR=nano
        sudo crontab -u "$cron_user" -e
    elif [[ "$cron_choice" == "2" ]]; then
        prompt "Enter username to run the job as (e.g., root, www-data): " cron_user
        prompt "Enter the full command to run: " cron_command
        echo "How often should it run?"
        echo "  1) Hourly (@hourly)"
        echo "  2) Daily (@daily)"
        echo "  3) Weekly (@weekly)"
        echo "  4) Monthly (@monthly)"
        echo "  5) On Reboot (@reboot)"
        prompt "Choose frequency [1-5]: " freq_choice
        local schedule=""
        case $freq_choice in
            1) schedule="@hourly" ;;
            2) schedule="@daily" ;;
            3) schedule="@weekly" ;;
            4) schedule="@monthly" ;;
            5) schedule="@reboot" ;;
            *) log_err "Invalid frequency."; return;;
        esac
        local current_crontab
        current_crontab=$(sudo crontab -u "$cron_user" -l 2>/dev/null || true)
        printf "%s\n%s %s\n" "$current_crontab" "$schedule" "$cron_command" | sudo crontab -u "$cron_user" -
        log_ok "Cron job added for user '$cron_user'."
    else
        warn "Invalid choice."
    fi
}

util_manage_ssl() {
    log "Manage SSL Certificates (Certbot)"
    echo "1) List all current certificates"
    echo "2) Test renewal process for all certificates (Dry Run)"
    echo "3) Renew all certificates"
    prompt "Your choice: " cert_choice
    case $cert_choice in
        1) sudo certbot certificates || true ;;
        2) sudo certbot renew --dry-run || true ;;
        3) sudo certbot renew || true ;;
        *) warn "Invalid choice." ;;
    esac
}

util_litecli() {
    log "Interactive Database Explorer (litecli)"
    if ! check_dep "litecli"; then return; fi
    if ! check_dep "fzf"; then return; fi

    log "Searching for database files in /var/www..."
    local db_files
    db_files=$(sudo find /var/www -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \))

    if [ -z "$db_files" ]; then
        warn "No database files (.db, .sqlite, .sqlite3) found in /var/www."
        return
    fi

    local selected_db
    if ! selected_db=$(echo "$db_files" | fzf --prompt="Select a database to explore > " --height=40% --border); then return; fi

    if [ -z "$selected_db" ]; then
        echo "No database selected."
        return
    fi

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

    # Launching with sudo to ensure permissions are correct
    sudo litecli "$selected_db"
}

util_download_url() {
    log "Download Files from URL"
    if ! check_dep "wget"; then return; fi
    if ! check_dep "tree"; then return; fi
    if ! check_dep "unzip"; then return; fi
    if ! check_dep "tar"; then return; fi

    log "💡 Tip: Uploading Files to Your Server"
    printf "\n\e[33m%s\e[0m\n" "Need to transfer a zip or file from your local machine?"
    printf " You can use temporary file-sharing services like:\n"
    printf "  - \e[36mhttps://TUI-transfer.kcstudio.nl\e[0m\n"
    printf "  - \e[36mhttps://tmpfiles.org\e[0m\n"
    printf "\nUpload your file and paste the download URL into this tool when prompted.\n"
    printf "The script will handle the download and extraction automatically.\n"
    pause

    local urls
    prompt "Enter one or more space-separated URLs to download: " urls
    if [ -z "$urls" ]; then
        warn "No URLs provided."
        return
    fi

    local subfolder
    prompt "Enter a name for the subfolder in '$DOWNLOADS_DIR' to store these files: " subfolder
    if [ -z "$subfolder" ]; then
        warn "No subfolder name provided."
        return
    fi

    local dest_dir="$DOWNLOADS_DIR/$subfolder"
    if [ -d "$dest_dir" ]; then
        warn "Directory '$dest_dir' already exists. Files may be overwritten."
    else
        mkdir -p "$dest_dir"
        log_ok "Created directory '$dest_dir'"
    fi

    log "Starting downloads..."
    for url in $urls; do
        echo "--> Downloading $url"
        wget -P "$dest_dir" "$url"
    done

    log_ok "All downloads complete."
    log "Checking for archives to extract..."

    for file in "$dest_dir"/*; do
        case "$file" in
            *.zip)
                log "Unzipping: $(basename "$file")"
                unzip -o "$file" -d "$dest_dir" && rm "$file"
                ;;
            *.tar.gz|*.tgz)
                log "Extracting tar.gz: $(basename "$file")"
                tar -xzf "$file" -C "$dest_dir" && rm "$file"
                ;;
            *.tar)
                log "Extracting tar: $(basename "$file")"
                tar -xf "$file" -C "$dest_dir" && rm "$file"
                ;;
            *)
                log "Normal file(s): $(basename "$file")"
                ;;
        esac
    done

    log "Displaying contents of download folder:"
    echo "----------------------------------------------------------------------"
    tree "$dest_dir"
    echo "----------------------------------------------------------------------"
    log "Files are located in '$dest_dir'"
}

util_upload_transfer() {
    log "Upload File or Folder with Fuzzy-Finder"
    if ! check_dep "fzf" || ! check_dep "zip"; then return; fi

    local selection
    # Exclude common large/unnecessary directories from the initial search to speed it up and clean the list
    if ! selection=$(sudo find / -path /proc -prune -o -path /sys -prune -o -path /dev -prune -o -path '*/.git' -prune -o -path '*/venv' -prune -o -path '*/node_modules' -prune -o -print 2>/dev/null | fzf --prompt="Select a file or folder to upload > " --height=80% --border); then return; fi

    if [ -z "$selection" ]; then
        warn "No file or folder selected."
        return
    fi

    log_ok "Selected: $selection"

    if [ -d "$selection" ]; then
        # It's a directory, it needs to be zipped
        local dir_name
        dir_name=$(basename "$selection")
        local temp_zip_path="/tmp/upload_${dir_name}_${RANDOM}.zip"

        log "The selection is a directory. It will be zipped for upload."
        log_ok "Excluding common development directories: venv, __pycache__, .git"
        warn "Zipping directory... This may take a moment for large folders."
        
        # The new zip command with exclusions
        if sudo zip -r "$temp_zip_path" "$selection" -x "*venv*" -x "*__pycache__*" -x "*.git*"; then
            log_ok "Directory zipped successfully to temporary file: $temp_zip_path"
            prompt_and_upload_file "$temp_zip_path"
            log "Cleaning up temporary zip file..."
            sudo rm -f "$temp_zip_path"
        else
            log_err "Failed to zip the directory. Please check permissions."
        fi
    elif [ -f "$selection" ]; then
        # It's a single file, upload directly
        prompt_and_upload_file "$selection"
    else
        log_err "The selected path is not a valid file or directory."
    fi
}

util_backup_all_projects() {
    log "Backing Up All Projects"
    
    local project_confs
    project_confs=($(sudo find /var/www -maxdepth 2 -type f -name "project.conf"))
    if [ ${#project_confs[@]} -eq 0 ]; then
        warn "No projects found to back up."
        return
    fi
    
    log "Found ${#project_confs[@]} project(s)."
    echo ""
    echo "Please choose the backup archive structure:"
    echo "  1) Individual Archives: Creates a single .tar.gz containing separate .tar.gz files for each project. (Good for restoring a single project)"
    echo "  2) Direct Folders: Creates a single .tar.gz containing all the project folders directly inside it. (Good for migrating all projects at once)"
    prompt "Your choice [1-2]: " backup_style_choice

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_archive="/var/backups/all-projects-backup-${timestamp}.tar.gz"
    local temp_backup_dir
    temp_backup_dir=$(mktemp -d)
    trap 'log "Cleaning up temporary directory..."; sudo rm -rf "$temp_backup_dir"' RETURN

    if [[ "$backup_style_choice" == "1" ]]; then
        log "Creating individual archives for each project..."
        for conf_file in "${project_confs[@]}"; do
            local project_path
            project_path=$(dirname "$conf_file")
            local project_name
            project_name=$(basename "$project_path")

            log "Archiving project: '$project_name'..."
            if ! sudo tar --exclude='**/venv' -czf "$temp_backup_dir/$project_name.tar.gz" -C "$(dirname "$project_path")" "$project_name"; then
                log_err "Failed to back up '$project_name'. Skipping."
            else
                log_ok "Successfully archived '$project_name'."
            fi
        done

    elif [[ "$backup_style_choice" == "2" ]]; then
        log "Copying all project folders (excluding 'venv') to a temporary location..."
        for conf_file in "${project_confs[@]}"; do
            local project_path
            project_path=$(dirname "$conf_file")
            local project_name
            project_name=$(basename "$project_path")

            log "Copying project: '$project_name'..."
            # Use rsync for its exclude capabilities
            if ! sudo rsync -a --exclude='venv' "$project_path/" "$temp_backup_dir/$project_name/"; then
                 log_err "Failed to copy '$project_name'. Skipping."
            else
                log_ok "Successfully copied '$project_name'."
            fi
        done
    else
        log_err "Invalid choice. Aborting backup."
        return
    fi
    
    # Check if there's anything to archive
    if [ -z "$(ls -A "$temp_backup_dir")" ]; then
        log_err "Temporary backup directory is empty. No projects were backed up successfully. Aborting."
        return
    fi

    log "Creating final master archive..."
    if sudo tar -czf "$backup_archive" -C "$temp_backup_dir" .; then
        log_ok "Master backup archive created at: $backup_archive"
        prompt_and_upload_file "$backup_archive"
    else
        log_err "Failed to create the master backup archive."
    fi
}


util_find() {
    log "Find File Content or Filenames"
    prompt "Search for a (F)ilename or a piece of (T)ext inside files? " search_type

    local search_dir
    prompt "Enter directory to search in (e.g., /var/www or /etc): " search_dir
    if [ ! -d "$search_dir" ]; then log_err "Directory not found."; return; fi

    if [[ "$search_type" == [Ff] ]]; then
        prompt "Enter filename pattern to find (wildcards allowed, e.g., *.log): " filename
        log "Searching for filenames matching '$filename'..."
        sudo find "$search_dir" -name "$filename"

    elif [[ "$search_type" == [Tt] ]]; then
        prompt "Enter text to search for: " text
        prompt "Enter directories to exclude (comma-separated, e.g., venv,node_modules): " exclude_dirs_str

        local exclude_args=()
        IFS=',' read -ra DIRS_TO_EXCLUDE <<< "$exclude_dirs_str"
        for dir in "${DIRS_TO_EXCLUDE[@]}"; do
            if [ -n "$dir" ]; then
                exclude_args+=("--exclude-dir=${dir}")
            fi
        done

        log "Searching for text '$text'..."
        echo "Excluding directories: ${exclude_dirs_str:-None}"
        sudo grep -rI --color=always "${exclude_args[@]}" "$text" "$search_dir" || log_ok "No matches found."
    else
        warn "Invalid choice."
    fi
}

util_swap() {
    log "Set / Change Swap File"
    if [ -n "$(swapon --show)" ]; then
        warn "A swap file of size $(free -h | grep Swap | awk '{print $2}') already exists."
        prompt "This will replace it. Are you sure? (y/N)" swap_confirm
        if [[ "$swap_confirm" != [yY] ]]; then echo "Operation cancelled."; return; fi
    fi
    prompt "Enter desired swap size (e.g., 1G, 2G, 4G): " swap_size
    sudo swapoff /swapfile &>/dev/null || true
    sudo rm -f /swapfile
    sudo fallocate -l "$swap_size" /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    log_ok "Swap file of size $swap_size created and enabled."
    free -h
}

util_goaccess() {
    log "Analyze ALL NGINX Access Logs with GoAccess"
    if ! check_dep "goaccess"; then return; fi

    local report_file="$REPORTS_DIR/nginx_report_$(date +%Y%m%d).html"
    warn "This may take a moment..."

    local temp_report
    temp_report=$(mktemp --suffix=.html)

    {
        # Include ALL plain access logs
        for f in /var/log/nginx/*access*.log /var/log/nginx/*access*.log.[0-9]*; do
            if [ -f "$f" ]; then
                sudo cat "$f"
            fi
        done

        # Include ALL compressed access logs
        for f in /var/log/nginx/*access*.gz; do
            if [ -f "$f" ]; then
                sudo zcat "$f"
            fi
        done

    } 2>/dev/null | sudo goaccess - --log-format=COMBINED -o "$temp_report"

    sudo mv "$temp_report" "$report_file"
    sudo chmod 644 "$report_file"

    echo ""
    log_ok "Interactive HTML report generated at: $report_file"
    prompt_and_upload_file "$report_file"
}

util_file_browser() {
    log "GUI File Browser (Midnight Commander)"
    if ! check_dep "mc"; then return; fi

    echo "You are about to launch Midnight Commander, a powerful visual file manager."
    printf "\n\e[33m%s\e[0m\n" "--- HOW IT WORKS ---"
    printf " The screen is split into two panes. Use the \e[36mTab\e[0m key to switch between them.\n"
    printf " This is useful for copying/moving files from one location to another.\n"
    printf "\n\e[33m%s\e[0m\n" "--- KEYBOARD SHORTCUTS ---"
    printf "  - \e[36mArrow Keys\e[0m:  Navigate up and down.\n"
    printf "  - \e[36mEnter\e[0m:       Enter a directory or execute a file.\n"
    printf "  - \e[36mMouse\e[0m:       You can also use your mouse to navigate!\n"
    printf "  - \e[32mF3 (View)\e[0m:   \e[90mSafely view the contents of a file (read-only).\e[0m\n"
    printf "  - \e[36mF4 (Edit)\e[0m:   \e[90mEdit a text file (uses 'nano').\e[0m\n"
    printf "  - \e[36mF5 (Copy)\e[0m:   \e[90mCopy the selected file(s) to the other pane.\e[0m\n"
    printf "  - \e[36mF6 (Move)\e[0m:   \e[90mMove the selected file(s) to the other pane.\e[0m\n"
    printf "  - \e[31mF8 (Delete)\e[0m: \e[90mDelete the selected file(s) (with confirmation).\e[0m\n"
    printf "  - \e[33mF10 (Quit)\e[0m:  \e[90mExit the file browser and return to the main menu.\e[0m\n"

    read -rp "Press [Enter] to continue..."

    # Launch with a modern dark skin
    sudo mc -S gotar
}

util_configure_backup_retention() {
    log "Configure Automatic Backup Cleanup"
    
    local config_file="/etc/logrotate.d/kcstudio-backups"
    local current_days="Not Set"

    if [ -f "$config_file" ]; then
        # Try to parse the current setting for display
        current_days=$(grep -oP '^\s*rotate\s+\K\d+' "$config_file" || echo "Not Set")
    fi

    echo "This utility configures the server to automatically delete old backup files."
    echo "It uses the standard Linux 'logrotate' service, which runs daily."
    echo -e "Current retention policy: Keep backups for \e[36m$current_days\e[0m days."
    echo ""

    prompt "Enter how many days to keep backup files (e.g., 7 for a week, 30 for a month): " days
    
    # Simple validation to ensure it's a number
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        log_err "Invalid input. Please enter a whole number."
        return
    fi

    log "Setting backup retention to $days days..."

    # Define the configuration content
    local config_content
    config_content=$(cat <<EOF
# This file is managed by the KCStudio Launchpad Toolkit.
# It configures the automatic cleanup of backup files.

/var/backups/*-backup-*.tar.gz
/var/backups/*-backup-*.db.bak
{
    # Check for rotation daily
    daily

    # Keep this many days' worth of backups
    rotate $days

    # Don't throw an error if no backup files are found
    missingok

    # Don't rotate empty files
    notifempty

    # Backups are already compressed, so don't compress them again
    nocompress
}
EOF
)
    # Write the configuration file with sudo
    echo "$config_content" | sudo tee "$config_file" > /dev/null

    log_ok "Backup retention policy updated successfully!"
    warn "The system will now automatically remove backups older than $days days during its daily maintenance."
}


# --- Advanced Config Functions ---
adv_fail2ban() {
    log "Manage Fail2Ban"
    echo "1) List banned IPs (sshd jail)"
    echo "2) Unban an IP"
    prompt "Your choice: " f2b_choice
    case $f2b_choice in
        1) sudo fail2ban-client status sshd ;;
        2)
            prompt "Enter IP to unban: " ip_to_unban
            sudo fail2ban-client set sshd unbanip "$ip_to_unban"
            ;;
        *) warn "Invalid choice." ;;
    esac
}

adv_timezone() {
    log "Configuring System Timezone"
    echo "This will launch an interactive timezone selector."
    sudo dpkg-reconfigure tzdata
    log_ok "Timezone updated. Current time: $(date)"
}

adv_auditd() {
    log "(Opt-in) Advanced System Auditing (auditd)"
    warn "This will install 'auditd' and generate a large volume of detailed system logs."
    warn "This is recommended for advanced security analysis or compliance requirements only."
    prompt "Are you sure you want to install and enable auditd? (y/N)" audit_confirm
    if [[ "$audit_confirm" == [yY] ]]; then
        sudo apt-get update && sudo apt-get install -y auditd audispd-plugins
        sudo systemctl enable --now auditd
        log_ok "auditd has been installed and enabled."
    else
        echo "Installation cancelled."
    fi
}

util_purge_directory() {
    log_err "DANGER ZONE: Safely Purge Files in a Directory"
    warn "This tool will delete ALL FILES inside a specified directory, but leave the directory itself."
    warn "It is designed to clear out millions of small cache or session files safely and quickly."
    echo "This action CANNOT BE UNDONE. Use with extreme caution."

    prompt "Enter the FULL path to the directory you want to purge: " target_dir

    if [ -z "$target_dir" ]; then
        log_err "No directory entered. Aborting."
        return
    fi
    if [ ! -d "$target_dir" ]; then
        log_err "Directory '$target_dir' does not exist. Aborting."
        return
    fi

    # SAFETY CHECKS
    local blocked_dirs=("/" "/boot" "/etc" "/usr" "/var/lib" "/var/log" "/bin" "/sbin" "/lib" "/lib64" "/home")
    for blocked in "${blocked_dirs[@]}"; do
        # Check if the target is a blocked directory itself, or a direct child of a sensitive root dir
        if [ "$target_dir" == "$blocked" ] || [[ "$target_dir" == "$blocked/"* && $(echo "$target_dir" | tr -cd '/' | wc -c) -le 2 ]]; then
             log_err "SAFETY LOCK ENGAGED: Purging critical system directory '$target_dir' is forbidden. Aborting."
             return
        fi
    done
    
    log "Analyzing target directory: $target_dir"
    local inode_count
    inode_count=$(sudo find "$target_dir" | wc -l)
    local disk_size
    disk_size=$(sudo du -sh "$target_dir" | awk '{print $1}')

    echo "--------------------------------------------------------"
    echo -e "  Directory: \e[1;33m$target_dir\e[0m"
    echo -e "  Contains:  \e[1;33m$inode_count\e[0m files and folders"
    echo -e "  Size:      \e[1;33m$disk_size\e[0m"
    echo "--------------------------------------------------------"
    
    warn "You are about to permanently delete all files within this directory."
    read -rp "To confirm, please type the directory path again: " confirm_path

    if [ "$confirm_path" != "$target_dir" ]; then
        log_err "Confirmation failed. Path did not match. Aborting."
        return
    fi

    log "Confirmation accepted. Purging files using 'find ... -delete'..."
    if sudo find "$target_dir" -type f -delete; then
        log_ok "All files within '$target_dir' have been successfully deleted."
    else
        log_err "An error occurred during the deletion process."
    fi
}

# --- Sub-Menu Functions ---
show_journal_menu() {
    while true; do
        show_logo
        echo -e "${WHITE}===================================================================================${RESET}"
        echo -e "  ${WHITE}Systemd Journal Viewer & Alerter${RESET}"
        echo -e "${WHITE}===================================================================================${RESET}"
        echo ""
        echo -e "  ${BLUE}[1]${RESET} Tail Live Journal (All Messages)"
        echo -e "  ${BLUE}[2]${RESET} Tail Live Journal (Errors & Higher)"
        echo -e "  ${BLUE}[3]${RESET} View Last 100 Lines (Errors & Higher)"
        echo ""

        local alert_script="/usr/local/bin/journal-alert.sh"
        if [ -f "$alert_script" ]; then
            echo -e "  ${BLUE}[A]${RESET} Manage Systemd Error Alerts (Currently ACTIVE)"
        else
            echo -e "  ${BLUE}[A]${RESET} Setup Systemd Error Alerts (via Webhook)"
        fi
        
        echo ""
        echo -e "${WHITE}===================================================================================${RESET}"
        echo -e "  ${BLUE}[B]${RESET} Back to Dashboard"
        echo -e "${WHITE}===================================================================================${RESET}"
        prompt "Enter choice: " choice

        case $choice in
            1) log "Tailing all journal messages. Press Ctrl+C to stop."; sudo journalctl -f; pause ;;
            2) log "Tailing errors and higher. Press Ctrl+C to stop."; sudo journalctl -f -p err..alert; pause ;;
            3) log "Last 100 system errors:"; sudo journalctl -n 100 -p err..alert --no-pager; pause ;;
            [Aa])
                if [ -f "$alert_script" ]; then
                    echo ""
                    echo "Alerts are currently active. What would you like to do?"
                    echo "  1) Edit Alert Script (in nano)"
                    echo "  2) Delete Alerts (remove script and cron job)"
                    prompt "Your choice: " manage_choice
                    case $manage_choice in
                        1) sudo nano "$alert_script"; log_ok "Alert script opened for editing.";;
                        2) 
                           (sudo crontab -l 2>/dev/null | grep -v "$alert_script") | sudo crontab -
                           sudo rm -f "$alert_script"
                           log_ok "Alert script and cron job have been deleted."
                           ;;
                        *) warn "Invalid choice." ;;
                    esac
                else
                    if ! check_dep "jq"; then pause; continue; fi
                    log "Setup System Journal Error Alerts via Webhook"
                    warn "This creates a cron job that runs hourly, checking for system errors."
                    echo "If errors are found, it sends them as a JSON payload to a webhook URL."
                    prompt "Enter your webhook URL: " WEBHOOK_URL
                    if [ -z "$WEBHOOK_URL" ]; then log_err "No webhook URL provided. Aborting."; continue; fi

                    log "Creating the alert script at $alert_script..."
                    sudo tee "$alert_script" > /dev/null << 'EOF'
#!/bin/bash
WEBHOOK_URL="__WEBHOOK_URL_PLACEHOLDER__"
ERRORS=$(journalctl --since "65 minutes ago" -p err..alert -o json)
if [ -n "$ERRORS" ] && [ "$ERRORS" != "[]" ]; then
    PAYLOAD=$(echo "$ERRORS" | jq -s '{
        "text": "Systemd Journal Alert on host `hostname`",
        "embeds": [{
            "title": ":warning: High Priority System Errors Detected",
            "description": ("```json\n" + . | tojson | .[:1900] + "\n```"),
            "color": 15745536
        }]
    }')
    curl -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$WEBHOOK_URL"
fi
EOF
                    sudo sed -i "s|__WEBHOOK_URL_PLACEHOLDER__|$WEBHOOK_URL|" "$alert_script"
                    sudo chmod +x "$alert_script"
                    (sudo crontab -l 2>/dev/null | grep -v "$alert_script"; echo "5 * * * * $alert_script") | sudo crontab -
                    log_ok "Alert script and hourly cron job installed for the root user."
                fi
                pause
                ;;
            [Bb]) return 0 ;;
            *) warn "Invalid choice."; pause ;;
        esac
    done
}

show_inode_menu() {
    if ! check_dep "fzf"; then return; fi
    
    while true; do
        show_logo
        echo -e "${WHITE}===================================================================================${RESET}"
        echo -e "  ${WHITE}Filesystem Inode Usage & Management${RESET}"
        echo -e "${WHITE}===================================================================================${RESET}"
        echo "A high inode usage (IUse%) can prevent file creation even with free disk space."
        echo ""
        df -i / # Show the primary filesystem inode usage right away
        echo ""
        echo "--- Tools ---"
        echo -e "  ${BLUE}[1]${RESET} Interactively Explore Inode Usage (Drill-Down)"
        echo -e "  ${BLUE}[2]${RESET} Safely Purge All Files in a Directory..."
        echo ""
        echo -e "${WHITE}===================================================================================${RESET}"
        echo -e "  ${BLUE}[B]${RESET} Back to Dashboard"
        echo -e "${WHITE}===================================================================================${RESET}"
        prompt "Enter choice: " choice

        case $choice in
            1)
                local current_path="/"
                while true; do
                    log "Inspecting Inode Usage in: $current_path"
                    
                    # Generate the list for fzf, including navigation options
                    local fzf_input
                    fzf_input=$(
                        (
                            echo -e "Inode Count\tDirectory/File"
                            echo -e "-----------\t----------------"
                            echo -e "0\t.. (Go Up)"
                            echo -e "0\t(Quit Explorer)"

                            # Efficiently list and count inodes for immediate children
                            cd "$current_path" && for item in * .[^.]* ; do
                                if [[ "$item" == "." || "$item" == ".." ]]; then continue; fi
                                # Use a subshell for find to avoid permission errors stopping the loop
                                count=$( (sudo find "$item" 2>/dev/null | wc -l) || echo "N/A" )
                                echo -e "$count\t$item"
                            done | sort -rn
                        )
                    )

                    local selection
                    selection=$(echo -e "$fzf_input" | fzf --height=80% --border --prompt="Drill Down > " \
                        --header="Navigate with arrows, Enter to select. Current Path: $current_path" \
                        --preview="[ -d '$current_path/$(echo {} | awk -F'\t' '{print \$2}')' ] && sudo ls -lA '$current_path/$(echo {} | awk -F'\t' '{print \$2}')' | head -n 30 || sudo ls -lA '$current_path/$(echo {} | awk -F'\t' '{print \$2}')'")
                    
                    if [ -z "$selection" ]; then break; fi # User pressed Esc

                    local selected_item
                    selected_item=$(echo "$selection" | awk -F'\t' '{print $2}')
                    
                    if [[ "$selected_item" == "(Quit Explorer)" ]]; then
                        break
                    elif [[ "$selected_item" == ".. (Go Up)" ]]; then
                        if [ "$current_path" != "/" ]; then
                            current_path=$(dirname "$current_path")
                        fi
                    else
                        local new_path="$current_path/$selected_item"
                        # Normalize path to handle cases like /..
                        new_path=$(realpath "$new_path")
                        if [ -d "$new_path" ]; then
                            current_path="$new_path"
                        else
                            warn "'$selected_item' is a file, not a directory. Cannot drill down."
                            pause
                        fi
                    fi
                done
                ;;
            2)
                util_purge_directory
                pause
                ;;
            [Bb]) return 0 ;;
            *) warn "Invalid choice."; pause ;;
        esac
    done
}

show_network_menu() {
    while true; do
        show_logo
        echo -e "${WHITE}===================================================================================${RESET}"
        echo -e "  ${WHITE}Network Connection States${RESET}"
        echo -e "${WHITE}===================================================================================${RESET}"
        echo ""
        echo -e "  ${BLUE}[1]${RESET} Show TCP Connection State Summary"
        echo -e "  ${BLUE}[2]${RESET} List All Listening Ports"
        echo -e "  ${BLUE}[3]${RESET} Show Top 20 IPs by Active Connection Count"
        echo ""
        echo -e "${WHITE}===================================================================================${RESET}"
        echo -e "  ${BLUE}[B]${RESET} Back to Dashboard"
        echo -e "${WHITE}===================================================================================${RESET}"
        prompt "Enter choice: " choice

        case $choice in
            1) log "TCP Connection Summary:"; ss -s; pause ;;
            2) log "All Listening Ports (TCP/UDP):"; sudo ss -tulnp; pause ;;
            3)
                log "Top 20 IPs by Active Connection Count:"
                # This command filters for established connections, extracts the remote IP (peer),
                # removes the port, sorts, counts, and shows the highest counts first.
                ss -tn | grep 'ESTAB' | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -n 20
                pause
                ;;
            [Bb]) return 0 ;;
            *) warn "Invalid choice."; pause ;;
        esac
    done
}

# --- Help Menu ---
show_help() {
    (
        show_logo
        echo -e "${WHITE}SERVER MAINTENANCE: THE OPERATOR'S MANUAL${RESET}"
        echo -e "This dashboard allows you to diagnose issues, manage files, and secure the server."
        echo -e "Below is a guide on ${WHITE}WHEN${RESET} and ${WHITE}WHY${RESET} to use each tool."
        echo ""
        
        echo -e "${WHITE}--- SCENARIO 1: \"THE SERVER IS SLOW / UNRESPONSIVE\" ---${RESET}"
        echo -e "  ${BLUE}[1] htop (Interactive Viewer):${RESET}"
        echo -e "      ${GREEN}When:${RESET} The server feels laggy or requests are timing out."
        echo -e "      ${GREEN}Why:${RESET} Shows real-time CPU/RAM usage. Look for bars hitting 100% or processes stuck at top."
        echo -e "  ${BLUE}[5] Resource Overview:${RESET}"
        echo -e "      ${GREEN}When:${RESET} You want a quick sanity check."
        echo -e "      ${GREEN}Why:${RESET} Checks 'Load Average'. If the number is higher than your CPU cores, you are overloaded."
        echo -e "  ${BLUE}[22] Swap File:${RESET}"
        echo -e "      ${GREEN}When:${RESET} RAM is full and apps are crashing (OOM Errors)."
        echo -e "      ${GREEN}Why:${RESET} Adds 'virtual memory' using disk space to prevent crashes during usage spikes."

        echo ""
        echo -e "${WHITE}--- SCENARIO 2: \"I'M OUT OF DISK SPACE\" ---${RESET}"
        echo -e "  ${BLUE}[2] ncdu (Disk Analyzer):${RESET}"
        echo -e "      ${GREEN}When:${RESET} You don't know what is eating your storage."
        echo -e "      ${GREEN}Why:${RESET} Allows you to drill down into folders and find large files instantly."
        echo -e "  ${BLUE}[18] Inode Usage:${RESET}"
        echo -e "      ${GREEN}When:${RESET} Disk usage says 50% free, but you can't create new files."
        echo -e "      ${GREEN}Why:${RESET} You might have too many tiny files (e.g., session files, cache). This tool finds and purges them."
        echo -e "  ${BLUE}[25] Backup Retention:${RESET}"
        echo -e "      ${GREEN}When:${RESET} Backups are filling up your drive."
        echo -e "      ${GREEN}Why:${RESET} Sets a policy to auto-delete backups older than X days."

        echo ""
        echo -e "${WHITE}--- SCENARIO 3: \"SECURITY & ATTACKS\" ---${RESET}"
        echo -e "  ${BLUE}[8/9] Logs (Auth/Firewall):${RESET}"
        echo -e "      ${GREEN}When:${RESET} You suspect someone is trying to hack in."
        echo -e "      ${GREEN}Why:${RESET} 'Auth' shows SSH login attempts. 'Firewall' shows blocked packets."
        echo -e "  ${BLUE}[13] Fail2Ban:${RESET}"
        echo -e "      ${GREEN}When:${RESET} You want to see who has been automatically blocked."
        echo -e "      ${GREEN}Why:${RESET} Lists IP addresses currently in jail for brute-forcing."
        echo -e "  ${BLUE}[14] Lynis Audit:${RESET}"
        echo -e "      ${GREEN}When:${RESET} You want a report card on your server's security."
        echo -e "      ${GREEN}Why:${RESET} Scans the whole system and suggests hardening improvements."

        echo ""
        echo -e "${WHITE}--- SCENARIO 4: \"DEBUGGING CRASHES\" ---${RESET}"
        echo -e "  ${BLUE}[12] Journal & Alerts:${RESET}"
        echo -e "      ${GREEN}When:${RESET} A service (like Nginx or your App) stopped mysteriously."
        echo -e "      ${GREEN}Why:${RESET} The Systemd Journal captures the 'stdout/stderr' of services. Select 'Errors & Higher'."
        echo -e "  ${BLUE}[11] Scan Project Logs:${RESET}"
        echo -e "      ${GREEN}When:${RESET} You want to check ALL your apps at once."
        echo -e "      ${GREEN}Why:${RESET} Greps for 'Error/Exception' in every log file in /var/www."

        echo ""
        echo -e "${WHITE}--- SCENARIO 5: \"MOVING DATA\" ---${RESET}"
        echo -e "  ${BLUE}[3] Midnight Commander (mc):${RESET}"
        echo -e "      ${GREEN}When:${RESET} You need to move/copy complex folder structures."
        echo -e "      ${GREEN}Why:${RESET} A visual, two-pane file manager inside your terminal. Safer than 'mv' or 'cp'."
        echo -e "  ${BLUE}[15] Upload (Transfer):${RESET}"
        echo -e "      ${GREEN}When:${RESET} You need to get a file FROM the server TO your computer."
        echo -e "      ${GREEN}Why:${RESET} Uploads the file to a secure temp host and gives you a QR code/Link."
        echo -e "  ${BLUE}[16] Download from URL:${RESET}"
        echo -e "      ${GREEN}When:${RESET} You need to get a file FROM the web TO the server."
        echo -e "      ${GREEN}Why:${RESET} Auto-downloads and unzips archives into a clean downloads folder."

        echo ""
        echo -e "${WHITE}--- ADVANCED TOOLS ---${RESET}"
        echo -e "  ${BLUE}[27] Network Analysis:${RESET} See exactly what IPs are connected to you right now."
        echo -e "  ${BLUE}[26] GoAccess:${RESET} Turns raw NGINX logs into a beautiful HTML traffic report."
        echo -e "  ${BLUE}[24] Backup ALL:${RESET} Creates a master disaster-recovery archive of everything in /var/www."
        echo ""
        echo -e "${YELLOW}(Press 'q' to quit help)${RESET}"
    ) | less -R
}


# --- Main Menu Loop ---
while true; do
    show_logo
    echo -e "${WHITE}===================================================================================${RESET}"
    echo -e "  ${WHITE}Server Maintenance & Utilities${RESET}"
    echo -e "${WHITE}===================================================================================${RESET}"
    echo ""
    echo -e "  ${WHITE}--- LIVE MONITORING ---${RESET}"
    echo -e "  ${BLUE}[1]${RESET} Interactive Process Viewer (htop)"
    echo -e "  ${BLUE}[2]${RESET} Disk Usage Analyzer (ncdu)"
    echo -e "  ${BLUE}[3]${RESET} GUI File Browser (Midnight Commander)"
    echo -e "  ${BLUE}[4]${RESET} Database Explorer (litecli)"
    echo ""
    echo -e "  ${WHITE}--- SYSTEM SNAPSHOTS ---${RESET}"
    echo -e "  ${BLUE}[5]${RESET} Resource Overview (CPU/RAM/Load)"
    echo -e "  ${BLUE}[6]${RESET} Disk Usage Summary (df -h)"
    echo -e "  ${BLUE}[7]${RESET} Active Network Ports (ss -tulnp)"
    echo ""
    echo -e "  ${WHITE}--- LOGS & SECURITY ---${RESET}"
    echo -e "  ${BLUE}[8]${RESET} View SSH Auth Logs"
    echo -e "  ${BLUE}[9]${RESET} View Firewall Logs"
    echo -e "  ${BLUE}[10]${RESET}Check Sudo History"
    echo -e "  ${BLUE}[11]${RESET}Scan All Project Logs for Errors"
    echo -e "  ${BLUE}[12]${RESET}System Journal & Alerts... (Submenu)"
    echo -e "  ${BLUE}[13]${RESET}Manage Fail2Ban"
    echo -e "  ${BLUE}[14]${RESET}Run Lynis Security Audit"
    echo ""
    echo -e "  ${WHITE}--- FILE OPERATIONS ---${RESET}"
    echo -e "  ${BLUE}[15]${RESET}Upload File/Folder (Transfer)"
    echo -e "  ${BLUE}[16]${RESET}Download Files from URL"
    echo -e "  ${BLUE}[17]${RESET}Find File or Text"
    echo -e "  ${BLUE}[18]${RESET}Inode Usage & Cleanup... (Submenu)"
    echo ""
    echo -e "  ${WHITE}--- CONFIGURATION & BACKUP ---${RESET}"
    echo -e "  ${BLUE}[19]${RESET}Manage Systemd Services"
    echo -e "  ${BLUE}[20]${RESET}Manage User Cron Jobs"
    echo -e "  ${BLUE}[21]${RESET}SSL Certificates (Certbot)"
    echo -e "  ${BLUE}[22]${RESET}Configure Swap File"
    echo -e "  ${BLUE}[23]${RESET}System Timezone"
    echo -e "  ${BLUE}[24]${RESET}Backup ALL Projects"
    echo -e "  ${BLUE}[25]${RESET}Configure Backup Retention"
    echo -e "  ${BLUE}[26]${RESET}NGINX Traffic Report (GoAccess)"
    echo ""
    echo -e "  ${WHITE}--- ADVANCED DIAGNOSTICS ---${RESET}"
    echo -e "  ${BLUE}[27]${RESET}Network Connection Analysis... (Submenu)"
    echo -e "  ${BLUE}[28]${RESET}Install Auditd (Auditing)"
    echo ""
    echo -e "${WHITE}===================================================================================${RESET}"
    echo -e "  ${BLUE}[B]${RESET} Back to Hub              ${BLUE}[H]${RESET} Help & Scenarios"
    echo -e "${WHITE}===================================================================================${RESET}"
    prompt "Enter choice: " main_choice

    case $main_choice in
        1) health_htop ;;
        2) health_ncdu ;;
        3) util_file_browser ;;
        4) util_litecli ;;
        5) health_overview; pause ;;
        6) health_disk_usage; pause ;;
        7) health_net_listeners; pause ;;
        8) health_ssh_log; pause ;;
        9) health_ufw_log; pause ;;
        10) health_sudo_history; pause ;;
        11) health_scan_project_logs; pause ;;
        12) show_journal_menu ;;
        13) adv_fail2ban; pause ;;
        14) lynis_audit; pause ;;
        15) util_upload_transfer; pause ;; 
        16) util_download_url; pause ;;
        17) util_find; pause ;;
        18) show_inode_menu ;;
        19) util_manage_systemd; pause ;;
        20) util_manage_cron; pause ;;
        21) util_manage_ssl; pause ;;
        22) util_swap; pause ;;
        23) adv_timezone; pause ;;
        24) util_backup_all_projects; pause ;;
        25) util_configure_backup_retention; pause ;; 
        26) util_goaccess; pause ;;
        27) show_network_menu ;;
        28) adv_auditd; pause ;;
        [Hh]) show_help ;;
        [Bb]) exit 0 ;;
        *) warn "Invalid choice." ; pause ;;
    esac
done