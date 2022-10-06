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

# Load required ZSH modules
zmodload zsh/mathfunc

# Determine if ADF is launching for the first time in this terminal
# or if it's reloading
if [[ -z $ADF_RELOADING ]]; then
	export ADF_RELOADING=0
else
	export ADF_RELOADING=1
fi

# Determine if current environment is WSL
if grep -q microsoft /proc/version; then
	command rm -rf "$ADF_DIR/linux"
	export IS_WSL_ENV=1
	export ENV_NAME_STR="wsl"
else
	command rm -rf "$ADF_DIR/wsl"
	export IS_WSL_ENV=0
	export ENV_NAME_STR="linux"
fi

if [[ -f $HOME/.autodotfiles-just-installed ]]; then
	export ADF_JUST_INSTALLED=1
	export ADF_JUST_UPDATED=1
	command rm "$HOME/.autodotfiles-just-installed"
else
	export ADF_JUST_INSTALLED=0
fi

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

# Set path to the external scripts directory
export ADF_EXTERNAL_DIR="$ADF_DIR/external"

# Set path to the files list
export ADF_FILES_LIST="$HOME/.autodotfiles-files-list.txt"

# Load the default configuration file
source "$ADF_DIR/config.zsh"

# Load the local configuration file
source "$ADF_USER_DIR/config.zsh"

# Load display functions
source "$ADF_DIR/display.zsh"

# Load common utilities usable by the installer
for script in "$ADF_DIR/preutils/"**/*; do
	source "$script"
done

# Load the updater
source "$ADF_DIR/updater.zsh"

# Ensure the restoration script is in place
if [[ ! -f $ADF_CONF_RESTORATION_SCRIPT || $ADF_JUST_INSTALLED = 1 ]]; then
	zerupdate_restoration_script
fi

# Load the backupers
source "$ADF_DIR/backuper.zsh"

# Run the installer
export ADF_INSTALLER_ABORTED=0

source "$ADF_DIR/components.zsh"

# Exit if the installer aborted
if (( $ADF_INSTALLER_ABORTED )); then
	return
fi

# Set path to platform-specific scripts
export ADF_ENV_DIR="$ADF_DIR/env/$ENV_NAME_STR"

# Load platform-specific configuration
source "$ADF_ENV_DIR/env.zsh"

# Load the local configuration
source "$ADF_USER_DIR/env.zsh"

# Allow fast reloading of this file after changes
alias reload="source ${(%):-%x}"

# # Load the script for the main computer (if applies)
# if [ $ADF_CONF_MAIN_PERSONAL_COMPUTER = 1 ]; then
# 	source "$ADF_DIR/main-pc.zsh"
# fi

# Ensure main directories are defined
if [[ -z $HOMEDIR ]]; then echoerr "Directory variable \z[green]°\$HOMEDIR\z[]° is not defined!"; fi
if [[ -z $TEMPDIR ]]; then echoerr "Directory variable \z[green]°\$TEMPDIR\z[]° is not defined!"; fi
if [[ -z $PLOCALDIR ]]; then echoerr "Directory variable \z[green]°\$PLOCALDIR\z[]° is not defined!"; fi
if [[ -z $TRASHDIR ]]; then echoerr "Directory variable \z[green]°\$TRASHDIR\z[]° is not defined!"; fi
if [[ -z $DLDIR ]]; then echoerr "Directory variable \z[green]°\$DLDIR\z[]° is not defined!"; fi
if [[ -z $SOFTWAREDIR ]]; then echoerr "Directory variable \z[green]°\$SOFTWAREDIR\z[]° is not defined!"; fi
if [[ -z $PROJDIR ]]; then echoerr "Directory variable \z[green]°\$PROJDIR\z[]° is not defined!"; fi
if [[ -z $WORKDIR ]]; then echoerr "Directory variable \z[green]°\$WORKDIR\z[]° is not defined!"; fi
if [[ -z $LOCBAKDIR ]]; then echoerr "Directory variable \z[green]°\$LOCBAKDIR\z[]° is not defined!"; fi

if [[ -n $HOMEDIR && ! -d $HOMEDIR ]]; then echoerr "Home directory at location \z[yellow]°$HOMEDIR\z[]° does not exist!"; fi

if [[ -z $HOMEDIR || -z $PLOCALDIR || ! -d $HOMEDIR || -z $DLDIR || -z $PROJDIR || -z $WORKDIR || -z $TEMPDIR || -z $SOFTWAREDIR || -z $TRASHDIR || -z $LOCBAKDIR ]]; then
	read "?Press <Enter> to exit, or <Ctrl+C> to get a without-AutoDotFiles ZSH prompt ('zerupdate' command will be available) "
	exit
fi

# Ensure these directories exist
if [[ ! -d $TEMPDIR ]]; then mkdir -p "$TEMPDIR"; fi
if [[ ! -d $PLOCALDIR ]]; then mkdir -p "$PLOCALDIR"; fi
if [[ ! -d $DLDIR ]]; then mkdir -p "$DLDIR"; fi
if [[ ! -d $TRASHDIR ]]; then mkdir -p "$TRASHDIR"; fi
if [[ ! -d $PROJDIR ]]; then mkdir -p "$PROJDIR"; fi
if [[ ! -d $WORKDIR ]]; then mkdir -p "$WORKDIR"; fi
if [[ ! -d $SOFTWAREDIR ]]; then mkdir -p "$SOFTWAREDIR"; fi
if [[ ! -d $LOCBAKDIR ]]; then mkdir -p "$LOCBAKDIR"; fi

# Ensure the 'open' function is defined
if ! typeset -f open > /dev/null; then echowarn "WARNING: contractual 'open' command is not defined. 'open'-related functions won't work correctly."; fi
if ! typeset -f opens > /dev/null; then echowarn "WARNING: contractual 'opens' command is not defined. 'opens'-related functions won't work correctly."; fi

# Set path to the functions directory
for script in "$ADF_DIR/functions/"**/*; do
	source "$script"
done

# Dir hashes
hash -d Home="$HOMEDIR"
hash -d Projects="$PROJDIR"
hash -d Work="$WORKDIR"
hash -d Downloads="$DLDIR"
hash -d Temp="$TEMPDIR"
hash -d Software="$SOFTWAREDIR"

# Load software
source "$ADF_DIR/software.zsh"

# Load platform-specific scripts
source "$ADF_ENV_DIR/script.zsh"

# Ensure the 'psymlink' function is defined
if ! typeset -f psymlink > /dev/null; then echowarn "WARNING: contractual 'psymlink' command is not defined."; fi

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
  if zer_filter_history "$1" ; then
      print -sr -- "${1%%$'\n'}"
      fc -p
  else
      return 1
  fi
}

# Go to the a specific folder on startup, except if the shell has been started in a custom directory
function gostartupdir() {
	if [[ $PWD = $HOME || $PWD = $HOMEDIR ]] || [[ -d $ALTERNATE_HOMEDIR && $PWD = $ALTERNATE_HOMEDIR ]]; then
		cd "$ADF_STARTUP_DIR"
	fi
}

gostartupdir

# Run a command and exit if required
if [[ $1 = "--just-run" && -n $2 ]]; then
	${@:2}
	ADF_JUST_RUN_RET=$? 
	if (( $ADF_JUST_RUN_RET )); then
		return $ADF_JUST_RUN_RET
	fi
elif (( $ADF_CHECK_CRONY_FAILURES_STARTUP )) && ! (( $ADF_RELOADING )); then
	crony check
fi
