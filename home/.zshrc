ZSH_DISABLE_COMPFIX=true 

# Disable OhMyZSH!'s magic functions (e.g. safe pasting)
DISABLE_MAGIC_FUNCTIONS=true

# .zshrc profiling (closes at the end of the file)
if (( ${+ZSH_PROFILING} )); then
	zmodload zsh/zprof
fi

# Profiles performances of the .zshrc configuration
function zerperf() {
	ZSH_PROFILING=true zsh -c "source ~/.zshrc && exit"
}

# Load required ZSH modules
zmodload zsh/mathfunc

# Disable bang history (allows to input '!' characters without escaping)
unsetopt BANG_HIST

# Disable history expansion
set +H

# Increase history capacity
export HISTSIZE=10000000
export SAVEHIST=10000000
export HISTFILE=$HOME/.zsh_history

# Load modules
source ~/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Enable partial path autocompletion
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Keybindings
bindkey ";5C" forward-word
bindkey ";5D" backward-word

# Load ADF
source $HOME/autodotfiles/index.zsh

# .zshrc profiling
if (( ${+ZSH_PROFILING} )); then
	PROFILING_PATH="$TEMPDIR/zshrc-profiling.txt"
	zprof > "$PROFILING_PATH"
	cat "$PROFILING_PATH"
	echo Profiling informations written to: "$PROFILING_PATH"
fi
