#
# This file contains the default configuration used by all other ZSH files
# Its content can be overriden by the `local/config.zsh` file
#

# Check Crony failures at startup
export ADF_CHECK_CRONY_FAILURES_STARTUP=1

# Update path for 'zerupdate'
export ADF_UPDATE_PATH=""

# Key filename for Git
export ADF_GIT_SSH_PRIVATE_KEY_FILENAME="id_rsa"

# Number of rounds for (de-)obfuscation
export ADF_OBF_ROUNDS=3

# Host for Unison backup data
export ADF_UNISON_REMOTE_HOST=""

# Path for Unison backup data
export ADF_UNISON_REMOTE_DATA_PATH=""
