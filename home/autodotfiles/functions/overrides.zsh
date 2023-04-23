
# Automatically use parent SSH private key file with 'git' commands
function git() {
    local current=$PWD

    while [[ $current != "/" ]]; do
        if [[ -f "$current/$ADF_GIT_SSH_PRIVATE_KEY_FILENAME" ]]; then
            GIT_SSH_COMMAND="ssh -i '$current/$ADF_GIT_SSH_PRIVATE_KEY_FILENAME'" command git "$@"
            return
        fi

        current=$(dirname "$current")
    done

    command git "$@"
}

# Make a commit with Git
function gm() {
    local first_line=$(printf '%s' $1 | head -n1)

    if (( ${#first_line} > 50 )); then
        echowarn "Maximum recommanded message length is \z[cyan]°50\z[]° characters but provided one is \z[cyan]°${#1}\z[]° long."
        return 1
    fi

    git commit -m "$1" "${@:2}"
}

function rm() {
	trasher rm "$@"
}

function unrm() {
	trasher unrm "$@"
}

# Safety handlers for 'npm', 'yarn' and 'pnpm'
function npm() {
	[[ -f yarn.lock ]] && { echoerr "A lockfile from \z[cyan]°Yarn\z[]° is already present!"; return 1 }
	[[ -f pnpm-lock.yaml ]] && { echoerr "A lockfile from \z[cyan]°PNPM\z[]° is already present!"; return 1 }
	command npm "$@"
}

function yarn() {
	[[ -f package-lock.json ]] && { echoerr "A lockfile from \z[cyan]°NPM\z[]° is already present!"; return 1 }
	[[ -f pnpm-lock.yaml ]] && { echoerr "A lockfile from \z[cyan]°PNPM\z[]° is already present!"; return 1 }
	command yarn "$@"
}

function pnpm() {
	[[ -f package-lock.json ]] && { echoerr "A lockfile from \z[cyan]°NPM\z[]° is already present!"; return 1 }
	[[ -f yarn.lock ]] && { echoerr "A lockfile from \z[cyan]°Yarn\z[]° is already present!"; return 1 }
	command pnpm "$@"
}

# VSCode opener
function code() {
	local dir=${1:-.}

    if [[ ! -d $dir ]]; then
        echoerr "Provided directory does not exist."
        return 1
    fi

	local workspace=($dir/*.code-workspace(N))
	local to_open=${workspace[1]:-$dir}

	if command -v code-insiders > /dev/null; then
		code-insiders "$to_open" "${@:2}"
	else
		command code "$to_open" "${@:2}"
	fi
}

# Configuration override for YTDL
function ytdl() {
    command ytdl -c "$ADF_DATA_DIR/ytdl/ytdl-config.json" "$@"
}
