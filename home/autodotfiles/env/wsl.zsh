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

# Get Windows username (cached for better performance)
export ADF_WSL_USERNAME_CACHE_FILE="$ADF_ASSETS_DIR/wsl-username.txt"

if [[ ! -f $ADF_WSL_USERNAME_CACHE_FILE ]]; then
  export WINUSER=$(powershell.exe -command '$env:UserName' | tr -d "\r")
  printf "$WINUSER" > "$ADF_WSL_USERNAME_CACHE_FILE"
else
  export WINUSER=$(command cat "$ADF_WSL_USERNAME_CACHE_FILE")
fi

# Fail if username couldn't be get
if [[ -z $WINUSER ]]; then
  echoerr "Failed to get username from command-line (see error above)"
  return
fi

# Set up path to main directories
export HOMEDIR="/mnt/c/Users/$WINUSER"
export TEMPDIR="$HOME/.tempdata"
export DLDIR="$HOMEDIR/Downloads"
export SOFTWAREDIR="$HOMEDIR/Logiciels"
export LOCBAKDIR="$HOMEDIR/Sauvegardes/ADF"

# Main data are located in WSL's own filesystem
export PROJDIR="$HOME/Projets"
export TRASHDIR="$HOME/.trasher"

# Alternate default entry directory that may occur sometimes
export ALTERNATE_HOMEDIR="/mnt/c/WINDOWS/system32"

# Set up web browser opening
export BROWSER="$WIN_POWERSHELL_PATH /C start"

# Open a file or directory in Windows
function open() {
  local topath=${1:-$PWD}

  [[ ! -f $topath && ! -d $topath && ! -L $topath ]] && { echoerr "Target path \z[yellow]°$topath\z[]° was not found!"; return 1 }

  ( cd "$(dirname "$topath")" && explorer.exe "$(basename "$topath")" )
  return 0
}

# Run a Windows command through PowerShell
# e.g. "win echo Hello!" will display "Hello!" by running PowerShell transparently
function win() {
  "$WIN_POWERSHELL_PATH" -command "$@"
}

# Same as 'win' but as administrator
function winadmin() {
  [[ -z $1 ]] && { echoerr "please specify a command to run"; return 1 }
  [[ -z $2 ]] || { echoerr "please ONLY specify a command to run"; return 1 }

  # Escape quotes
  local escaped=${${1:gs/\'/\'\'}:gs/\"/\"\"\"}

  # Single quotes are automatically escaped
  win "Start-Process powershell -ArgumentList '-NoExit -Command & { $escaped }' -Verb RunAs"
}

# Remount a drive in WSL
function remount() {
	sudo umount /mnt/${1:l} 2> /dev/null
	sudo mkdir /mnt/${1:l} 2> /dev/null
	sudo mount -t drvfs "${1:u}:" /mnt/${1:l} -o uid=$UID,gid=$GID
}

# Edit a file directly in a native text editor, even if stored inside WSL
function edit() {
  ( cd "$(dirname "$1")" && "$SOFTWAREDIR/Lite XL/lite-xl.exe" "$(basename "$1")" )
}

# Link a WSL port with a Windows port
function wslport() {
  [[ -z $1 ]] && { echoerr "please specify a port (syntax: wslport <wsl port> [<windows port>]"; return 1 }

  winadmin "netsh interface portproxy add v4tov4 listenport=${2:-$1} listenaddress=0.0.0.0 connectport=$1 connectaddress=172.18.28.x"
}

# Open a port on the local network
function openport() {
  [[ -z $1 ]] && { echoerr "please specify a port to open"; return 1 }
  [[ -z $2 ]] || { echoerr "please specify only one port to open"; return 1 }

  local task_name="WSL 2 Firewall Unlock for port: $1"

  winadmin "
    \$remoteport = bash.exe -c \"ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'\"
    \$found = \$remoteport -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

    if (\$found) {
      \$remoteport = \$matches[0];
    } else {
      echo \"The Script Exited, the ip address of WSL 2 cannot be found\";
      exit;
    }

    # Remove Firewall Exception Rules
    iex \"Remove-NetFireWallRule -DisplayName '$task_name' \";

    # Add Exception Rules for inbound and outbound Rules
    iex \"New-NetFireWallRule -DisplayName '$task_name' -Direction Outbound -LocalPort $1 -Action Allow -Protocol TCP\";
    iex \"New-NetFireWallRule -DisplayName '$task_name' -Direction Inbound -LocalPort $1 -Action Allow -Protocol TCP\";

    iex \"netsh interface portproxy delete v4tov4 listenport=$1 listenaddress=0.0.0.0\";
    iex \"netsh interface portproxy add v4tov4 listenport=$1 listenaddress=0.0.0.0 connectport=$1 connectaddress=$(hostname -I)\";
  "
}

# Copy a file to clipboard
function clip() {
  command cat "$1" | clip.exe
}

# Copy a string to clipboard
function clipstr() {
  echo "$*" | clip.exe
}

# Fix for 'fd' (otherwise always getting error '[fd error]: Could not retrieve current directory (has it been deleted?).')
function fd() {
  cd "$PWD" && command fd "$@"
}

# Fix external connection for e.g. Explorer, VSCode, etc.
function fix_socket_connection() {
  local interop_pid=$$
  local pid

  while true ; do
    [[ -e /run/WSL/${interop_pid}_interop ]] && break
    pid=$(ps -p ${interop_pid:-$$} -o ppid=;)
    interop_pid=${pid// /}
    [[ ${interop_pid} = 1 ]] && break
  done

  if [[ ${interop_pid} = 1 ]] ; then
      echo "Failed to find a parent process with a working interop socket.  Interop is broken."
  else
      export WSL_INTEROP=/run/WSL/${interop_pid}_interop
  fi
}

# Enable screen provider on Windows
export DISPLAY=":0"

# Fix socket connection
fix_socket_connection

# Schedule clock fix
# Required as WSL2's clock tends to go out of sync from time to time
crony register timesync --run 'sudo ntpdate pool.ntp.org' --at 'h=*' --ignore-identical

# Fix startup directory
if [[ $PWD = "/mnt/c/Windows" ]] || [[ $PWD = "/mnt/c/Windows/System32" || $PWD = "/mnt/c/Users/$WINUSER/AppData/Local/Microsoft/WindowsApps" ]]; then
  cd "$HOME"
fi
