
# Prefix used by all formatting variables
export ADF_PREFIX_FORMAT="ADF_FORMAT_"

export ADF_FORMAT_RESET="\e[0m"
export ADF_FORMAT_BLACK="\e[30m"
export ADF_FORMAT_GRAY="\e[90m"
export ADF_FORMAT_RED="\e[91m"
export ADF_FORMAT_GREEN="\e[92m"
export ADF_FORMAT_YELLOW="\e[93m"
export ADF_FORMAT_BLUE="\e[94m"
export ADF_FORMAT_MAGENTA="\e[95m"
export ADF_FORMAT_CYAN="\e[96m"
export ADF_FORMAT_WHITE="\e[97m"

function _report_echoc_error() {
    >&2 echo "${ADF_FORMAT_RED}====================== echoc error ======================${ADF_FORMAT_RESET}"
    >&2 echo "${ADF_FORMAT_RED}| $1${ADF_FORMAT_RESET}"
    >&2 echo "${ADF_FORMAT_RED}|${ADF_FORMAT_RESET}"
    >&2 echo "${ADF_FORMAT_RED}| In: ${ADF_FORMAT_YELLOW}${2:0:$3-1}${ADF_FORMAT_BLUE}${2:$3:$4}${ADF_FORMAT_YELLOW}${2:$3+$4}${ADF_FORMAT_RESET}"
    >&2 echo "${ADF_FORMAT_RED}|     $(printf ' %.0s' {1..$(($3-1))})${ADF_FORMAT_BLUE}$(printf '^%.0s' {1..$4})${ADF_FORMAT_RESET}"
    >&2 echo "${ADF_FORMAT_RED}=========================================================${ADF_FORMAT_RESET}"
}

# NO_COLOR=1                   => disable colors
# ADF_CLEAN_EOL=1              => clean with space characters up to the end of the line (based on `tput cols` value)
# ADF_UPDATABLE_LINE=1         => clear the line instantly everytime we're writing on it (requires to print a line to overwrite beforehand)
# ADF_REPLACE_UPDATABLE_LINE=1 => same as "ADF_UPDATABLE_LINE" but print a newline symbol after
# ADF_NEVER_CUT_LINE=1         => don't cut an updatable line if it's longer than the terminal's width
# ADF_SILENT=1                 => disable all messages, except those from `echowarn` and `echoerr`
# ADF_FULLY_SILENT=1           => disable all messages
function echoc() {
    if (( $ADF_FULLY_SILENT )); then
        return
    fi

    local text="${@: -1}"
    shift -p

    local output=""
    local colors_history=()
    local i=0
    local rawtext=""

    while (( i < ${#text} )); do
        local i=$((i+1))

        if [[ $text[$i] != "\\" ]] || [[ $text[$i,$i+2] != "\z[" ]]; then
            output+="${text[$i]}"
            rawtext+="${text[$i]}"
            continue
        fi

        local substr="${text[$i+3,-1]}"

        local look="]°"
        local color="${substr%%$look*}"

        local format_test_varname="$ADF_PREFIX_FORMAT${color:u}"

        if [[ $color = $substr ]]; then
            output+="${text[$i]}"
            continue
        fi

        local segment_len=$((${#color}+5))

        if [[ ! -z $color && -z ${(P)format_test_varname} ]]; then
            _report_echoc_error "Unknown color ${ADF_FORMAT_YELLOW}$color" "$text" $((i-1)) $segment_len
            return 1
        fi

        if [[ -z $color ]]; then
            if [[ ${#colors_history[@]} = 0 ]]; then
                _report_echoc_error "Cannot close a color as no one is opened" "$text" $((i-1)) $segment_len
                return 1
            fi

            shift -p colors_history

            local add_color="${colors_history[-1]:-reset}"
        else
            local add_color="$color"
            colors_history+=("$color")
        fi

        local format_varname="$ADF_PREFIX_FORMAT${add_color:u}"
        local i=$((i+4+${#color}))
        
        if ! (( $NO_COLOR )); then
            output+="${(P)format_varname}"
        fi
    done

    local echo_args=("$@")

    if [[ ${#colors_history[@]} != 0 ]]; then
        _report_echoc_error "Unterminated color groups: $colors_history" "$text" $((${#text}+1)) 1
        return 1
    fi

    if (( $ADF_UPDATABLE_LINE )); then
        echo_args+=("-n")
    fi

    if (( $ADF_UPDATABLE_LINE )) || (( $ADF_REPLACE_UPDATABLE_LINE )); then
        echof "${echo_args[@]}" "\r$output" "$rawtext"
    else
        echo "${echo_args[@]}" "$output"
    fi
}

# Fill a line with a message (can't overflow)
# Usage: echof [<...arguments for 'echo'>] <formatted message> <raw message>
function echof() {
    if (( $# < 2 )); then
        echoerr "Please provide the formatted message as well as the raw message."
        return 1
    fi

    local formatted=${@: -2:1}
    local rawtext=${@: -1}

    local len=$(wc -L <<< "$rawtext")
    local remaining=$((COLUMNS - len))

    if (( $remaining < 0 )); then
        tput rmam
        echo -n "$formatted"
        tput smam
        return
    fi

    formatted+=$(printf ' %.0s' {1..$remaining})

    if (( $remaining > 1 )); then
        formatted+=$(printf '\b%.0s' {1..$((remaining - 1))})
    fi

    echo "${@:1:-2}" "$formatted"
}

function echoerr() {
    local message="\z[red]°ERROR: ${@: -1}\z[]°"
    shift -p
    >&2 echoc "$@" "$message"
}

# Equivalent to 'echoerr', but without prefix ('np' = no prefix)
function echoerrnp() {
    local message="\z[red]°${@: -1}\z[]°"
    shift -p
    >&2 ADF_SILENT=0 echoc "$@" "$message"
}

function echowarn() {
    local message="\z[yellow]°${@: -1}\z[]°"
    shift -p
	>&2 ADF_SILENT=0 echoc "$@" "$message"
}

function echosuccess() {
    if (( $ADF_SILENT )); then return; fi

    local message="\z[green]°$1\z[]°"
    shift -p
    echoc "$@" "$message"
}

function echoinfo() {
    if (( $ADF_SILENT )); then return; fi

    local message="\z[blue]°${@: -1}\z[]°"
    shift -p
    echoc "$@" "$message"
}

function echodata() {
    if (( $ADF_SILENT )); then return; fi

    local message="\z[cyan]°${@: -1}\z[]°"
    shift -p
	echoc "$@" "$message"
}

function echoverb() {
    if ! (( $ADF_VERBOSE )); then
        return
    fi

    local message="\z[gray]°[Verbose]\z[]° \z[magenta]°${@: -1}\z[]°"
    shift -p
	echoc "$@" "$message"
}