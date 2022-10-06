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
    typeset -A arguments=()
    local rest=()

    local ___pc="" # Parse context

    for arg in "$@"; do
        if [[ -z $arg ]]; then
            continue
        fi

        if [[ ${arg[1]} = "-" ]]; then
            if [[ ! -z $___pc ]]; then
                arguments[$___pc]=1
                local ___pc=""
            fi

            if [[ ${arg[2]} = "-" ]]; then
                if [[ $arg =~ ^--([^=]*)=(.*)$ ]]; then
                    arguments[${match[1]}]=${match[2]}
                else
                    local ___pc=${arg:2}
                fi
            else
                if [[ $arg =~ ^-([^=])=(.*)$ ]]; then
                    arguments[${match[1]}]=${match[2]}
                elif [[ $arg =~ ^-([^=])$ ]]; then
                    local ___pc=${arg:1}
                else
                    for i in {1..$((${#arg}-1))}; do
                        arguments[${arg:$i:1}]=1
                    done
                fi
            fi
        elif [[ ! -z $___pc ]]; then
            arguments[$___pc]=$arg
            local ___pc=""
        else
            rest+=("$arg")
        fi
    done

    if [[ ! -z $___pc ]]; then
        arguments[$___pc]=1
    fi
}

export ADF_PARSE_MACRO=$(whence -f ___parse_arguments)
unset -f ___parse_arguments

if [[ $ADF_PARSE_MACRO =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\\([[:space:]]*\\)[[:space:]]*\\{(.*)\\}$ ]]; then
    export ADF_PARSE_MACRO=${match[2]}
fi

alias adf_args_parser='eval "$ADF_PARSE_MACRO"'
