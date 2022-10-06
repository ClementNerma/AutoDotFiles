#
# This file is a run during shell startup only on WSL
# Its role is to setup aliases and make the environment ready to go
#

# Determine path to PowerShell
export WIN_POWERSHELL_PATH=${$(command -v "powershell.exe"):-"/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"}

# Determine path to CMD
export WIN_CMD_PATH=${$(command -v "cmd.exe"):-"/mnt/c/Windows/system32/cmd.exe"}

# Ensure these two exists
if [[ ! -f $WIN_POWERSHELL_PATH ]]; then echoerr "PowerShell executable was not found at path \z[yellow]°$WIN_POWERSHELL_PATH\z[]°!"; fi
if [[ ! -f $WIN_CMD_PATH ]]; then echoerr "CMD executable was not found at path \z[yellow]°$WIN_CMD_PATH\z[]°!"; fi

# Alternate default entry directory that may occur sometimes
export ALTERNATE_HOMEDIR="/mnt/c/WINDOWS/system32"

# Run a Windows command through PowerShell
# e.g. "win echo Hello!" will display "Hello!" by running PowerShell transparently
function win() {
  "$WIN_POWERSHELL_PATH" -command "$@"
}

# Run a Windows command through CMD.EXE
function wincmd() {
  "$WIN_CMD_PATH" /C "$@"
}

# Run a Windows command through PowerShell and use its content in WSL
# This uses "tr" because Window's newline symbols are different than Linux's ones, thus resulting in weird string behaviours
function win2text() {
  "$WIN_POWERSHELL_PATH" "$@" | tr -d "\r"
}

# Run a Windows command through CMD.EXE and use its content in WSL
# This uses "tr" because Window's newline symbols are different than Linux's ones, thus resulting in weird string behaviours
function wincmd2text() {
  "$WIN_CMD_PATH" /C "$@" | tr -d "\r"
}

# Make an alias to a Windows command
# e.g. "winalias mycmd" will allow to use "mycmd" by running PowerShell transparently
function winalias() {
  for name in "$@"; do
    alias "${name}=win ${name}";
  done
}

# Run a Cargo project located in the projects directory, on Windows
function cargextw() {
	win cargo run "--manifest-path=C:\\Users\\$WINUSER\\Projets\\$1\\Cargo.toml" -- ${@:2}
}

# Run a Cargo project located in the projects directory in release mode, on Windows
function cargextwr() {
	win cargo run "--manifest-path=C:\\Users\\$WINUSER\\Projets\\$1\\Cargo.toml" --release -- ${@:2}
}

# Remount a drive in WSL
function remount() {
	sudo umount /mnt/${1:l} 2> /dev/null
	sudo mkdir /mnt/${1:l} 2> /dev/null
	sudo mount -t drvfs "${1:u}:" /mnt/${1:l}
}

# Get IP of host Windows system (can be used to access its ports)
export WSL_HOST_IP=$(awk '/nameserver/ { print $2 }' /etc/resolv.conf)

# Synchronize WSL's time with Windows' one
function wslclocksync() {
  sudo ntpdate time.windows.com
}

# Mount drives in WSL, including removable ones
function mount_wsl_drives() {
  local found_c=0

  for drive in /mnt/*
  do
    local letter=${drive:s/\/mnt\//}
    local chrlen=${#letter}

    if [[ $chrlen == 1 ]]; then
      if [[ $letter != "c" ]] && mountpoint -q "/mnt/$letter"; then
        remount "$letter"
      fi
    fi
  done

  if [[ ! -d /mnt/c ]]; then
    echoerr "Assertion error: \z[magenta]°C:\z[]° drive was not found while mounting WSL drives!"
  fi
}

# Edit a file directly in Sublime Text, even if stored inside WSL
function edit() {
  ( cd "$(dirname "$1")" && /mnt/c/Program\ Files/Sublime\ Text/sublime_text.exe "$(basename "$1")" )
}

# Link a WSL port with a Windows port
function wslport() {
  if [[ -z $1 ]]; then
    echoerr "please specify a port (syntax: wslport <wsl port> [<windows port>]"
    return 1
  fi

  win "Start-Process powershell -ArgumentList '-Command netsh interface portproxy add v4tov4 listenport=${2:-$1} listenaddress=0.0.0.0 connectport=$1 connectaddress=172.18.28.x ; pause' -Verb RunAs"
}

# Copy a file to clipboard
function clip() {
  command cat "$1" | clip.exe
}

# Copy a string to clipboard
function clipstr() {
  echo "$*" | clip.exe
}

# Get the list of all open windows for a given process name
function process_windows() {
  if [[ -z $1 ]]; then
    echoerr "Please provide a process name to check."
    return 1
  fi

  win 'Get-Process'\
       '| Where-Object {$_.MainWindowTitle -ne "" -and $_.ProcessName -eq "'$1'"}'\
       '| Select-Object MainWindowTitle'\
       '| Format-Table -AutoSize -Wrap -HideTableHeaders'\
       '| Out-String -Stream -Width 1000000000'
}

# Platform-dependant symbolic link creation
function psymlink() {
  if [[ -z $1 ]]; then
    echoerr "Please provide the target's path."
    return 1
  fi

  if [[ -z $2 ]]; then
    echoerr "Please provide the link's path."
    return 2
  fi

  if [[ -f $2 || -d $2 || -L $2 ]]; then
    echoerr "Link already exists."
    return 10
  fi

  if ! touch "$2"; then
    echoerr "Failed to create a temporary file at the link's location."
    return 11
  fi

  local link_path=$(realpath "$2")
  local wsl_path=$(wslpath -w "$2")

  if ! command rm "$2"; then
    cehoerr "Failed to delete the temporary file created at the link's location."
    return 12
  fi

  if [[ $(realpath "$1") =~ ^\/mnt\/ ]] || [[ $link_path =~ ^\/mnt\/ ]]; then
    ( cd /mnt/c && wincmd mklink "$wsl_path" "$(wslpath -w "$1")" ">" NUL )
  else
    ln -s "$1" "$2"
  fi
}

# Load main PC exclusive modules
if (( $ADF_CONF_MAIN_PERSONAL_COMPUTER )); then
  source "$ADF_ENV_DIR/session-backuper.zsh"
  source "$ADF_ENV_DIR/rclone.zsh"
fi

# Enable screen provider on Windows
export DISPLAY=":0"

# Mount storage devices on startup (this typically takes 50~100 ms)
mount_wsl_drives
