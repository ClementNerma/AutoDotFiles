#!/usr/bin/zsh

#
# This file is the main loader of AutoDotFiles
# It is loaded during the execution of ~/.zshrc
# The goal is to use a separate file for custom definitions and thus be able to reload just that, instead of
#  reloading the whole configuration each time ; as well as to keep the ~/.zshrc file as clean and simple as possible.
#

# Fix required to avoid the occassional following error:
# > sh: 0: getcwd() failed: No such file or directory
# when running some commands like `service`
cd "."

# Set path to the main script of AutoDotFiles
export ADF_ENTRYPOINT="${(%):-%x}"

# Set path to AutoDotFiles files
export ADF_DIR=$(dirname "$ADF_ENTRYPOINT")

# Set path to local directory
export ADF_USER_DIR="$ADF_DIR-user"

# Set path to cache directory
export ADF_DATA_DIR="$ADF_USER_DIR/data"

# Set path to data directory
export ADF_ASSETS_DIR="$ADF_DIR-assets"

# Set path to binaries directory
export ADF_BIN_DIR="$ADF_ASSETS_DIR/bin"

# Register the local binaries directory in PATH
export PATH="$ADF_BIN_DIR:$PATH"

# Create base directories
if [[ ! -d $ADF_DATA_DIR ]]; then mkdir "$ADF_DATA_DIR"; fi
if [[ ! -d $ADF_ASSETS_DIR ]]; then mkdir "$ADF_ASSETS_DIR"; fi
if [[ ! -d $ADF_BIN_DIR ]]; then mkdir "$ADF_BIN_DIR"; fi

# Set path to the config directory
export ADF_CONFIG_FILES_DIR="$ADF_DIR/config"

# Set path to the files list
export ADF_FILES_LIST="$HOME/.autodotfiles-files-list.txt"

# Load the default configuration file
source "$ADF_DIR/config.zsh"

# Load display functions
source "$ADF_DIR/display.zsh"

# Load common utilities usable by the installer
source "$ADF_DIR/preutils.zsh"

# Load the updater
source "$ADF_DIR/updater.zsh"

# Load the backupers
source "$ADF_DIR/backuper.zsh"

# Run the installer
source "$ADF_DIR/components.zsh"

# Exit if the installer aborted
if (( $ADF_INSTALLER_ABORTED )); then
	return
fi

# Determine if current environment is WSL
if grep -q microsoft /proc/version; then
	source "$ADF_DIR/env/wsl.zsh"
else
	source "$ADF_DIR/env/bare.zsh"
fi

# Load the local configuration
source "$ADF_USER_DIR/env.zsh"

# Allow fast reloading of this file after changes
alias reload="source ${(%):-%x}"

# Ensure main directories are defined
if [[ -z $HOMEDIR ]]; then echoerr "Directory variable \z[green]°\$HOMEDIR\z[]° is not defined!"; fi
if [[ -z $TEMPDIR ]]; then echoerr "Directory variable \z[green]°\$TEMPDIR\z[]° is not defined!"; fi
if [[ -z $TRASHDIR ]]; then echoerr "Directory variable \z[green]°\$TRASHDIR\z[]° is not defined!"; fi
if [[ -z $DLDIR ]]; then echoerr "Directory variable \z[green]°\$DLDIR\z[]° is not defined!"; fi
if [[ -z $SOFTWAREDIR ]]; then echoerr "Directory variable \z[green]°\$SOFTWAREDIR\z[]° is not defined!"; fi
if [[ -z $PROJDIR ]]; then echoerr "Directory variable \z[green]°\$PROJDIR\z[]° is not defined!"; fi
if [[ -z $LOCBAKDIR ]]; then echoerr "Directory variable \z[green]°\$LOCBAKDIR\z[]° is not defined!"; fi

if [[ -n $HOMEDIR && ! -d $HOMEDIR ]]; then echoerr "Home directory at location \z[yellow]°$HOMEDIR\z[]° does not exist!"; fi

if [[ -z $HOMEDIR || ! -d $HOMEDIR || -z $DLDIR || -z $PROJDIR || -z $TEMPDIR || -z $SOFTWAREDIR || -z $TRASHDIR || -z $LOCBAKDIR ]]; then
	read "?Press <Enter> to exit, or <Ctrl+C> to get a without-AutoDotFiles ZSH prompt ('zerupdate' command will be available) "
	exit
fi

# Ensure these directories exist
if [[ ! -d $TEMPDIR ]]; then mkdir -p "$TEMPDIR"; fi
if [[ ! -d $DLDIR ]]; then mkdir -p "$DLDIR"; fi
if [[ ! -d $TRASHDIR ]]; then mkdir -p "$TRASHDIR"; fi
if [[ ! -d $PROJDIR ]]; then mkdir -p "$PROJDIR"; fi
if [[ ! -d $SOFTWAREDIR ]]; then mkdir -p "$SOFTWAREDIR"; fi
if [[ ! -d $LOCBAKDIR ]]; then mkdir -p "$LOCBAKDIR"; fi

# Set path to the functions directory
for script in "$ADF_DIR/functions/"**/*; do
	source "$script"
done

# Load software
source "$ADF_DIR/software.zsh"

# Load the local script
source "$ADF_USER_DIR/script.zsh"

# Load the startup script
# source "$ADF_DIR/startup.zsh"

if [[ -z $ADF_STARTUP_DIR ]]; then
	echowarn "WARNING: Contractual '\$ADF_STARTUP_DIR' variable was not set by the local script."
	export ADF_STARTUP_DIR="$HOMEDIR"
fi

# Filter the commands to put in the history
function zshaddhistory() {
    emulate -L zsh

	if [[ "$1" == "open "*  || "$1" == "opene "* || "$1" == "z "* ]]; then
		return 1
	fi

	print -sr -- "${1%%$'\n'}"
	fc -p
}

# Go to the a specific folder on startup, except if the shell has been started in a custom directory
if [[ $PWD = $HOME || $PWD = $HOMEDIR || $PWD = $ADF_STARTUP_DIR ]]; then
	cd "$ADF_STARTUP_DIR"
fi

# Run a command and exit if required
if [[ $1 = "--just-run" && -n $2 ]]; then
	${@:2}
	ADF_JUST_RUN_RET=$? 
	if (( $ADF_JUST_RUN_RET )); then
		return $ADF_JUST_RUN_RET
	fi
elif [[ $1 = "--start-with" && -n $2 ]]; then
	${@:2}
elif [[ ! -z $ADF_START_WITH ]]; then
	eval "$ADF_START_WITH"
elif (( $ADF_CHECK_CRONY_FAILURES_STARTUP )); then
	crony check
fi
