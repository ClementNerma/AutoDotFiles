#
# This file contains the default configuration used by all other ZSH files
# Its content can be overriden by the `local/config.zsh` file
#

# Is this my main computer?
# Set to '1' if it is
export ADF_CONF_MAIN_PERSONAL_COMPUTER=0

# Path to the restoration script
export ADF_CONF_RESTORATION_SCRIPT="/usr/local/bin/zerrestore"

# Minimum parallel downloads that have to occur in parallel to enable the temporary path feature
export ADF_CONF_YTDL_TEMP_DL_DIR_THRESOLD=0

# Temporary path (must be on a VERY FAST storage) where Youtube-DL downloaded files are put
# They are moved after the download has been finished, to avoid problems with parallel downloads
export ADF_CONF_YTDL_TEMP_DL_DIR_PATH="/tmp/ytdl-videos"

# Backup path for sessions (WSL-only)
export ADF_CONF_WSL_BACKUP_SESSION_DIR="/mnt/c/Temp/SessionBackup"

# Backup path for sessions' compilation (WSL-only) - must end with `.7z` extension
export ADF_CONF_WSL_BACKUP_SESSION_COMPILATION="$ADF_CONF_WSL_BACKUP_SESSION_DIR/session-backups.7z"

# CRON tasks' logs directory
export ADF_CONF_CRON_LOGS_DIR="$ADF_THISCOMP_DIR/cron-logs"

# Default bandwidth limit for the 'ytdl' function
# Can be overriden with the YTDL_LIMIT_BANDWIDTH variable
export ADF_CONF_YTDL_DEFAUT_LIMIT_BANDWIDTH="999M"

# Bandwidth limit to use when synchronizing a Youtube-DL playlist with the "ytsync" or "ytrepairres" commands
# This is required in order to avoid temporary IP bans on most websites
export ADF_CONF_YTDL_SYNC_LIMIT_BANDWIDTH="5M"

# Bandwidth limit to use when synchronizing a Youtube-DL playlist with the "ytsync" or "ytrepairres" commands
# This is required in order to avoid temporary IP bans on most websites
# Only applies to the v2 algorithm
export ADF_CONF_YTDL_SYNC_LIMIT_BANDWIDTH_V2="25M"
