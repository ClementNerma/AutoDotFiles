#!/usr/bin/zsh

#
# This file contains the integrated backup system for the main computer
#

# Perform a local backup
# Requires to set the "ADF_LOCBAK_PASSPHRASE" variable
# Arguments are paths to back up
# As well as "ADF_MIRROR_BACKUP" to duplicate it to another location
function adf_local_backup() {
    [[ -z $ADF_LOCBAK_PASSPHRASE ]] && { echoerr "Please provide a \z[yellow]°\$ADF_LOCBAK_PASSPHRASE\z[]° variable."; return 1 }

    if [[ -n $ADF_MIRROR_BACKUP && ! -d $ADF_MIRROR_BACKUP ]]; then
        echoerr "The provided mirror backup directory does not exist!"
    fi
    
    local passphrase
    passphrase=$(adf_obf_decode "$passphrase") || return 2

    [[ -z $passphrase ]] && { echoerr "The encryption passphrase cannot be empty!"; return 1 }

    if [[ -n $ADF_BACKUP_PREPARATION_SCRIPT ]]; then
        echoinfo " "
        echoinfo "(1/5) Running the preparation script..."
        echoinfo " "

        $ADF_BACKUP_PREPARATION_SCRIPT || { echoerr "Local backup preparation script exited with a non-zero code."; return 99 }
    else
        echowarn " "
        echowarn "(1/5) No preparation script to run, skipping this step."
        echowarn " "
    fi

    echoinfo " "
    echoinfo "(2/5) Building the files list..."
    echoinfo " "

    local listfile=$(mktemp)
    touch "$listfile"

    adf_build_files_list "$listfile" $ADF_BACKUPS_CONTENT || return 3

    if (( $ADF_ADD_ADF_FILES_TO_BACKUP )); then
        ADF_SILENT=1 zerbackup
        adf_build_files_list "$listfile" "$ADF_LAST_BACKUP_DIR"
    fi

    echoinfo ""
    echoinfo "(3/5) Compressing \z[yellow]°$(wc -l < "$listfile")\z[]° elements..."
    echoinfo ""

    local tmpfile="$TEMPDIR/adf-backup-$(humandate).tmp.7z"
    
    if ! 7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhc=on -mhe=on -spf2 -bso0 -p"$passphrase" "$tmpfile" @"$listfile"; then
        echoerr "Command \z[yellow]°7z\z[]° failed."
        command rm "$listfile"
        return 4
    fi

    command rm "$listfile"

    local outfile="$LOCBAKDIR/adf-$(humandate).7z"

    echoinfo " "
    echoinfo "(4/5) Moving the final archive..."
    echoinfo " "

    mv "$tmpfile" "$outfile" || { echoerr "Command \z[yellow]°mv\z[]° failed."; return 5 }

    if [[ -n $ADF_MIRROR_BACKUP ]]; then
        echoinfo " "
        echoinfo "(5/5) Mirroring the backup..."
        echoinfo " "

        cp "$outfile" "$ADF_MIRROR_BACKUP/$(basename "$outfile")" || { echoerr "Command \z[yellow]°cp\z[]° failed."; return 6 }
    else
        echowarn " "
        echowarn "(5/5) WARNING: No mirroring to perform, skipping this type."
        echowarn " "
    fi

    echosuccess "Done! Archive path is \z[magenta]°$outfile\z[]°"
}

function adf_build_files_list() {
    [[ -f $1 ]] || { echoerr "List file not found while building files list"; return 1 }

    local listfile="$1"; shift

    for item in "$@"; do
        >&2 echoinfo "> Treating: \z[magenta]°$item\z[]°"

        local files=""
        
        if [[ -f $item ]]; then
            files="$item"
        elif [[ ! -d $item ]]; then
            echoerr "Input directory \z[yellow]°$item\z[]° does not exist!"
            return 2
        elif ! files=$(fd --threads=1 --hidden --one-file-system --type 'file' --no-require-git --absolute-path --search-path "$item"); then
            echoerr "Command \z[yellow]°fd\z[]° failed."
            return 2
        fi

        files=$(printf "%s" "$files" | grep "\S")

        if [[ -z $files ]]; then
            echowarn ">  WARNING: No matching found for this item!"
        else
            printf "%s\n" "$files" | sort >> "$listfile"
        fi
    done
}
