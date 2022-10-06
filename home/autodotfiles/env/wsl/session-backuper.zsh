
# Checksum of the last session backup folder
export ADF_LAST_SESSION_BACKUP_CKSUM_FILE="$ADF_CONF_WSL_BACKUP_SESSION_DIR/last-session-backup-cksum.txt"

export ADF_SESSION_UPDATE_START_LINE_MARKER="@-- UPDATE:"
export ADF_SESSION_UPDATE_END_LINE_MARKER="@-- /UPDATE"

# Ensure directory exists
if [[ ! -d $ADF_CONF_WSL_BACKUP_SESSION_DIR ]]; then
    mkdir -p "$ADF_CONF_WSL_BACKUP_SESSION_DIR"
fi

# Backup the session
# Works by enumerating the windows of the said softwares' processes, and filtering them through PowerShell and ZSH
function adf_backup_session() {
    local tmpfile="$TEMPDIR/adf-backup-session-$(humandate).txt"
    touch "$tmpfile"

    # Iterate over all software profiles
    for software in $( _adf_bss_entries ); do
        adf_backup_software_session "$tmpfile" "$software" "$(_adf_bss_get_key "$software" "process_name")" "$(_adf_bss_get_key "$software" "window_format")"
    done

    local now=$(humandate)

    local content=$(command cat "$tmpfile")
    local cksum=$(cksumfile "$tmpfile")
    command rm "$tmpfile"

    local outfile="$ADF_CONF_WSL_BACKUP_SESSION_DIR/$(date +%F).txt"
    [[ -f $outfile ]]; local first_in_day=$?

    # Ignore empty values
    if [[ -z $content ]]; then
      echosuccess "Nothing to backup!"
      echo "@-- EMPTY | $now" >> "$outfile"

      if [[ -f $ADF_LAST_SESSION_BACKUP_CKSUM_FILE ]]; then
        command rm "$ADF_LAST_SESSION_BACKUP_CKSUM_FILE"
      fi

      return
    fi

    if ! (( $first_in_day )) && [[ -f $ADF_LAST_SESSION_BACKUP_CKSUM_FILE ]] && [[ $cksum -eq $(cat $ADF_LAST_SESSION_BACKUP_CKSUM_FILE) ]]; then
        echowarn "Nothing changed since previous backup."
        echo "@-- NOCHANGE | $now" >> "$outfile"
    else
        echo "$ADF_SESSION_UPDATE_START_LINE_MARKER $cksum | $now" >> "$outfile"
        echo "$content" >> "$outfile"
        echo "$ADF_SESSION_UPDATE_END_LINE_MARKER" >> "$outfile"

        echo "" >> "$outfile"
        echo -n "$cksum" > "$ADF_LAST_SESSION_BACKUP_CKSUM_FILE"
        echo -n "$finaldir"
    fi
}

