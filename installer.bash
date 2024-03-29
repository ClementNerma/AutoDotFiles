#!/usr/bin/env bash
#
# WARNING:
# This installer should **NOT** contain **ANY** private information, as it is meant to be used on
#  distant servers, computers at work, etc.
#
#

# Fail
function _fail() {
	echo -e "\e[91mERROR: $2\e[0m"
	exit $1
}

# Beginning of the installer!
echo
echo -e "\e[92m=================================\e[0m"
echo -e "\e[92m====== AUTOMATED INSTALLER ======\e[0m"
echo -e "\e[92m=================================\e[0m"

if ! command -v apt &> /dev/null; then
    _fail 3 "Command 'apt' was not found."
fi

if [[ -d /data/data/com.termux ]]; then
	function sudo() {
		"$@"
	}
	
	export ADF_TEMP_DIR="$HOME/.faketemp"
else
	export ADF_TEMP_DIR="/tmp"

	if [ ! -x /usr/bin/sudo ]; then
		echo -e "\e[33m\!/ WARNING: 'sudo' command was not found, installing it for compatibility reasons.\e[0m"
		
		if ! su -s /bin/bash -c "apt install sudo -y" root; then
			_fail 6 "Failed to install 'sudo' package"
		fi
	fi
fi

echo "Selected temporary direcotry: $ADF_TEMP_DIR"

mkdir -p "$ADF_TEMP_DIR"

OFFLINE_INSTALLER_FILENAME="local-installer.bash"

if [[ $1 = "--offline" ]]; then
	if [[ ! -f "$OFFLINE_INSTALLER_FILENAME" ]]; then
		_fail 7 "Offline installer was not found at path: $OFFLINE_INSTALLER_FILENAME"
	fi

	bash "$OFFLINE_INSTALLER_FILENAME"
else
	echo -e "\e[94mDownloading required files...\e[0m"

	sudo apt install git -y

	INSTALL_FROM="$ADF_TEMP_DIR/autodotfiles-github-download-$(date +%s)"
	git clone "https://github.com/ClementNerma/AutoDotFiles.git" "$INSTALL_FROM"

	echo -e "\e[94mLaunching offline installer...\e[0m"
	bash "$INSTALL_FROM/$OFFLINE_INSTALLER_FILENAME"

	echo -e "\e[94mCleaning up offline installer...\e[0m"
	command rm -rf "$INSTALL_FROM"

	echo -e "\e[94mDone!\e[0m"
fi
