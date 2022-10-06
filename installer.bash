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

# Get current timestamp
AUTO_INSTALLER_STARTED_AT=$(date +%s)

# Choose a temporary directory
TMPDIR="/tmp/_autodotfiles_autoinstaller_$AUTO_INSTALLER_STARTED_AT"

# Determine the parent directory of the current script
INSTALL_FROM=$(dirname "$CURRPATH")

# Beginning of the installer!
echo
echo -e "\e[92m=================================\e[0m"
echo -e "\e[92m====== AUTOMATED INSTALLER ======\e[0m"
echo -e "\e[92m=================================\e[0m"

arch="$(dpkg --print-architecture)"
if [[ $arch != "amd64" && $arch != "arm64" ]]; then
	echo "ERROR: Unsupported CPU architecture detected: ${arch}"
	_fail 2 "Exiting now."
fi

if [ ! -x /usr/bin ]; then
    _fail 3 "Command 'apt' was not found."
fi

if [ -d "$TMPDIR" ]; then
	_fail 4 "Temporary directory '$TMPDIR' already exists."
fi

if ! mkdir -p "$TMPDIR"; then
	_fail 5 "Failed to create a temporary directory at '$TMPDIR'."
fi

if [ ! -x /usr/bin/sudo ]; then
	echo -e "\e[33m\!/ WARNING: 'sudo' command was not found, installing it for compatibility reasons.\e[0m"
	
	if ! su -s /bin/bash -c "apt install sudo -y" root; then
        _fail 6 "Failed to install 'sudo' package"
    fi
fi

if [[ $1 != "--offline" ]]; then
	echo -e "\e[94mDownloading required files...\e[0m"

	sudo apt install git -y

	INSTALL_FROM="$TMPDIR/AutoDotFiles-github-download"
	git clone "https://github.com/ClementNerma/AutoDotFiles.git" "$INSTALL_FROM"
	bash "$INSTALL_FROM/installer.bash" --offline

	# Exit installer now
	exit
fi

if [ ! -d "$INSTALL_FROM/home" ] || [ ! -d "$INSTALL_FROM/home/autodotfiles" ]; then
	_fail 7 "'home' directory was not found, to download required files from the web don't use the '--offline' flag"
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

if [ -d ~/.oh-my-zsh ]; then
	echo -e "\e[33m\!/ A previous version of \e[32mOh-My-ZSH! \e[33mwas detected ==> backing it up to \e[32m~/.oh-my-zsh.bak\e[33m...\e[0m"
	rm -rf ~/.oh-my-zsh.bak
	mv ~/.oh-my-zsh ~/.oh-my-zsh.bak
fi

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k

cp -a "$INSTALL_FROM/home/." ~/

ls -1A "$INSTALL_FROM/home" > ~/.autodotfiles-files-list.txt
touch ~/.autodotfiles-just-installed

rm -rf "$TMPDIR"

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