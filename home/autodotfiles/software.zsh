
# Integration for Rust (if installed)
if [[ -f ~/.cargo/env ]]; then
	source ~/.cargo/env
fi

# Integration for Python
export PATH="$HOME/.local/bin:$PATH"

# Integration for Volta
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Integration for PNPM
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Integration for Starship
export STARSHIP_CONFIG="$HOME/starship.toml"

if command -v starship > /dev/null; then
    eval "$(starship init zsh)"
else
    echowarn "Starship does not seem to be installed yet."
fi

# Integration for Jumpy
function jumpy_handler() {
    if (( $__JUMPY_DONT_REGISTER )); then
        return
    fi

    emulate -L zsh
    jumpy inc "$PWD"
}

chpwd_functions=(${chpwd_functions[@]} "jumpy_handler")

# Integration for Atuin
if command -v atuin > /dev/null; then
    eval "$(atuin init zsh)"
fi

# Ensure Crony is started
crony start --ignore-started
