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
export ADF_CONF_YTDL_TEMP_DL_DIR_PATH="/tmp/ytdl"

# Backup path for sessions (WSL-only)
export ADF_CONF_WSL_BACKUP_SESSION_DIR="/mnt/c/Temp/SessionBackup"

# Backup path for sessions' compilation (WSL-only) - must end with `.7z` extension
export ADF_CONF_WSL_BACKUP_SESSION_COMPILATION="$ADF_CONF_WSL_BACKUP_SESSION_DIR/session-backups.7z"

# Check Crony failures at startup
export ADF_CHECK_CRONY_FAILURES_STARTUP=1

# Default bandwidth limit for the 'ytdl' function
# Can be overriden with the YTDL_LIMIT_BANDWIDTH variable
export ADF_CONF_YTDL_DEFAUT_LIMIT_BANDWIDTH="1G"

# Update path for 'zerupdate'
export ADF_UPDATE_PATH=""

# Key filename for Git
export ADF_GIT_SSH_PRIVATE_KEY_FILENAME="id_rsa"

# Number of rounds for (de-)obfuscation
export ADF_OBF_ROUNDS=3
