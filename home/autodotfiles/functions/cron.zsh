
# Check if there is a line in the cronfile containing the provided string
function adf_cron_contains() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a content to look for."
        return 1
    fi

	crontab -l 2> /dev/null | grep "$1" > /dev/null
}

# Add a task at the end of the cronfile
# Usage: cron_add_uq_raw <filter> <time | "-"> <command> [--head]
function adf_cron_add_uq_raw() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a filter."
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Please provide a CRON time."
        return 2
    fi

    if [[ -z $3 ]]; then
        echoerr "Please provide a command."
        return 3
    fi

    if [[ ! -z $4 && $4 != "--head" ]]; then
        echoerr "Fourth argument must be \z[yellow]°--head\z[]° or empty."
        return 4
    fi

    if [[ $3 != *"$1"* ]]; then
        echoerr "Filter does not cover the command."
        return 4
    fi

    if adf_cron_contains "$1"; then
        echoverb "Ignoring CRON line with filter \z[yellow]°$2\z[]° as it already exists."
        return
    fi

    local line="$3"

    if [[ $2 != "-" ]]; then
        local line="$2 $3"
    fi

    if [[ $4 != "--head" ]]; then
    	(crontab -l 2> /dev/null; echo "$line") | crontab
    else
        (echo "$line"; crontab -l 2> /dev/null) | crontab
    fi
}

# Add a task to run inside ADF at the end of the cronfile
# Usage: cron_add_uq_raw <task slug> <time> <command> [--head]
function adf_cron_add_uq() {
    adf_cron_add_uq_raw "adf_cron_logged '$1'" "$2" "zsh '$ADF_ENTRYPOINT' --just-run adf_cron_logged '$1' $3" $4

    local ret=$? ; if (( $ret )); then return $ret; fi
}

# Run a command from inside a CRON task
function adf_cron_logged() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a CRON task slug."
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Please provide a command to run."
        return 2
    fi

    _adf_cron_logged "$@" >> "$ADF_CONF_CRON_LOGS_DIR/$1.log" 2>&1

    local ret=$? ; if (( $ret )); then return $ret; fi
}

function _adf_cron_logged() {
    echoinfo "[ADF:CRON] Running task \z[yellow]°$1\z[]° at \z[yellow]°$(printabledate)\z[]°..."
    local started=$(timer_start)

    "${@:2}"

    local ret=$?
    local elapsed=$(timer_elapsed "$started")
    local ended=$(printabledate)

    local failure_file="$ADF_CONF_CRON_FAILURE_DIR/$1"

    local exitcodemsg="\z[green]°command ended successfully (exit code 0)\z[]°"

    if (( $ret )); then
        local exitcodemsg="\z[red]°command failed with exit code \z[yellow]°$ret\z[]°\z[]°"
        printf "%s" "$ended" > "$failure_file"
    elif [[ -f $failure_file ]]; then
        command rm "$failure_file"
    fi

    echoinfo "[ADF:CRON] Finished running task at \z[yellow]°$ended\z[]° in \z[yellow]°$elapsed\z[]°, $exitcodemsg."
    echoinfo " "
    echoinfo " "

    if (( $ret )); then return $ret; fi
}

# Read the logs of a specific CRON task
function adf_cron_logs() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a task slug to read the logs from. Available ones:"

        for file in "$ADF_CONF_CRON_LOGS_DIR/"*(N); do
            echoinfo "* \z[yellow]°${$(basename "$file")/.log/}\z[]°"
        done

        return 1
    fi

    local logsfile="$ADF_CONF_CRON_LOGS_DIR/$1.log"

    if [[ ! -f $logsfile ]]; then
        echoerr "This task slug doesn't exist or it does not have a log file yet."
        return 2
    fi

    echoinfo "\z[magenta]°===== LOG FILE: \z[blue]°\$ADF_CONF_CRON_LOGS_DIR\z[]°\z[yellow]°/$1.log\z[]° =====\z[]°"

    tail -f -n 50 "$logsfile"
}

if [[ ! -d $ADF_CONF_CRON_LOGS_DIR ]]; then
    mkdir -p "$ADF_CONF_CRON_LOGS_DIR"
fi

if [[ ! -d $ADF_CONF_CRON_FAILURE_DIR ]]; then
    mkdir -p "$ADF_CONF_CRON_FAILURE_DIR"
fi

function adf_check_crons() {
    for failure in "$ADF_CONF_CRON_FAILURE_DIR/"*(N); do
        local dismiss="\z[cyan]°adf_cron_dismiss '$(basename "$failure")'\z[]°"
        echoerr "* Job \z[yellow]°$(basename "$failure")\z[]° failed at \z[blue]°$(command cat "$failure")\z[]° (dismiss with $dismiss)"
    done
}

function adf_cron_dismiss() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a CRON name to dismiss."
        return 1
    fi

    local failure="$ADF_CONF_CRON_FAILURE_DIR/$1"

    if [[ ! -f $failure ]]; then
        echoerr "No CRON failure found for the provided name."
        return 2
    fi

    command rm "$failure"
    echo OK
}
