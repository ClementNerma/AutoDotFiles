#
# This file contains the default configuration used by all other ZSH files
# Its content can be overriden by the `local/config.zsh` file
#

# Is this my main computer?
# Set to '1' if it is
export ADF_CONF_MAIN_PERSONAL_COMPUTER=0

# Path to the restoration script
export ADF_CONF_RESTORATION_SCRIPT="/usr/local/bin/zerrestore"

# Check Crony failures at startup
export ADF_CHECK_CRONY_FAILURES_STARTUP=1

# Update path for 'zerupdate'
export ADF_UPDATE_PATH=""

# Key filename for Git
export ADF_GIT_SSH_PRIVATE_KEY_FILENAME="id_rsa"

# Number of rounds for (de-)obfuscation
export ADF_OBF_ROUNDS=3
