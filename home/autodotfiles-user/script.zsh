#
# This file is run during startup on all platforms and is not overriden during updates
# Its role is to setup aliases and make the environment ready to go
#

# Edit this file and reload it
alias zerl="nano ${(%):-%x} && source ${(%):-%x}"

# Startup directory
export ADF_STARTUP_DIR="$PROJDIR"

# Items to put in ADF's local backups
#export ADF_BACKUPS_CONTENT=()

# Put your own commands here
