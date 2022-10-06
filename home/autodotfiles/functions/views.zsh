
# Views location
export ADF_VIEWS_DIR="$PLOCALDIR/views"
export ADF_VIEW_PATH_FILENAME=".viewpath"
export ADF_VIEW_SOFTWARE_FILENAME=".viewsoftware"

if [[ ! -d "$ADF_VIEWS_DIR" ]]; then
    mkdir "$ADF_VIEWS_DIR"
fi

function adf_view_list() {
    for dir in "$ADF_VIEWS_DIR/"*(N); do
        local base=$(basename "$dir")
        echoinfo "\z[yellow]°* $base\z[]° \z[blue]°-> $(adf_view_target "$base")\z[]° \z[green]°-> $(adf_view_software "$base")\z[]°"
    done
}

function adf_view_create() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a view name."
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Please provide a target directory."
        return 2
    fi

    if [[ -z $3 ]]; then
        echoerr "Please provide a software path."
        return 3
    fi

    if [[ ! -d $2 ]]; then
        echoerr "Target directory was not found."
        return 10
    fi

    if [[ ! -f $3 ]]; then
        echoerr "Provided software was not found."
        return 11
    fi

    local view_dir="$ADF_VIEWS_DIR/$1"

    if [[ -d $view_dir ]]; then
        echoerr "A view already exists with this name."
        return 11
    fi

    mkdir "$view_dir"
    echo "$2" > "$view_dir/$ADF_VIEW_PATH_FILENAME"
    echo "$3" > "$view_dir/$ADF_VIEW_SOFTWARE_FILENAME"
    adf_view_randomize "$1"

    echosuccess "View \z[yellow]°$1\z[]° was successfully created and randomized."
}

function adf_view_target() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a view name."
        return 1
    fi

    local view_dir="$ADF_VIEWS_DIR/$1"

    if [[ ! -d $view_dir ]]; then
        echoerr "Provided view name does not exist."
        return 10
    fi

    command cat "$view_dir/$ADF_VIEW_PATH_FILENAME"
}

function adf_view_software() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a view name."
        return 1
    fi

    local view_dir="$ADF_VIEWS_DIR/$1"

    if [[ ! -d $view_dir ]]; then
        echoerr "Provided view name does not exist."
        return 10
    fi

    command cat "$view_dir/$ADF_VIEW_SOFTWARE_FILENAME"
}

function adf_view_clean() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a view name."
        return 1
    fi

    local view_dir="$ADF_VIEWS_DIR/$1"

    if [[ ! -d $view_dir ]]; then
        echoerr "Provided view name does not exist."
        return 10
    fi

    echoinfo "Cleaning the view..."

    for item in "$view_dir/"*(N); do
        command rm "$item"
    done

    echoinfo "View was cleaned successfully."
}

function adf_view_randomize() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a view name."
        return 1
    fi

    local view_dir="$ADF_VIEWS_DIR/$1"

    if [[ ! -d $view_dir ]]; then
        echoerr "Provided view name does not exist."
        return 10
    fi

    if ! adf_view_clean "$1"; then
        echoerr "Failed to clean the view."
        return 11
    fi

    local target=$(command cat "$view_dir/$ADF_VIEW_PATH_FILENAME")

    local counter=0
    local files=()

    while IFS= read -r file; do
        files+=("$file")
    done <<< $(command ls -1A "$target" | shuf)

    local total=$(printf "%05d" ${#files})

    for counter in {1..$total}; do
        local file="${files[counter]}"
        local padded_counter=$(printf "%05d" "$counter")
        local symlink="r$padded_counter-$(basename "$file")"
        echoinfo "\z[magenta]°> $padded_counter/\z[green]°$total\z[]°: \z[yellow]°r$padded_counter\z[]° -> \z[blue]°$(basename "$file")\z[]°\z[]°"
        psymlink "$target/$file" "$view_dir/$symlink"
	done

    echoinfo "View was randomized successfully."
}

function adf_view_open() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a view name."
        return 1
    fi

    local view_dir="$ADF_VIEWS_DIR/$1"

    if [[ ! -d $view_dir ]]; then
        echoerr "Provided view name does not exist."
        return 10
    fi

    if [[ $2 = "--randomize" ]]; then
        adf_view_randomize "$1"
    elif [[ ! -z $2 ]]; then
        echoerr "The only allowed parameter is \z[yellow]°--randomize\z[]°"
        return 2
    fi

    local first_file=$(command ls -1A "$view_dir" | sort | head -n 1)

    local cwd=$(pwd)
    cd "$view_dir"

    (nohup "$(adf_view_software "$1")" "$first_file" > /dev/null 2>&1 &)
    cd "$cwd"
}

function adf_view_delete() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a view name."
        return 1
    fi

    local view_dir="$ADF_VIEWS_DIR/$1"

    if [[ ! -d $view_dir ]]; then
        echoerr "Provided view name does not exist."
        return 10
    fi

    command rm -rf "$view_dir"

    echosuccess "View was successfully deleted."
}