#
# Synchronization utility
#

# Synchronize two directories, like follows:
#
# 1. All files added to the source directory since the last synchronization will be copied
# 2. Files whose content change between two synchronization are ignored
# 3. Files that are deleted on the source are not deleted on the target
# 4. Modification times are taken into account
# 5. Files are encrypted during transfer using 7-Zip
function adf_sync_files() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a source directory."
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Please provide a target directory."
        return 2
    fi

    if [[ ! -d $1 ]]; then
        echoerr "Source directory does not exist."
        return 3
    fi

    if [[ ! -d $2 ]]; then
        echoerr "Target directory does not exist."
        return 4
    fi

    if [[ -z $ADF_LOCBAK_PASSPHRASE ]]; then
        echoerr "Please provide a \z[yellow]°\$ADF_LOCBAK_PASSPHRASE\z[]° variable."
        return 5
    fi


    local passphrase="$ADF_LOCBAK_PASSPHRASE"
    
    if (( $ADF_DEOBFUSCATE_PASSPHRASE )); then
        if ! passphrase=$(echo "$passphrase" | adf_obf_decode); then
            return 6
        fi
    fi

    if [[ -z $passphrase ]]; then
        echoerr "The encryption passphrase cannot be empty!"
        return 7
    fi

    echoinfo "Building the files list..."

    local source_files=$(fd --hidden --type 'file' --absolute-path --search-path "$1" | sort)

    echoinfo "Found \z[yellow]°$(wc -l <<< "$source_files")\z[]° files in the source directory."
    echoinfo "Determining which files to synchronize...\n"

    local tosync=()
    local sync_size=0

    while IFS= read -r file; do
        if [[ -d $file ]]; then continue; fi

        local rel_path=$(realpath --relative-to="$1" "$file")
        
        if [[ ! -f $(__adf_file_sync_path "$2" "$rel_path") ]]; then
            echoinfo "> Going to synchronize file: \z[green]°$(padendspaces "$(LC_TIME=fr_FR.UTF-8 date -r "$file")" 29)\z[]° \z[yellow]°$(padspaces "$(filesize "$file")" 10)\z[]° \z[magenta]°$rel_path\z[]°"
            tosync+=("$rel_path")
            local sync_size=$((sync_size+$(stat -c %s "$file")))
        fi
    done <<< "$source_files"

    if [[ ${#tosync} -eq 0 ]]; then
        echosuccess "Nothing to synchronize!"
        return
    fi

    echoinfo "\nGoing to synchronize \z[yellow]°${#tosync}\z[]° new files for a total size of \z[yellow]°$(humansize "$sync_size")\z[]°."
    
    echoinfo "Do you want to continue (Y/n)?"

    if ! confirm; then
        return 10
    fi

    local errors=0
    local max_spaces=$(echo -n "${#tosync}" | wc -c)

    echoinfo "Starting the synchronization..."

    for i in {1..${#tosync}}; do
        local dest_file=$(__adf_file_sync_path "$2" "${tosync[$i]}")
        local dest_file_dir=$(dirname "$dest_file")

        echoinfo "| Transferring encrypted file \z[yellow]°$i\z[]° / \z[yellow]°${#tosync}\z[]°: \z[gray]°[$(basename "$dest_file")]\z[]° \z[magenta]°${tosync[$i]}\z[]° (\z[yellow]°$(padspaces "$(filesize "$1/${tosync[$i]}")" 10)\z[]°)"

        if [[ $dest_file_dir != "$2" ]]; then
            mkdir -p "$dest_file_dir"
        fi

        if ! sync_7z_output=$(7z a -t7z -m0=Copy -mhe=on -p"$passphrase" "$dest_file" "$1/${tosync[$i]}" 2>&1 > /dev/null); then
            echoerr "> Failed to transfer file (command \z[yellow]°7z\z[]° failed): \z[yellow]°${sync_7z_output}\z[]°."
            local errors=$((errors+1))
        fi
    done

    if (( $errors > 0 )); then
        echoerr "Failed with \z[yellow]°$errors\z[]°."
        return 20
    fi

    echosuccess "\nSuccessfully synchronized \z[yellow]°${#tosync}\z[]° new files!"
}

function __adf_file_sync_path() {
    if [[ -z $1 ]]; then
        echoerr "Internal error: please provide an absolute target path"
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Internal error: please provide a relative source path"
        return 1
    fi

    local target="$1"
    local dir=$(dirname "$2")

    if [[ $dir != "." ]]; then
        local target="$target/$dir"
    fi

    printf '%s' "$target/$(hashstr "$(basename "$2")").7z"
}