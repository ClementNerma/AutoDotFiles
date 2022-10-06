#
# This file contains the default configuration used by all other ZSH files
# Its content can be overriden by the `local/config.zsh` file
#

# Is this my main computer?
# Set to '1' if it is
export ADF_CONF_MAIN_PERSONAL_COMPUTER=0

# Path to the restoration script
export ADF_CONF_RESTORATION_SCRIPT="/usr/local/bin/zerrestore"

# Temporary path (must be on a VERY FAST storage) where Youtube-DL downloaded files are put
# They are moved after the download has been finished, to avoid problems with parallel downloads
export ADF_CONF_YTDL_TEMP_DL_DIR_PATH="/tmp/ytdl-videos"

# Backup path for sessions (WSL-only)
export ADF_CONF_WSL_BACKUP_SESSION_DIR="/mnt/c/Temp/SessionBackup"

# Backup path for sessions' compilation (WSL-only) - must end with `.7z` extension
export ADF_CONF_WSL_BACKUP_SESSION_COMPILATION="$ADF_CONF_WSL_BACKUP_SESSION_DIR/session-backups.7z"

# CRON tasks' logs directory
export ADF_CONF_CRON_LOGS_DIR="$ADF_ASSETS_DIR/cron-logs"

# Default bandwidth limit for the 'ytdl' function
# Can be overriden with the YTDL_LIMIT_BANDWIDTH variable
export ADF_CONF_YTDL_DEFAUT_LIMIT_BANDWIDTH="1G"

# Bandwidth limit to use when repairing a Youtube-DL playlist with the "ytrepairres" commands
# This is required in order to avoid temporary IP bans on most websites
export ADF_CONF_YTDL_REPAIRRES_LIMIT_BANDWIDTH="5M"

