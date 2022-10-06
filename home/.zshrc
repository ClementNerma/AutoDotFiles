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

# Prezto configuration version
_prezto_config_version="1"
_prezto_version_file="$HOME/.adf-prezto-config-version"

if [[ ! -f $_prezto_version_file ]]; then
	echo "Setting up Prezto configuration files..."

	setopt EXTENDED_GLOB

	for rcfile in "$HOME"/.zprezto/runcoms/^README.md(.N); do
		ln -s "$rcfile" "$HOME/.${rcfile:t}"
	done

	echo "0" > "$_prezto_version_file"
fi

if [[ $(command cat "$_prezto_version_file") != $_prezto_config_version ]]; then
	echo "Updating Prezto configuration..."

	command cat "$HOME/.prezto.zsh" > "$HOME/.zpreztorc"
	echo "$_prezto_config_version" > "$_prezto_version_file"
fi

# Load Prezto
source "$HOME/.zprezto/init.zsh"

# Load ADF
source $HOME/autodotfiles/index.zsh

# .zshrc profiling
if (( ${+ZSH_PROFILING} )); then
	PROFILING_PATH="$TEMPDIR/zshrc-profiling.txt"
	zprof > "$PROFILING_PATH"
	cat "$PROFILING_PATH"
	echo Profiling informations written to: "$PROFILING_PATH"
fi
