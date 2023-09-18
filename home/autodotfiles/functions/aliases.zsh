
# Shortcuts for main directories in paths
alias gohome="cd $HOMEDIR"
alias gotemp="cd $TEMPDIR"
alias godl="cd $DLDIR"
alias gotrash="cd $TRASHDIR"
alias goproj="cd $PROJDIR"
alias gosoft="cd $SOFTWAREDIR"

# Run Bash
alias bash="BASH_NO_ZSH=true bash"

# Software: Lsd
alias ls="lsd --almost-all --long --versionsort --group-dirs first --git"
alias tree="ls --tree"

# Software: Bat
alias cat="bat --theme OneHalfDark --style plain"

# Software: Trasher
alias rm="trasher rm"
alias unrm="trasher unrm"

# Software: Git
alias ga="git add"
alias gb="git checkout -b"
alias gm="git commit -m"
alias gs="gitui"
alias gr="git reset"
alias gl="git log"
alias glo="git log --oneline"
alias gc="git checkout"
alias gp="git push"
alias gpf="git push --force-with-lease"

# Software: Neovim
alias nvim="nvim -u $ADF_CONFIG_FILES_DIR/lazy-vim.lua"
alias vi="nvim"

# Software: 'ytdl'
alias ytdl="ytdl -c $ADF_DATA_DIR/ytdl/ytdl-config.json"
alias yd="ytdl dl"
alias ytsync="ytdl sync"

# Set the default editor
export EDITOR="nvim"
alias nano="$EDITOR"
