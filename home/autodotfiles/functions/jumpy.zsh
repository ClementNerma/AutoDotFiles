
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

# Add a list of directories to Jumpy's index
# All directories one level under the provided list will be indexed as well
function jumpy_populate_with() {
    echoinfo "Building directories list..."

    local fd_args=()

    for dir in $@; do
        fd_args+=("--search-path" "$dir")
    done

    if ! fd_list=$(fd ${fd_args[@]} --type d --max-depth ${MAX_DEPTH:-1}); then
        echoerr "Command \z[cyan]°fd\z[]° failed (see output above)."
        return 10
    fi

    IFS=$'\n' local directories=($(echo -E "$fd_list"))

    echoinfo "Found \z[yellow]°${#directories}\z[]° directories to populate Jumpy with."

    for dir in $directories; do
        jumpy add "$dir"
    done

    echosuccess "Successfully populated Jumpy."
}

function jumpy_handler() {
    if (( $__JUMPY_DONT_REGISTER )); then
        return
    fi

    emulate -L zsh
    jumpy inc "$PWD"
}

chpwd_functions=(${chpwd_functions[@]} "jumpy_handler")
