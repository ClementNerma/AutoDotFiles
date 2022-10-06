#
# This file is a giant hack
# It works by creating a function (which will be unset at the end of the script)
#  whose body is made to be run raw inside another function.
# This function's body is then extracted and put inside a global variable which can be used using the
#  evil "eval" instruction.
# It is then aliased as the "adf_args_parser" instruction, which will have for effect to create two local
#  variables, "arguments" (associate array) and "rest" (simple array)
#
# This is the only not-THAT-bad method I found to parse arguments properly inside a function
#

function ___parse_arguments() {
    if [[ -z $__args_declaration ]]; then
        echoerr "Missing \z[yellow]°\$__args_declaration\z[]° variable."
        return 90
    fi

    if [[ -z ${__args_declaration[required_positional]} ]]; then
        echoerr "Missing \z[yellow]°required_positional\z[]° property."
        return 90
    fi

    if [[ -z ${__args_declaration[optional_positional]} ]]; then
        echoerr "Missing \z[yellow]°optional_positional\z[]° property."
        return 90
    fi

    if [[ -z ${__args_declaration[required_args]} ]]; then
        echoerr "Missing \z[yellow]°required_args\z[]° property."
        return 90
    fi

    if [[ -z ${__args_declaration[optional_args]} ]]; then
        echoerr "Missing \z[yellow]optional_args\z[]° property."
        return 90
    fi    

    local __required_positional=${__args_declaration[required_positional]}
    local __optional_positional=${__args_declaration[optional_positional]}

    if [[ ${__args_declaration[required_args]} = "-" ]]; then
        local __required_args=()
    else
        local __required_args=("${(@s/, /)__args_declaration[required_args]}")
    fi

    if [[ ${__args_declaration[optional_args]} = "-" ]]; then
        local __optional_args=()
    else
        local __optional_args=("${(@s/, /)__args_declaration[optional_args]}")
    fi

    typeset -A arguments=()
    local rest=()

    local ___pc="" # Parse context

    for arg in "$@"; do
        if [[ -z $arg ]]; then
            continue
        fi

        if [[ ${arg[1]} = "-" ]]; then
            if [[ -n $___pc ]]; then
                if ! (( ${__required_args[(Ie)$___pc]} )) && ! (( ${__optional_args[(Ie)$___pc]} )); then
                    echoerr "Unknown argument: \z[yellow]°-$___pc\z[]°"
                    return 10
                fi

                if [[ -n ${arguments[$___pc]} ]]; then
                    echoerr "Cannot redefine argument: \z[yellow]°-$___pc\z[]°"
                    return 11
                fi

                arguments[$___pc]=1
                local ___pc=""
            fi

            if [[ ${arg[2]} = "-" ]]; then
                if [[ $arg =~ ^--([^=]*)=(.*)$ ]]; then
                    if ! (( ${__required_args[(Ie)${match[1]}]} )) && ! (( ${__optional_args[(Ie)${match[1]}]} )); then
                        echoerr "Unknown argument: \z[yellow]°--${match[1]}\z[]°"
                        return 10
                    fi

                    if [[ -n ${arguments[${match[1]}]} ]]; then
                        echoerr "Cannot redefine argument: \z[yellow]°--${match[1]}\z[]°"
                        return 11
                    fi

                    arguments[${match[1]}]=${match[2]}
                else
                    local ___pc=${arg:2}
                fi
            else
                if [[ $arg =~ ^-([^=])=(.*)$ ]]; then
                    if ! (( ${__required_args[(Ie)${match[1]}]} )) && ! (( ${__optional_args[(Ie)${match[1]}]} )); then
                        echoerr "Unknown argument: \z[yellow]°-${match[1]}\z[]°"
                        return 10
                    fi

                    if [[ -n ${arguments[${match[1]}]} ]]; then
                        echoerr "Cannot redefine argument: \z[yellow]°-${match[1]}\z[]°"
                        return 11
                    fi

                    arguments[${match[1]}]=${match[2]}
                elif [[ $arg =~ ^-([^=])$ ]]; then
                    local ___pc=${arg:1}
                else
                    for i in {1..$((${#arg}-1))}; do
                        if ! (( ${__required_args[(Ie)${arg:$i:1}]} )) && ! (( ${__optional_args[(Ie)${arg:$i:1}]} )); then
                            echoerr "Unknown argument: \z[yellow]°-${arg:$i:1}\z[]°"
                            return 10
                        fi

                        if [[ -n ${arguments[${arg:$i:1}]} ]]; then
                            echoerr "Cannot redefine argument: \z[yellow]°-${arg:$i:1}\z[]°"
                            return 11
                        fi

                        arguments[${arg:$i:1}]=1
                    done
                fi
            fi
        elif [[ -n $___pc ]]; then
            if ! (( ${__required_args[(Ie)$___pc]} )) && ! (( ${__optional_args[(Ie)$___pc]} )); then
                echoerr "Unknown argument: \z[yellow]°-(-)$___pc\z[]°"
                return 10
            fi

            if [[ -n ${arguments[$___pc]} ]]; then
                echoerr "Cannot redefine argument: \z[yellow]°-(-)$___pc\z[]°"
                return 11
            fi

            arguments[$___pc]=$arg
            local ___pc=""
        else
            rest+=("$arg")
        fi
    done

    if [[ -n $___pc ]]; then
        if ! (( ${__required_args[(Ie)$___pc]} )) && ! (( ${__optional_args[(Ie)$___pc]} )); then
            echoerr "Unknown argument: \z[yellow]°-(-)$___pc\z[]°"
            return 10
        fi

        if [[ -n ${arguments[$___pc]} ]]; then
            echoerr "Cannot redefine argument: \z[yellow]°-(-)$___pc\z[]°"
            return 11
        fi

        arguments[$___pc]=1
    fi

    if (( ${#rest} > $__optional_positional )); then
        echoerr "This command only accepts \z[yellow]°$__optional_positional\z[]° positional arguments but \z[yellow]°${#rest}\z[]° were provided."
        return 10
    fi

    if (( ${#rest} < $__required_positional )); then
        echoerr "This command accepts \z[yellow]°$__required_positional\z[]°-\z[yellow]°$__optional_positional\z[]° positional arguments but only \z[yellow]°${#rest}\z[]° were provided."
        return 10
    fi

    for required_arg in $__required_args; do
        if [[ -z ${arguments[$required_arg]} ]]; then
            echoerr "Missing provided argument \z[yellow]°$required_arg\z[]°"
            return 10
        fi
    done
}

export ADF_PARSE_MACRO=$(whence -f ___parse_arguments)
unset -f ___parse_arguments

if [[ $ADF_PARSE_MACRO =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\\([[:space:]]*\\)[[:space:]]*\\{(.*)\\}$ ]]; then
    export ADF_PARSE_MACRO=${match[2]}
fi

alias adf_args_parser='eval "$ADF_PARSE_MACRO"'
