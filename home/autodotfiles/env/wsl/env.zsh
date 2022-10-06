#
# This file is run during startup on WSL platform only
# Its role is to configure all required environment variables and options
#

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
export PLOCALDIR="$HOMEDIR/AppData/Local/AutoDotFilesLocalDirectory"

# Main data are located in WSL's own filesystem
export PROJDIR="$HOME/Projets"
export WORKDIR="$HOME/Work"
export TRASHDIR="$HOME/.trasher"

# Open a file or directory in Windows
function open() {
  local topath=${1:-$PWD}

  if [[ ! -f $topath && ! -d $topath && ! -L $topath ]]; then
    echoerr "Target path \z[yellow]°$topath\z[]° was not found!"
    return 1
  fi

  ( cd "$(dirname "$topath")" && explorer.exe "$(basename "$topath")" )
  return 0
}

# Open a file or directory with a specific search
function opens() {
  if [[ -z $1 ]]; then
    echoerr "Please provide a search."
    return 2
  fi

  explorer.exe "search-ms:displayname=$1 - Search Results in $(basename "$PWD")&crumb=System.Generic.String%3A$1&crumb=location:$(wslpath -w "$PWD")"
}