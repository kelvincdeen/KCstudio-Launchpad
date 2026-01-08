# Changelog

## [2.0.0] - 2025-01-08

### Added
* **Upload Integration:** Integrated `TUI-transfer` to upload backups and reports directly from the CLI and generate shareable download links.
* **System Dashboard:** `SecureCore` now persists after setup, providing a menu to easily add or remove admin users (handling SSH keys and sudoers).
* **Traffic Stats:** Added a dashboard in `ManageApp` to view hit counts (24h/30d) for all domains (requires v2.0 project structure).
* **Webhook Alerts:** Added a daemon in `ServerMaintenance` to monitor system logs and dispatch error notifications via webhook.
* **Smart Restore:** Backup restoration now supports direct URLs and automatically handles `.zip` extraction.
* **Backup Retention:** Added a utility to configure automatic deletion of old backups based on age.
* **Inode Tools:** Added an interactive explorer and bulk purge tool for diagnosing storage issues caused by high file counts.

### Changed
* **UX/UI Overhaul:** Standardized colors, headers, and navigation ([B]ack buttons) across all scripts for a consistent experience.
* **HTTPS Catch-All:** The default “Black Hole” server block now handles port 443 using snakeoil certificates to properly drop IP scanners without handshake errors.
* **Script Resolution:** The hub now discovers sub-scripts dynamically, removing the need to rename files when updating.
* **NGINX Logging:** Projects now write to isolated access and error log files rather than the global log.
* **Log Rotation:** Application logs (debug) now rotate weekly; NGINX logs (compliance) rotate monthly.
* **Safety Wrappers:** NGINX config edits now enforce a syntax check before reloading.

### Fixed
* **Setup Robustness:** Added checks for `/run/sshd` to prevent setup failures on minimal OS images.
* **Permissions:** Fixed overly strict permissions on restored log directories.
