
# Allow to sign Git commits with GPG
export GPG_TTY=$(tty)

# Integration for Rust (if installed)
if [[ -f ~/.cargo/env ]]; then
	source ~/.cargo/env
fi

# Integration for Go
if [[ -d ~/go ]]; then
    export GOPATH=$HOME/go
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
fi

# Integration for Python
export PATH="$HOME/.local/bin:$PATH"

# Integration for Volta
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Integration for PNPM
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Integration for FZF
source ~/.fzf.zsh

# # Integration for Zoxide
# export _ZO_DATA_DIR="$ADF_ASSETS_DIR/zoxide"
# ZOXIDE_LOAD_FILE="$ADF_ASSETS_DIR/zoxide.zsh"

# if [[ ! -f $ZOXIDE_LOAD_FILE ]]; then
# 	zoxide init zsh > "$ZOXIDE_LOAD_FILE"
# fi

# # NOTE: Forced to "source" as a simple "eval" isn't enough to declare aliases
# source "$ZOXIDE_LOAD_FILE"
