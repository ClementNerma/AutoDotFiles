#!/usr/bin/zsh

# Run a Windows through PowerShell
# e.g. "win echo Hello!" will display "Hello!" by running PowerShell transparently
function win() {
  powershell.exe -command "$@"
}

# Make an alias to a Windows command
# e.g. "winalias mycmd" will allow to use "mycmd" by running PowerShell transparently
function winalias() {
  for name in "$@"; do
    alias "${name}=win ${name}";
  done
}

# Create project using hand-made template
function create-project () {
  cp -R "$PROJDIR/_Done/Templates/$1" "$2"
  cd "$2"
  bash TEMPLATE_INIT.sh
  rm TEMPLATE_INIT.sh
}

# Run a Cargo project located in the projects directory, on Windows
function cargextw() {
    PROJ_NAME=$1
    shift
	win cargo run "--manifest-path=C:\\Users\\cleme\\Projets\\$PROJ_NAME\\Cargo.toml" -- $*
}

# Run a Cargo project located in the projects directory in release mode, on Windows
function cargextwr() {
    PROJ_NAME=$1
    shift
	win cargo run "--manifest-path=C:\\Users\\cleme\\Projets\\$PROJ_NAME\\Cargo.toml" --release -- $*
}

# Remount a drive in WSL
function remount() {
	sudo umount /mnt/${1:l} 2> /dev/null
	sudo mkdir /mnt/${1:l} 2> /dev/null
	sudo mount -t drvfs "${1:u}:" /mnt/${1:l}
}

# Get Windows username
export WINUSER=$(win '$env:UserName')

# Set up path to main directories
export HOMEDIR="/mnt/c/Users/$WINUSER"
export TEMPDIR="/mnt/c/Temp/__wsltemp"

# Ensure temporary directory exists
if [ ! -d "$TEMPDIR" ]; then
  mkdir -p "$TEMPDIR"
fi

# Go to windows' home directory
alias gowin="cd $HOMEDIR"

# Integration of some Windows tools
winalias code

# Open a file using the Windows association system
open() {
	explorer.exe "$1"
	echo # Fix error status code from "explorer.exe"
}

alias here="open ."

# Software: Docker
alias docker="win docker"
alias docker-compose="win docker-compose"

# Allow fast editing of this file
alias zeditwslrc="nano ~/.zshrc.wsl.zsh && source ~/.zshrc.wsl.zsh"