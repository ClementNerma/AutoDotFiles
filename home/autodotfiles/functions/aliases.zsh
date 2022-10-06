
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
alias gs="git status"
alias gr="git reset"
alias gl="git log"
alias gc="git checkout"
alias gp="git push"
alias gpb="git push --set-upstream origin \$(git rev-parse --abbrev-ref HEAD)"
alias gop="git reflog expire --expire=now --all && git gc --prune=now && git repack -a -d --depth=250 --window=250"

function git() {
    local current=$PWD
    local key_file=0

    while [[ $current != "/" ]]; do
        if [[ -f "$current/$ADF_GIT_SSH_PRIVATE_KEY_FILENAME" ]]; then
            local key_file=1
            break
        fi

        local current=$(dirname "$current")
    done

    if (( $key_file )); then
        GIT_SSH_COMMAND="ssh -i '$current/$ADF_GIT_SSH_PRIVATE_KEY_FILENAME'" command git "$@"
    else
        command git "$@"
    fi
}

# Custom commit command
alias gm="gitcommit"

# Set the default editor
export EDITOR="micro"
alias nano="$EDITOR"
