#
# Background jobs management
#

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
        local task=$(printf '%s' "$entry" | pomsky "$PSS_ENTRY_PARSER" '$command' | pomsky "Start Codepoint+ '_bjmarker' [s] :name(![s]+) [s] :command(Codepoint+) End" '\z[yellow]°$name\z[]° => \z[magenta]°$command\z[]°')
        echoinfo "* $task"
    done
}

function bjhas() {
    [[ -z $1 ]] && { echoerr "Please provide a task name"; return 1 }

    if ! ps -ux | grep "_bjmarker $1 " | grep -v "grep" > /dev/null; then
        return 1
    fi
}

function bjstart() {
    [[ -z $1 ]] && { echoerr "Please provide a task name"; return 1 }
    [[ -z $2 ]] && { echoerr "Please provide a command to run"; return 2 }

    if bjhas "$1"; then
        return 1
    fi

    (nohup "$(which zsh)" "$ADF_ENTRYPOINT" "--just-run" _bjmarker "$1" "${@:2}" > /dev/null 2>&1 &)
    echoinfo "Started task \z[yellow]°$1\z[]°."
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
