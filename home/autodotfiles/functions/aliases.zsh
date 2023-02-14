
# Shortcuts for main directories in paths
alias gohome="cd $HOMEDIR"
alias gotemp="cd $TEMPDIR"
alias godl="cd $DLDIR"
alias gotrash="cd $TRASHDIR"
alias goproj="cd $PROJDIR"
alias gowork="cd $WORKDIR"
alias gosoft="cd $SOFTWAREDIR"

# Run Bash
alias bash="BASH_NO_ZSH=true bash"

# Software: Exa
alias ls="exa --all --long --group-directories-first --color-scale --binary"
alias tree="ls --tree"

# Software: Bat
alias cat="bat --theme=base16"

# Software: Git
alias ga="git add"
alias gb="git checkout -b"
alias gd="git diff"
alias gds="git diff --staged"
alias gs="gitui"
alias gr="git reset"
alias gl="git log"
alias glo="git log --oneline"
alias gc="git checkout"
alias gp="git push"
alias gpf="git push --force-with-lease"

# Software: 'ytdl'
alias yd="ytdl dl"
alias ytsync="ytdl sync"

function yu() {
    yd "${@:2}" --cookie-profile "$1"
}

# Set the default editor
export EDITOR="hx"
alias nano="$EDITOR"
