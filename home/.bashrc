#!/bin/bash

# Bash will by default directly run ZSH
# This is required to fix problems especially with WSL
# To run Bash instead of ZSH, simply run:
#   BASH_NO_ZSH=true bash

if [ "$BASH_NO_ZSH" != "true" ]; then
    export SHELL=/bin/zsh
    exec /bin/zsh -l
fi
