
function adf_borgmatic_backup() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a Borg repository path."
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Please provide a list of items to backup (as many as you want)"
        return 1
    fi

    if [[ ! -d $1 ]]; then
        echoerr "Provided Borg repository was not found."
        return 10
    fi

    echoinfo "Preparing to backup repository \z[yellow]°$(basename "$1")\z[]° at path \z[magenta]°$1\z[]°:"

    local borg_dirs_list=""

    for i in {2..$#}; do
        # Ignore empty arguments but don't make them fail the whole command
        if [[ -z ${@[i]} ]]; then
            continue
        fi

        if [[ -d ${@[i]} ]]; then
            echoinfo "| Source \z[yellow]°directory\z[]° n°$((i-1)): \z[magenta]°$(dirname "${@[i]}")/\z[]°\z[yellow]°$(basename "${@[i]}")\z[]°"
        elif [[ -f ${@[i]} ]]; then
            echoinfo "| Source \z[yellow]°file\z[]° n°$((i-1)): \z[magenta]°$(dirname "${@[i]}")/\z[]°\z[yellow]°$(basename "${@[i]}")\z[]°"
        else
            echoerr "Provided source item \z[magenta]°${@[i]}\z[]° was not found."
            return 10
        fi

        if [[ -z $borg_dirs_list ]]; then
            local borg_dirs_list="${@[i]}"
        else
            local borg_dirs_list="$borg_dirs_list,${@[i]}"
        fi
    done

    if ! withborgpass borg info "$1" > /dev/null; then
        echoerr "Provided directory is not a Borg repository, or passphrase is invalid (see above)!"
        return 11
    fi

    if [[ ! -f $ADF_BORGMATIC_CONFIG_FILE ]]; then
        echoerr "Borgmatic base configuration file was not found at path \z[magenta]°$ADF_BORGMATIC_CONFIG_FILE\z[]°"
        return 12
    fi

    echoinfo "Backing up using Borgmatic..."

    if ! withborgpass borgmatic --config "$ADF_BORGMATIC_CONFIG_FILE" --override location.repositories="[$1]" location.source_directories="[$borg_dirs_list]" \
        --progress --stats --files; then
        echoerr "Failed to back up (see above)."
        return 20
    fi

    echosuccess "Sucessfully backed up the source directories!"
}

# Path to the Borgmatic base configuration file
export ADF_BORGMATIC_CONFIG_FILE="$ADF_DIR/external/borgmatic-conf.yml"

if [[ ! -f $ADF_BORGMATIC_CONFIG_FILE ]]; then
    echowarn "WARNING: Borgmatic base configuration file was not found at path \z[magenta]°$ADF_BORGMATIC_CONFIG_FILE\z[]°"
fi
