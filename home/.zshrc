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

# Prezto configuration version
if [[ ! -f $HOME/.zpreztorc ]]; then
	echo "Setting up Prezto configuration files..."

	setopt EXTENDED_GLOB

	for rcfile in "$HOME"/.zprezto/runcoms/^README.md(.N); do
		ln -s "$rcfile" "$HOME/.${rcfile:t}"
	done
fi

if ! cmp "$HOME/.zpreztorc" "$HOME/.prezto.zsh" > /dev/null; then
	echo "Updating Prezto configuration..."
	command cat "$HOME/.prezto.zsh" > "$HOME/.zpreztorc"
fi

# Load Prezto
source "$HOME/.zprezto/init.zsh"

# Disable bang history (allows to input '!' characters without escaping)
unsetopt BANG_HIST

# Disable history expansion
set +H

# Disable unused feature to greatly accelerate autocompletion
unsetopt PATH_DIRS

# Disable ZSH command correction
unsetopt correct
unsetopt correct_all

# Custom keybindings
bindkey '^H' backward-kill-word
bindkey '5~' kill-word

# Set cursor to vertical and blocking instead of block and fixed
echo -n '\e[5 q'

# Load ADF
source $HOME/autodotfiles/index.zsh

# .zshrc profiling
if (( ${+ZSH_PROFILING} )); then
	PROFILING_PATH="$TEMPDIR/zshrc-profiling.txt"
	zprof > "$PROFILING_PATH"
	cat "$PROFILING_PATH"
	echo Profiling informations written to: "$PROFILING_PATH"
fi
