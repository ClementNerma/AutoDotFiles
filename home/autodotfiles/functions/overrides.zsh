
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

# Open a file with VSCode
function codefile() {
	[[ -n $1 ]] || { echoerr "Please provide a file to open"; return 1 }
	[[ -f $1 ]] || { echoerr "Provided file does not exist"; return 1 }

	command code "$1"
}
