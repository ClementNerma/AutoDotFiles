
function z() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a query."
        return 1
    fi

    local result=$(jumpy query "$1" --checked --after "$PWD")

    if [[ -n $result ]]; then
        export __JUMPY_DONT_REGISTER=1
        cd "$result"
        export __JUMPY_DONT_REGISTER=0
    fi
}

# Aliases to exit after open commands
function opene() { open "$@" && exit }

function jumpy_handler() {
    if (( $__JUMPY_DONT_REGISTER )); then
        return
    fi

    emulate -L zsh
    jumpy inc "$PWD"
}

chpwd_functions=(${chpwd_functions[@]} "jumpy_handler")