# Backup a software's session
# Works by listing the windows from the provided process name using PowerShell
# Arguments: <output directory> <slug> <process name> <matching regex>
function adf_backup_software_session() {
    # Get the list of windows for the provided process
    local windows="$(process_windows "$3")"

    if [[ -z $windows ]]; then
        echoinfo "> Nothing to backup for software \z[cyan]°$3\z[]°"
        return
    fi

    # 000d = '\r'
    if [[ ${#windows} = 1 && $(printf '%04x\n' \'$windows[1]) = "000d" ]]; then
        echowarn "NOTE: No window found for software \z[cyan]°$3\z[]°."
        return
    fi

    # Iterate over the list of windows
    while IFS= read -r window; do
        # Ignore empty lines
    	if [[ ${#window} = 1 && $(printf '%04x\n' \'$window[1]) = "000d" ]]; then continue; fi

        # Ensure the window's format match the provided one
        # Note that accents may cause regex even like (.*) to fail
        if [[ ! $window =~ $4 ]]; then
            echowarn "WARNING: Invalid window format for software \z[cyan]°$3\z[]°: \z[magenta]°$window\z[]°"
            echo "$2: ##INVALID##:$window" >> "$1"
        else
	        echo "$2: ${match[1]}" >> "$1"
        fi
    done <<< "$windows"
}

# Compile the backup data in a compressed archive to take less space
# This is the only file that will be taken during backups
function adf_backup_session_compile() {
    if [[ -f $ADF_CONF_WSL_BACKUP_SESSION_COMPILATION ]]; then
        echowarn "Removing previous compilation archive..."
        rm "$ADF_CONF_WSL_BACKUP_SESSION_COMPILATION"
    fi

    echoinfo "Compiling session backups..."

    if (( $ADF_BACKUP_NO_COMPRESS )); then
        echowarn "Creating a NON-COMPRESSED archive."
        7z a -t7z -m0=Copy -mmt=1 -spf2 -bso0 "$ADF_CONF_WSL_BACKUP_SESSION_COMPILATION" "$ADF_CONF_WSL_BACKUP_SESSION_DIR" "-x!$(basename "$ADF_CONF_WSL_BACKUP_SESSION_COMPILATION")"
    else
        7z a -t7z -m0=lzma2 -mx=5 -mfb=64 -md=32m -ms=on -mhc=on -mhe=on -spf2 -bso0 "$ADF_CONF_WSL_BACKUP_SESSION_COMPILATION" "$ADF_CONF_WSL_BACKUP_SESSION_DIR" "-x!$(basename "$ADF_CONF_WSL_BACKUP_SESSION_COMPILATION")"
    fi

    if (( $? )); then
        echoerr "7-Zip failed (see error above)"
        return 1
    fi

    echosuccess "Done!"
}

# Restore the last session backed up with `backup_session`
# Previous backups can be restored by providing their checksum through the `CKSUM` variable
# Usage: restore_session [<software name>] [<ignore the last X entries>]
function adf_restore_session() {
    local filter=""

    if [[ ! -z $CKSUM ]]; then
      local filter="\-$CKSUM$"
    fi

    local go_back=${2:-0}

    local files=($(command ls -1A "$ADF_CONF_WSL_BACKUP_SESSION_DIR" | grep "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\.txt$" | sort -r))
    local session_file=""
    local content=""

    for file in $files; do
        local file_path="$ADF_CONF_WSL_BACKUP_SESSION_DIR/$file"

        if ! grep -q "$ADF_SESSION_UPDATE_START_LINE_MARKER" "$file_path"; then continue; fi

        local session_file="$file"
        local start_line=$(grep -n "$ADF_SESSION_UPDATE_START_LINE_MARKER" "$file_path" | tail -$((1 + $go_back)) | head -1 | cut -f1 -d':')
        local end_line=$(grep -n "$ADF_SESSION_UPDATE_END_LINE_MARKER" "$file_path" | tail -$((1 + $go_back)) | head -1 | cut -f1 -d':')

        local content=$(command cat "$file_path" | tail +$(($start_line + 1)) | head -n$(($end_line - $start_line - 1)))
        break
    done

    if [[ -z $session_file ]]; then
        echoerr "No session to restore."
        return 10
    fi

    echoinfo "Restoring session from session file \z[magenta]°$session_file\z[]°..."

    local content=$(dos2unix <<< "$content")

    # Treat all software one by one
    local softwares=()
    local files_to_open=()
    local failed=0

    while IFS= read -r line; do
        if ! [[ $line =~ ^([a-zA-Z0-9_\-]+):[[:space:]](.*)$ ]]; then
            echoerr "Invalid line: \z[yellow]°$line\z[]°"
        fi

        local software=${match[1]}
        
        if ! _adf_bss_has_entry "$software"; then
            echoerr "Unknown software \z[cyan]°$software\z[]°"
            local failed=1
            continue
        fi

        if [[ ! -z $1 && $software != $1 ]]; then
            continue
        fi

        local software_brackets="\z[cyan]°[$software]\z[]°"

        # Trim the file's name
        local file="$(echo "${match[2]}" | sed 's/ *$//g')"

        # Handle items tagged as invalids
        if [[ $file = "##INVALID##:"* ]]; then
        	echoerrnp ">> Software $software_brackets: invalid item found in backup: \z[yellow]°${file:12}\z[]°"
        	failed=$((failed+1))
        	continue
    	fi

        # Find the item to open
        local item=$(adf_find_session_item "$file" $(_adf_bss_get_array_lines "$software" "lookup_dirs"))

        # If the item is not found, increase the failures counter
        if [[ -z $item ]]; then
            local failed=$((failed+1))
        else
            # Else, open it
	    	echoinfo ">> Software $software_brackets: found \z[yellow]°$item\z[]°"

            if [[ -z $RESTORATION_DRY_RUN ]]; then
                softwares+=("$(_adf_bss_get_key "$software" "executable")")
                files_to_open+=("$(wslpath -w "$item")")
            fi
        fi
    done <<< "$content"

    if [[ ${#files_to_open} -eq 0 ]]; then
        echowarn "Nothing to open."
        return
    fi

    # HACK: Launching the software pieces directly in the loop above would make it break
    #       This is a known bug amongst most shells
    local opened=0

    echoverb "Opening ${#files_to_open} files..."
   
    for i in {1..${#files_to_open}}; do
    	runback "${softwares[i]}" "${files_to_open[i]}"
		opened=$((opened+1))
    done

    echoverb "Done."

    # Ensure all files to restore have been successfully opened
    if [[ $opened != ${#files_to_open} ]]; then
		echoerr "Only \z[yellow]°$opened\z[]° files were successfully opened ; \z[yellow]°${#files_to_open}\z[]° were expected."
		return 1
    fi

    if (( $failed > 0 )); then
    	return 2
	fi
}

# Find an item in a list of session-related directories
# Usage: adf_find_session_item <item name to find> <directories to look in...>
function adf_find_session_item() {
    if [[ -z $2 ]]; then
        echoerr "Please provide search directories."
        return 1
    fi

    echoverb "Looking for $1..."

    # Iterate over the list of lookup directories
    for dir in "${@:2}"; do
        # Assertion to avoid problems if the provided directory does not exist
        if [[ ! -d $dir ]]; then
            echoerr "Search directory not found: \z[yellow]°$dir\z[]°"
            return 2
        fi

        # Iterate over the recursive items list from the provided directory
		while IFS=$'\n' read -r candidate; do
            # If an item exists with the filename we're looking for...
		    if [[ -f $candidate/$1 || -d $candidate/$1 ]]; then
                # Success, display it and return
                echoverb "Found at: $candidate/$1"
                echo -n "$candidate/$1"
                return
            fi
		done <<< $(find "$dir" -type d | sort)
    done

    # If it was not found in the loop above, we can't do much more
    echoerr "File not found: \z[yellow]°$1\z[]°"
    return 3
}

# Run "restore_session" but only search and display the list of files without actually restoring anything
# Made for debug purposes
function adf_dry_restore_session() {
    RESTORATION_DRY_RUN=1 adf_restore_session "$@"
}

# Register a software to backup
# Arguments: <slug> <process name> <window format> <executable path> <lookup directories (array)>
function adf_register_session_backup() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a slug (will be used in backups' filenames)."
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Please provide a process name."
        return 2
    fi

    if [[ -z $3 ]]; then
        echoerr "Please provide a window format."
        return 3
    fi

    if [[ -z $4 ]]; then
        echoerr "Please provide an executable path."
        return 4
    fi

    if [[ -z $5 ]]; then
        echoerr "Please provide at least one lookup directory."
        return 5
    fi

    # Checkings
    if _adf_bss_has_entry "$1"; then
        if ! (( $ADF_DISABLE_BSS_OVERRIDING_WARNING )); then
            echowarn "WARNING: Overriding session backup profile for software: \z[cyan]°$1\z[]°"
        fi

        _adf_bss_delete_entry "$1"
    fi

    if [[ ! -f $4 ]]; then
        echoerr "Provided software path was not found at path: \z[yellow]°$4\z[]°"
        return 7
    fi

    for lookup_dir in ${@:5}; do
        if [[ ! -d $lookup_dir ]]; then
            echoerr "Lookup directory not found for software \z[cyan]°$1\z[]° at path \z[yellow]°$lookup_dir\z[]°"
            return 8
        fi
    done

    _adf_bss_set "$1" "process_name" "$2"
    _adf_bss_set "$1" "window_format" "$3"
    _adf_bss_set "$1" "executable" "$4"
    _adf_bss_set_array "$1" "lookup_dirs" "${@:5}"
}

# Load the array manager
source "$ADF_ENV_DIR/session-backuper-arr.zsh"
