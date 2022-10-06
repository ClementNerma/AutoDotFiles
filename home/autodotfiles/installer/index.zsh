#
# This file contains is in charge of installing all components required by the current setup
#

if [[ -z $ADF_INSTALLER_DIR ]]; then
    echoerr "Environment variable \z[yellow]°\$ADF_INSTALLER_DIR\z[]° is not defined."
    echoerr "       Please make sure the current script is run from AutoDotFiles."
    return 1
fi

export ADF_INSTALLED_DIR=$(realpath "$ADF_THISCOMP_DIR/.installer.auto")
mkdir -p "$ADF_INSTALLED_DIR"

function zercomponent_install() {
    if ! (( $# )); then
        echosuccess "No component to install."
        return
    fi

    # Choose a temporary directory
    local AUTO_INSTALLER_STARTED_AT=$(date +%s%N)
    export INSTALLER_TMPDIR="/tmp/autodotfiles_autoinstaller_$AUTO_INSTALLER_STARTED_AT"
    mkdir -p "$INSTALLER_TMPDIR"

    echowarn "There are \z[red]°$#\z[]° components to install:"

    local longest_component_name=0

    for component in "$@"; do
        local component_name=$(basename "$component")

        if (( ${#component_name} > $longest_component_name )); then
            local longest_component_name=${#component_name}
        fi
    done

    for component in "$@"; do
        local component_name=$(basename "$component")
        local component_dir="($(dirname "$component"))"
        echodata "\z[cyan]°    $(basename "$component")\z[green]°${(l($longest_component_name-${#component_name}+${#component_dir}+5)( ))component_dir}\z[]°\z[]°"
    done

    echowarn ""
    echowarn "These components will now be installed."
    echowarn "To get a raw prompt, type \z[red]°N\z[]°\z[yellow]°/\z[]°\z[red]°n\z[]°."

    local install_choice
    read "install_choice?"

    if [[ $install_choice =~ ^[Nn]$ ]]; then
        echowarn "Installation has been aborted."
        echowarn ""

        if [[ $3 = 1 ]]; then
            export ADF_INSTALLER_ABORTED=1
        fi

        return 1
    fi

    if [[ -z $ADF_SKIP_APT_UPDATE ]]; then
        echosuccess ""
        echosuccess ">"
        echosuccess "> Preparing the environment for update..."
        echosuccess ">"
        echosuccess ""

        if ! sudo apt update; then
            echoerr "Failed to update environment!"
            return 2
        fi
    fi

    local install_step=0

    for component in "$@"
    do
        local install_step=$((install_step + 1))

        local pretty_component_display="\z[cyan]°$(basename "$component")\z[]° \z[green]°($(dirname "$component"))\z[]°"

        echosuccess ""
        echosuccess ">"
        echosuccess "> Installing component \z[blue]°$install_step\z[]° / \z[red]°$#\z[]°: $pretty_component_display"
        echosuccess ">"
        echosuccess ""

        local script_path="$ADF_INSTALLER_SCRIPTS_DIR/$component.zsh"

        if [[ ! -f $script_path ]]; then
            echoerr "> Failed to install component \z[cyan]°$component\z[]°: installation script not found at \z[green]°$script_path\z[]°!"
            return 1
        fi

        export ZER_UPDATING=$5

        if source "$script_path"; then
            zcmi "$component"
        fi
    done

    unset ZER_UPDATING

    echosuccess ""
    echosuccess ">"
    echosuccess "> Cleaning the temporary directory..."
    echosuccess ">"
    echosuccess ""

    command rm -rf "$INSTALLER_TMPDIR"

    echoinfo ""
    echoinfo "=> Successfully installed \z[red]°$#\z[]° component(s)!"
    echoinfo ""
}

# Arguments:
# * <dir>/<script_name> <value>
# * <script_name> <dir> <value>
function zercomponent_mark_custom() {
    local script_name="$1"
    local value="$2"

    if [[ ! -z $3 ]]; then
        local script_name="$2/$1"
        local value="$3"
    fi

    if [[ ! -f $ADF_INSTALLER_SCRIPTS_DIR/$script_name.zsh ]]; then
        echoerr "Provided module not found!"
        return 1
    fi

    if [[ $value = 1 ]]; then
        mkdir -p "$(dirname "$ADF_INSTALLED_DIR/$script_name")"
        touch "$ADF_INSTALLED_DIR/$script_name"
    else
        rm "$ADF_INSTALLED_DIR/$script_name"
    fi
}

# Z Component Mark Installed
function zcmi() { zercomponent_mark_custom "$@" "1" }

# Z Component Mark Not Installed
function zcmni() { zercomponent_mark_custom "$@" "0" }

# Z Component Update
function zcu() {
    local to_install=()

    for component in "$@"
    do
        local found=""

        if [[ ! -f $ADF_INSTALLER_SCRIPTS_DIR/$component.zsh ]]; then
            if found=$(find "$ADF_INSTALLER_SCRIPTS_DIR" -type f -name "$component.zsh") && [[ ! -z $found ]]; then
                if [[ $(echo $found | wc -l) -gt 1 ]]; then
                    echoerr "Multiple candidates were found for component: \z[cyan]°$component\z[]°."
                    return 2
                fi

                local component="$(realpath --relative-to="$ADF_INSTALLER_SCRIPTS_DIR" "$found")"
                local component="${component/\.zsh/}"
            else
                echoerr "Provided component \z[cyan]°$component\z[]° was not found."
                return 1
            fi
        fi

        to_install+=("$component")
    done

    zercomponent_install $to_install
}

function zercomponent_install_required() {
    local check_list=()

    for script in "$ADF_INSTALLER_SCRIPTS_DIR/"{all,$ENV_NAME_STR}/**/*(N); do
        if [[ -f $script ]]; then check_list+=("$script"); fi
    done

    if (( $ADF_CONF_MAIN_PERSONAL_COMPUTER )); then
        for script in "$ADF_INSTALLER_SCRIPTS_DIR/"main-pc/{all,$ENV_NAME_STR}/*(N); do
            if [[ -f $script ]]; then check_list+=("$script"); fi
        done
    fi

    local to_install=()

    for script in $check_list; do
        local file_name=$(realpath --relative-to="$ADF_INSTALLER_SCRIPTS_DIR" "$script")
        local script_name="${file_name/.zsh/}"

        if [[ ! -f $ADF_INSTALLED_DIR/$script_name ]]; then
            to_install+=("$script_name")
        fi
    done

    if (( ${#to_install} )); then
        zercomponent_install $to_install
    fi
}

export ADF_INSTALLER_SCRIPTS_DIR="$ADF_INSTALLER_DIR/scripts"

zercomponent_install_required
