
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

# Open a file or directory with the file explorer from a 'fd' search
function openfd() {
    local results=$(fd "$@")
    local count=$(echo "$results" | wc -l)

    if [[ -z $results ]]; then
        echoerr "No result found for this search."
        return 1
    fi

    if [[ $count = 1 ]]; then
        open "$results"
        return
    fi

    local selected=$(echo "$results" | scout)

    if [[ -z $selected ]]; then
        return 1
    fi

    open "$selected"
}

# Open a file or directory with the file explorer from a 'jumpy' search
function openz() {
    local result=$(jumpy query "$1" 2>/dev/null)

    if [[ -z $result ]]; then
        echoerr "No result found by Jumpy."
      return 1
    fi

    open "$result"
}

# Open a file or directory with the file explorer from a 'jumpy' interactive search
function openzi() {
    local list=$(jumpy list)
    local selected=$(scout <<< "$list")

    if [[ -z $selected ]]; then
        return 1
    fi

    jumpy inc "$selected"
    open "$selected"
}

# Open a file or directory with the file explorer from a 'jumpy' + 'fd' search
function openfz() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a search for Jumpy."
        return 1
    fi

    local result=$(jumpy query "$1" 2>/dev/null)

    if [[ -z $result ]]; then
        echoerr "No result found by Jumpy."
        return 1
    fi
  
    cd "$result"
    openfd
}

# Aliases to exit after open commands
function opene() { open "$@" && exit }
function openze() { openz "$@" && exit }
function openfde() { openfd "$@" && exit }
function openfze() { openfz "$@" && exit }

function openl() { open "$(latest)" }
function openle() { opene "$(latest)" }

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
