#
# This file is run during startup on bare Linux platforms only
# Its role is to setup aliases and make the environment ready to go
#

# Set up path to main directories
export HOMEDIR="$HOME"
export TEMPDIR="$ADF_TEMP_DIR"
export TRASHDIR="$HOMEDIR/.trasher"
export DLDIR="$HOMEDIR/Téléchargements"
export SOFTWAREDIR="$HOMEDIR/Logiciels"
export PROJDIR="$HOMEDIR/Projets"
export LOCBAKDIR="$HOMEDIR/Sauvegardes/ADF"

if [[ ! -d $DLDIR ]]; then
    export DLDIR="$HOMEDIR/Downloads"
fi
