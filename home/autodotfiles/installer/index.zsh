#
# This file contains is in charge of installing all components required by the current setup
#

if [[ -z "$ADF_INSTALLER_DIR" ]]; then
    echoerr "Environment variable \e[93m\$ADF_INSTALLER_DIR\e[91m is not defined."
    echoerr "       Please make sure the current script is run from Setup Env."
    return 1
fi

export ADF_INSTALLED_DIR=$(realpath "$ADF_DATA_DIR/.installer.auto")
mkdir -p "$ADF_INSTALLED_DIR"

function zercomponent_install_from_list() {
    # Choose a temporary directory
    local AUTO_INSTALLER_STARTED_AT=$(date +%s%N)
    INSTALLER_TMPDIR="/tmp/autodotfiles_autoinstaller_$AUTO_INSTALLER_STARTED_AT"
    mkdir -p "$INSTALLER_TMPDIR"

    echoinfo "Detected \e[91m${#ADF_TO_INSTALL[@]}\e[93m $1:"

    local longest_component_name=0

    for component in $ADF_TO_INSTALL
    do
        local component_name=$(basename "$component")
        if (( ${#component_name} > $longest_component_name )); then
            longest_component_name=${#component_name}
        fi
    done

    for component in $ADF_TO_INSTALL
    do
        local component_name=$(basename "$component")
        local component_dir="($(dirname "$component"))"
        echo -e "\e[96m    $(basename "$component")\e[92m${(l($longest_component_name-${#component_name}+${#component_dir}+5)( ))component_dir}\e[0m"
    done

    echo -e ""
    echoinfo "These components will now be installed."
    echoinfo "$2type \e[31mN\e[93m/\e[31mn\e[93m."

    local install_choice
    read "install_choice?"

    if [[ $install_choice =~ ^[Nn]$ ]]; then
        echoinfo "Installation has been aborted."
        echo -e ""

        if [[ $3 = 1 ]]; then
            export ADF_INSTALLER_ABORTED=1
        fi

        return 1
    fi

    ADF_INSTALL_STEP=0

    echo -e ""
    echosuccess ">"
    echosuccess "> Preparing the environment for update..."
    echosuccess ">"
    echo -e ""

    sudo apt update

    for component in $ADF_TO_INSTALL
    do
        ADF_INSTALL_STEP=$((ADF_INSTALL_STEP + 1))

        echo ""
        echosuccess ">"
        echosuccess "> Installing component \e[94m$ADF_INSTALL_STEP\e[32m /" \
                "\e[91m${#ADF_TO_INSTALL[@]}\e[32m: \e[96m$(basename "$component") \e[92m($(dirname "$component"))\e[32m"
        echosuccess ">"
        echo ""

        local script_path="$ADF_INSTALLER_SCRIPTS_DIR/$component.zsh"

        if [[ ! -f $script_path ]]; then
            echoerr "> Failed to install component \e[96m$component\e[91m: installation script not found at \e[92m$script_path\e[91m!"
            return 1
        fi

        export ZER_UPDATING=$5

        if source "$script_path"; then
            zercomponent_mark_installed "$component"
        fi
    done

    unset ZER_UPDATING

    echo -e ""
    echosuccess ">"
    echosuccess "> Cleaning the temporary directory..."
    echosuccess ">"
    echo -e ""

    command rm -rf "$INSTALLER_TMPDIR"

    echo -e ""
    echoinfo "=> Successfully $4 \e[91m${#ADF_TO_INSTALL[@]}\e[93m component(s)!"
    echo -e ""

    unset ADF_INSTALL_STEP
    unset ADF_TO_INSTALL
}

function zercomponent_addtolist() {
    local file_name=$(realpath --relative-to="$ADF_INSTALLER_SCRIPTS_DIR" "$1")
    local script_name="${file_name/.zsh/}"

    if [[ ! -f "$ADF_INSTALLED_DIR/$script_name" ]]; then
        ADF_TO_INSTALL+=("$script_name")
    fi
}

# Arguments:
# * <dir>/<script_name> <value>
# * <script_name> <dir> <value>
function zercomponent_mark_custom() {
    local script_name="$1"
    local value="$2"

    if [[ ! -z "$3" ]]; then
        script_name="$2/$1"
        value="$3"
    fi

    if [[ ! -f "$ADF_INSTALLER_SCRIPTS_DIR/$script_name.zsh" ]]; then
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

function zercomponent_mark_installed() { zercomponent_mark_custom "$@" "1" }
function zercomponent_mark_not_installed() { zercomponent_mark_custom "$@" "0" }

function zercomponent_update() {
    if [[ ! -f "$ADF_INSTALLER_SCRIPTS_DIR/$1.zsh" ]]; then
        echoerr "Provided component \e[96m$1\e[91m was not found."
        return 1
    fi

    ADF_TO_INSTALL=()

    for component in "$@"
    do
        ADF_TO_INSTALL+=("$component")
    done

    zercomponent_install_from_list "components to update" "To abort the update process, " 0 "updated" 1
}

function _step() {
    echo -e ""
    echoinfo ">>> Sub-step: $1"
    echo -e ""
}

function _checkdir() {
    if [[ ! -d "$1" ]]; then
        return
    fi

    if [[ -f "$1/_init.zsh" ]]; then
        zercomponent_addtolist "$1/_init.zsh"
    fi

    for file in "$1/_"*.zsh(N)
    do
        if [[ "$(basename "$file")" = "_init.zsh" ]]; then
            continue
        fi

        zercomponent_addtolist "$file"
    done

    for file in "$1/"*.zsh(N)
    do
        if [[ "$(basename "$file")" = "_"* ]]; then
            continue
        fi

        zercomponent_addtolist "$file"
    done
}

ADF_TO_INSTALL=()

export ADF_INSTALLER_SCRIPTS_DIR="$ADF_INSTALLER_DIR/scripts"

_checkdir "$ADF_INSTALLER_SCRIPTS_DIR/all/pre"
_checkdir "$ADF_INSTALLER_SCRIPTS_DIR/all"
_checkdir "$ADF_INSTALLER_SCRIPTS_DIR/$ENV_NAME_STR/pre"
_checkdir "$ADF_INSTALLER_SCRIPTS_DIR/$ENV_NAME_STR"

if [[ $ADF_CONF_MAIN_PERSONAL_COMPUTER = 1 ]]; then
    _checkdir "$ADF_INSTALLER_SCRIPTS_DIR/main-pc/all/pre"
    _checkdir "$ADF_INSTALLER_SCRIPTS_DIR/main-pc/all"
    _checkdir "$ADF_INSTALLER_SCRIPTS_DIR/main-pc/$ENV_NAME_STR/pre"
    _checkdir "$ADF_INSTALLER_SCRIPTS_DIR/main-pc/$ENV_NAME_STR"
fi

if [[ ${#ADF_TO_INSTALL[@]} != 0 ]]; then
    zercomponent_install_from_list "missing components" "To skip the installation process for now and not load the environment, " 1 "installed" 0
fi

unset INSTALLER_TMPDIR
unset -f _checkdir