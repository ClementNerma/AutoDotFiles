#
# Background jobs management
#

function bjstart() {
    [[ -z $1 ]] && { echoerr "Please provide a task name"; return 1 }
    [[ -z $2 ]] && { echoerr "Please provide a command to run"; return 2 }

    nohup "$(which zsh)" \
        "$ADF_ENTRYPOINT" "--just-run" \
        _bjmarker "$1" "${@:2}" \
        > /dev/null & \
        disown 
}

function bjlist() {
    IFS=$'\n' local pids=($(
		pss | grep " _bjmarker " | grep -v "grep "
	))

    if [[ ${#pids} -eq 0 ]]; then
        echoinfo "No running task."
        return
    fi

    echoinfo "Found \z[yellow]°${#pids}\z[]° running command(s):"

    for entry in $pids; do
        local command=$(printf '%s' "$entry" | pomsky "$PSS_ENTRY_PARSER" '$command' | pomsky "Start Codepoint+ '_bjmarker' [s] ![s]+ [s] :command(Codepoint+) End" '$command')
        echoinfo "* \z[magenta]°$command\z[]°"
    done
}

function bjkill() {
    [[ -z $1 ]] && { echoerr "Please provide a task name"; return 1 }

    if ! _bj_pid=$(find_pid "_bjmarker $1"); then
        echoerr "Task not found."
        return 1
    fi

    echoinfo "Killing PID \z[yellow]°$_bj_pid\z[]°"
    kill "$_bj_pid"
}

function _bjmarker() {
    [[ -z $1 ]] && { echoerr "Please provide a task name"; return 1 }
    [[ -z $2 ]] && { echoerr "Please provide a command to run"; return 2 }

    "${@:2}"
}
