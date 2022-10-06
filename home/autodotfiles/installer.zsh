#
# This file contains is in charge of installing all components required by the current setup
#

export ADF_INSTALLED_LIST="$ADF_ASSETS_DIR/installed-components.txt"
export ADF_INSTALLER_HASH_FILE="$ADF_ASSETS_DIR/installer-checksum.txt"
export ADF_INSTALLER_MAIN_PC_CHECKED_MARKER="$ADF_ASSETS_DIR/installer-checked-for-main-pc.txt"
export ADF_INSTALLER_SCRIPTS="$ADF_DIR/installer-scripts.zsh"

# Usage: <component name (not specified = everything)>
# ADF_SKIP_INSTALLED=1 => skip already-installed components
# ADF_FORCE_INSTALL=1 => indicate to the component it's installing for the first time instead of updating
function adf_install() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a component to install (* = everything)"
        return 1
    fi

    local only_install=("$@")
    local skip_if_installed=$(($ADF_SKIP_INSTALLED))

    local scripts=$(cat "$ADF_INSTALLER_SCRIPTS")
    local cksum=$(cksumstr "$scripts")

    if (( $skip_if_installed )) && [[ -f $ADF_INSTALLER_HASH_FILE ]] && [[ $(cat "$ADF_INSTALLER_HASH_FILE") = $cksum ]]; then
        if ! (( $ADF_CONF_MAIN_PERSONAL_COMPUTER )) || [[ -f $ADF_INSTALLER_MAIN_PC_CHECKED_MARKER ]]; then
            return
        fi
    fi

    if [[ ! -f $ADF_INSTALLED_LIST ]]; then
        touch $ADF_INSTALLED_LIST
    fi

    IFS=$'\n' local lines=($(cat "$ADF_INSTALLER_SCRIPTS"))

    local installer_scripts=()

    local to_install=0
    local to_install_needs_apt_update=0

    local to_install_functions=()
    local to_install_priority=()
    local to_install_names=()
    local to_install_env=()
    local to_install_version_cmds=()
    local to_install_already_installed=()
    local to_install_previous_version=()

    local longest_name=0
    local longest_env=0

    local i=0
    local last_priority=9
    local last_env=""

    while (( i < ${#lines} )); do
        local i=$((i+1))

        if [[ ! ${lines[i]} =~ ^[[:space:]]*function ]]; then
            continue
        fi

        if [[ ! ${lines[i]} =~ ^[[:space:]]*function[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]+)[[:space:]]*\\(\\)[[:space:]]*\\{[[:space:]]*$ ]]; then
            echoerr "Found invalid function statement in installer scripts: \z[yellow]°${lines[i]}\z[]°"
            return 80
        fi

        local func_name=${match[1]}

        installer_scripts+=("$func_name")

        if [[ ! ${lines[i + 1]} =~ ^[[:space:]]*\#[[:space:]]NAME:[[:space:]](.*)$ ]]; then
            echoerr "Missing or invalid \z[cyan]°NAME\z[]° statement in script \z[yellow]°$script_name\z[]°"
            return 81
        fi

        local script_name=${match[1]}

        if [[ ! ${lines[i + 2]} =~ ^[[:space:]]*\#[[:space:]]PRIORITY:[[:space:]]([0-9])$ ]]; then
            echoerr "Missing or invalid \z[cyan]°PRIORITY\z[]° statement in script \z[yellow]°$script_name\z[]°"
            return 81
        fi

        local priority=${match[1]}

        if [[ ! ${lines[i + 3]} =~ ^[[:space:]]*\#[[:space:]]ENV:[[:space:]]([a-zA-Z0-9-]+\/)?([a-zA-Z0-9-]+)$ ]]; then
            echoerr "Missing or invalid \z[cyan]°ENV\z[]° statement in script \z[yellow]°$script_name\z[]°"
            return 81
        fi

        local script_env="${match[1]}${match[2]}"

        if [[ -z ${match[1]} ]]; then
            local for_this_pc=1
        elif [[ ${match[1]} = "main-pc/" ]]; then
            ! (( $ADF_CONF_MAIN_PERSONAL_COMPUTER ))
            local for_this_pc=$?
        else
            echoerr "Internal error: invalid installer main PC indicator: \z[yellow]°${match[1]}\z[]°"
            return 82
        fi

        if [[ ${match[2]} = "all" ]]; then
            local for_this_env=1
        elif [[ ${match[2]} = "wsl" ]]; then
            ! (( $IS_WSL_ENV ))
            local for_this_env=$?
        elif [[ ${match[2]} = "linux" ]]; then
            (( $IS_WSL_ENV ))
            local for_this_env=$?
        else
            echoerr "Internal error: invalid installer environment: \z[yellow]°$script_env\z[]°"
            return 83
        fi

        if [[ ! ${lines[i + 4]} =~ ^[[:space:]]*\#[[:space:]]VERSION:[[:space:]](.*)$ ]]; then
            echoerr "Missing or invalid \z[cyan]°VERSION\z[]° statement in script \z[yellow]°$script_name\z[]°"
            return 84
        fi

        local version_cmd=${match[1]}

        if [[ ! ${lines[i + 5]} =~ ^[[:space:]]*\#[[:space:]]NEEDS_APT_UPDATE:[[:space:]](.*)$ ]]; then
            echoerr "Missing or invalid \z[cyan]°NEEDS_APT_UPDATE\z[]° statement in script \z[yellow]°$script_name\z[]°"
            return 85
        fi

        if [[ ${match[1]} = "yes" ]]; then
            local needs_apt_update=1
        elif [[ ${match[1]} = "no" ]]; then
            local needs_apt_update=0
        else
            echoerr "Internal error: invalid installer \z[cyan]°NEEDS_APT_UPDATE\z[]° value: \z[yellow]°${match[1]}\z[]°"
        fi

        if [[ $script_env != $last_env ]]; then
            local last_priority=9
        elif (( $priority > $last_priority )); then
            echoerr "Internal error: installer script \z[yellow]°$script_name\z[]° has a higher priority than the previous script in the same env."
            return 86
        else
            local last_priority=$priority
        fi

        if ! (( $for_this_pc )) || ! (( $for_this_env )); then
            continue
        fi

        if grep -Fxq "$func_name" "$ADF_INSTALLED_LIST"; then
            local already_installed=1
        else
            local already_installed=0
        fi

        if (( $skip_if_installed )) && (( $already_installed )); then
            continue
        fi

        if ! (( ${only_install[(Ie)$func_name]} )) && [[ $only_install != "*" || $priority -eq 0 ]]; then
            continue
        fi

        if (( $already_installed )) && [[ $version_cmd != "-" ]]; then
            local prev_version=$( (eval "$version_cmd") | tr '\n' ' ' )
            to_install_previous_version+=("$prev_version")
        else
            to_install_previous_version+=("-")
        fi

        to_install=$((to_install + 1))
        to_install_functions+=("$func_name")
        to_install_priority+=("$priority")
        to_install_names+=("$script_name")
        to_install_env+=("$script_env")
        to_install_version_cmds+=("$version_cmd")
        to_install_already_installed+=($already_installed)

        if (( $needs_apt_update )); then
            local to_install_needs_apt_update=1
        fi

        if (( ${#func_name} > $longest_name )); then
            local longest_name=${#func_name}
        fi

        if (( ${#script_env} > $longest_env )); then
            local longest_env=${#script_env}
        fi
    done

    if [[ $to_install -eq 0 ]]; then
        if [[ $only_install != "*" ]]; then
            echoerr "Component \z[yellow]°$only_install\z[]° was not found."
            return 20
        fi

        if (( $skip_if_installed )); then
            printf '%s' "$cksum" > "$ADF_INSTALLER_HASH_FILE"
        fi

        return
    fi

    echoinfo ""
    echoinfo "Detected \z[cyan]°$to_install\z[]° component(s) to install or update."
    echoinfo ""

    for i in {1..$to_install}; do
        local env_spacing=$(printf " %.0s" {1..$((longest_env + 1 - ${#to_install_env[i]}))})
        local func_spacing=$(printf " %.0s" {1..$((longest_name + 1 - ${#to_install_functions[i]}))})

        if [[ ${to_install_priority[i]} -eq 1 ]]; then
            local color="yellow"
        elif [[ ${to_install_priority[i]} -eq 2 ]]; then
            local color="magenta"
        else
            local color="red"
        fi

        local infos_suffix="\z[gray]°- ${to_install_names[i]}\z[]°"

        if (( ${to_install_already_installed[i]} )); then
            infos_suffix+=" \z[magenta]°[update]\z[]°"
        fi

        echoinfo " * \z[cyan]°(${to_install_env[i]})\z[]°$env_spacing\z[$color]°${to_install_functions[i]}\z[]°$func_spacing$infos_suffix"
    done

    echowarn ""
    echowarn "Press \z[cyan]°<Enter>\z[]° to continue, or \z[cyan]°<Ctrl+C>\z[]° then \z[cyan]°<Ctrl+D>\z[]° to cancel."
    echowarn ""

    # Required trick to avoid getting the whole parent script to stop when getting a SIGINT (Ctrl+C)
    if ! passive_confirm; then
        echoerr "Aborted due to user cancel."
        return 30
    fi

    local started=$(timer_start)

    local namespaced_functions_prefix="___adf_installer_script_"

    eval "$(sed -e "s/^function\s\+/function $namespaced_functions_prefix/" <<< "$scripts")"

    if (( $to_install_needs_apt_update )); then
        if ! sudo apt update; then
            echoerr "Failed to update repositories."
            return 87
        fi
    fi

    export BASE_INSTALLER_TMPDIR="/tmp/adf-installer-$(humandate)"

    local failed=0
    local successes=()

    for i in {1..$to_install}; do
        local func_name="$namespaced_functions_prefix${to_install_functions[i]}"

        if ! commandexists "$func_name"; then
            echoerr "Internal error: namespaced function name \z[yellow]°$func_name\z[]° was not found in evaluated installer scripts."
            return 88
        fi
        
        echoinfo ">"
        echoinfo "> Installing component \z[magenta]°$i\z[]° / \z[magenta]°$to_install\z[]°: \z[yellow]°${to_install_names[i]}\z[]°"
        echoinfo ">"
        echoinfo ""

        export INSTALLER_TMPDIR="$BASE_INSTALLER_TMPDIR/$func_name"
        mkdir -p "$INSTALLER_TMPDIR"

        export COMPONENT_UPDATING=${to_install_already_installed[i]}

        if (( $ADF_FORCE_INSTALL )); then
            export COMPONENT_UPDATING=0
        fi

        if ! $func_name; then
            local failed=$((failed+1))
            echoerr "Component installation failed (see messages above)."
            echoerr "Waiting 5 seconds before next component..."
            
            if ! sleep 5; then
                echoerr "Installation aborted due to user's cancel."
                return 30
            fi

            continue
        fi

        if [[ ${to_install_version_cmds[i]} = "-" ]]; then
            local new_installed_ver="-"
        elif ! new_installed_ver=$( (eval "${to_install_version_cmds[i]}") | tr '\n' ' ' ); then
            local failed=$((failed+1))
            echoerr "Component installation seemingly succeeded but cannot fetch installed component's version."
            echoerr "Waiting 5 seconds before next component..."
            
            if ! sleep 5; then
                echoerr "Installation aborted due to user's cancel."
                return 30
            fi

            continue
        fi

        echosuccess ""

        local f_name="\z[yellow]°${to_install_names[i]}\z[]°"
        local register_success=1

        if (( ${to_install_already_installed[i]} )); then
            if [[ ${to_install_previous_version[i]} = "-" ]]; then
                local success="Successfully updated $f_name!"
                local register_success=0
            elif [[ $new_installed_ver = ${to_install_previous_version[i]} ]]; then
                local success="No update was needed for $f_name at version \z[yellow]°$new_installed_ver\z[]°!"
                local register_success=0
            else
                local success="Successfully updated $f_name from version \z[yellow]°${to_install_previous_version[i]}\z[]° to version \z[yellow]°$new_installed_ver\z[]°!"
            fi
        else
            if [[ $new_installed_ver != "-" ]]; then
                local success="Successfully installed component $f_name with version \z[yellow]°$new_installed_ver\z[]°!"
            else
                local success="Successfully installed component $f_name!"
            fi

            echo "${to_install_functions[i]}" >> "$ADF_INSTALLED_LIST"
        fi

        echosuccess "$success"

        if (( $register_success )); then
            successes+=("$success")
        fi
        
        echosuccess ""
    done

    if (( $failed )); then
        echoerr "Failed to install \z[yellow]°$failed\z[]° component(s)!"
        return 89
    fi

    echosuccess "All components were installed or updated successfully in \z[yellow]°$(timer_elapsed "$started")\z[]°!\n"

    if (( ${#successes} > 1 )); then
        for success in $successes; do
            echoinfo "* $success"
        done
    elif ! (( ${#successes} )); then
        echoinfo "* No update was needed for any component, or the updated components didn't have a version."
    fi

    command rm -rf "$BASE_INSTALLER_TMPDIR"

    if (( $skip_if_installed )); then
        printf '%s' "$cksum" > "$ADF_INSTALLER_HASH_FILE"

        if (( $ADF_CONF_MAIN_PERSONAL_COMPUTER )) && [[ ! -f $ADF_INSTALLER_MAIN_PC_CHECKED_MARKER ]]; then
            touch "$ADF_INSTALLER_MAIN_PC_CHECKED_MARKER"
        fi
    fi
}

function adf_update() {
    adf_install "${1:-*}"
}

if ! ADF_SKIP_INSTALLED=1 adf_install "*"; then
    export ADF_INSTALLER_ABORTED=1
fi
