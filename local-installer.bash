#!/usr/bin/env bash
#
# WARNING:
# This installer should **NOT** contain **ANY** private information, as it is meant to be used on
#  distant servers, computers at work, etc.
#
#

# Display a number of seconds in a human-readable format
function print_seconds {
	local T=$1
	local D=$((T/60/60/24))
	local H=$((T/60/60%24))
	local M=$((T/60%60))
	local S=$((T%60))
	(( $D > 0 )) && printf '%d days ' $D
	(( $H > 0 )) && printf '%d hours ' $H
	(( $M > 0 )) && printf '%d minutes ' $M
	(( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
	printf '%d seconds\n' $S
}

# Fail
function _fail() {
	echo -e "\e[91mERROR: $2\e[0m"
	exit $1
}

# Get the total number of steps
CURRPATH=$(realpath "$0")

if [[ -z $CURRPATH ]]; then
	_fail 1 "Please run this script as: bash <script name>"
fi

# Define path to temporary directory
if [[ -d /data/data/com.termux ]]; then
	export ADF_TEMP_DIR="$HOME/.faketemp"
else
	export ADF_TEMP_DIR="/tmp"
fi

mkdir -p "$ADF_TEMP_DIR"

# Get current timestamp
AUTO_INSTALLER_STARTED_AT=$(date +%s)

# Choose a temporary directory
TMPDIR="$ADF_TEMP_DIR/_autodotfiles_autoinstaller_$AUTO_INSTALLER_STARTED_AT"

# Determine the parent directory of the current script
INSTALL_FROM=$(dirname "$CURRPATH")

# Beginning of the installer!
echo
echo -e "\e[92m===========================================\e[0m"
echo -e "\e[92m====== AUTOMATED (OFFLINE) INSTALLER ======\e[0m"
echo -e "\e[92m===========================================\e[0m"

if ! command -v apt &> /dev/null; then
    _fail 3 "Command 'apt' was not found."
fi

if [[ -d /data/data/com.termux ]]; then
	function sudo() {
		"$@"
	}
fi

if [ -d "$TMPDIR" ]; then
	_fail 4 "Temporary directory '$TMPDIR' already exists."
fi

if ! mkdir -p "$TMPDIR"; then
	_fail 5 "Failed to create a temporary directory at '$TMPDIR'."
fi

if ! command -v sudo &> /dev/null; then
	echo -e "\e[33m\!/ WARNING: 'sudo' command was not found, installing it for compatibility reasons.\e[0m"
	
	if ! su -s /bin/bash -c "apt install sudo -y" root; then
        _fail 6 "Failed to install 'sudo' package"
    fi
fi

if [ ! -d "$INSTALL_FROM/home" ] || [ ! -d "$INSTALL_FROM/home/autodotfiles" ]; then
	_fail 7 "Installation files were not found (missing either 'home' directory or its content)."
fi

if [ -d ~/autodotfiles ]; then
	_fail 89 "\!/ A previous version of \e[32mAutoDotFiles \e[91mwas detected, cannot continue (please run 'zeruninstall' first)"
fi

if [ -f ~/.zshrc ]; then
	mv ~/.zshrc ~/.zshrc.bak
fi

if [ -f ~/.bashrc ]; then
	mv ~/.bashrc ~/.bashrc.bak
fi

sudo apt update

sudo apt install -yqqq zsh git curl

git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"

cp -a "$INSTALL_FROM/home/." ~/

ls -1A "$INSTALL_FROM/home" > ~/.autodotfiles-files-list.txt
touch ~/.autodotfiles-just-installed

rm -rf "$TMPDIR"

# Create main data directories
mkdir -p ~/.local/share
mkdir -p ~/.config

echo Done\!

# Unset 'sudo' alias if it was set up at the beginning of the script
if [ ! -x /usr/bin/sudo ]; then
	unset -f sudo
fi

# Set default shell to ZSH
sudo chsh -s $(which zsh) $(whoami)

printf "Automated installer completed in "
print_seconds "$(($(date +%s) - ${AUTO_INSTALLER_STARTED_AT}))"

echo ""
echo "> Please restart your shell !"
echo ""