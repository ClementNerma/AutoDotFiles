#
# RClone utilities
#

function rclone_mirror() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a source."
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Please provide a destination."
        return 2
    fi

    if [[ ! -d $(wslpath "$1") ]]; then
        echoerr "Source directory was not found at path \z[yellow]°$1\z[]°."
        return 3
    fi

    local rclone_output_file="$TEMPDIR/rclone-output-$(humandate).txt"

    local started=$(timer_start)
    
    if ! __rclone_sync_nocheck "$1" "$2" --dry-run "${@:3}" > "$rclone_output_file" 2>&1; then
        echoerr "RClone failed: \z[yellow]°$(command cat "$rclone_output_file")\z[]°"
        rm "$rclone_output_file"
        return 4
    fi

    local rclone_list=$(cat "$rclone_output_file" | ansi2txt)
    rm "$rclone_output_file"

    local items=()
    local items_size=()
    local todelete=()
    local tomove=()
    local toupdatemodtime=()
    local unparsed=()
    local total=""
    local size=""
    local renamed=""
    local deleted=""
    local noitem=0

    while IFS= read -r line; do
        if [[ $line =~ ^[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9]?[0-9][[:space:]][0-9]?[0-9]:[0-9][0-9]:[0-9][0-9][[:space:]]NOTICE:[[:space:]]([^:]+):[[:space:]]Skipped[[:space:]](copy|delete|move|update[[:space:]]modification[[:space:]]time|make[[:space:]]directory|remove[[:space:]]directory)[[:space:]]as[[:space:]]--dry-run[[:space:]]is[[:space:]]set([[:space:]]\\(size[[:space:]]([0-9\\.]+)([KMGTi]+)?\\))?$ ]]; then
            if [[ ${match[2]} = "copy" ]]; then
                items+=("${match[1]}")
                items_size+=("${match[4]} ${match[5]}B")
            elif [[ ${match[2]} = "delete" ]] || [[ ${match[2]} = "remove directory" ]]; then
                todelete+=("${match[1]}")
            elif [[ ${match[2]} = "move" ]]; then
                tomove+=("${match[1]}")
            elif [[ ${match[2]} = "update modification time" ]]; then
                toupdatemodtime+=("${match[1]}")
            elif [[ ${match[2]} = "make directory" ]]; then
            else
                echoerr "Unreachable: expected 'copy', 'delete' or 'move' in regex result, got '${match[2]}'"
                return 5
            fi
        elif [[ $line =~ ^Transferred:[[:space:]]+0[[:space:]]/[[:space:]]0[[:space:]]Bytes,[[:space:]]-,[[:space:]]0[[:space:]]Bytes/s,[[:space:]]ETA[[:space:]]-$ ]]; then
            local noitem=1
        elif [[ $line =~ ^[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9]?[0-9][[:space:]][0-9]?[0-9]:[0-9][0-9]:[0-9][0-9][[:space:]]NOTICE:[[:space:]]([^:]+):[[:space:]]Duplicate[[:space:]]object[[:space:]]found[[:space:]]in[[:space:]]destination[[:space:]]-[[:space:]]ignoring$ ]]; then
            echowarn "$line"
        elif [[ $line =~ ^[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9]?[0-9][[:space:]][0-9]?[0-9]:[0-9][0-9]:[0-9][0-9][[:space:]]NOTICE:[[:space:]]+(.+)$ ]]; then
            echoerr "Failed to parse line: \z[white]°$line\z[]°"
            return 5
        elif [[ $line =~ ^Transferred:[^/]+/[[:space:]]([0-9\\.]+[[:space:]][KMGTiBytes]+),[[:space:]]100%,([[:space:]]0[[:space:]]B/s,)? ]]; then
            local size="${match[1]}"
            
            if [[ -n ${match[2]} ]]; then
                local total=0
            fi
        elif [[ $line =~ ^Transferred:[^/]+/[[:space:]]([0-9]+),[[:space:]]100%$ ]]; then
            local total="${match[1]}"
        elif [[ $line =~ ^Transferred:[[:space:]]+0[[:space:]]B[[:space:]]/[[:space:]]0[[:space:]]B,[[:space:]]-,[[:space:]]0[[:space:]]B/s,[[:space:]]ETA[[:space:]]-$ ]]; then
            local total=0
            local size="-"
        elif [[ $line =~ ^Renamed:[[:space:]]+([0-9]+)$ ]]; then
            local renamed=$((${match[1]}))
        elif [[ $line =~ ^Deleted:[[:space:]]+([0-9]+)[[:space:]]\\(files\\),[[:space:]]([0-9]+)[[:space:]]\\(dirs\\)$ ]]; then
            local deleted=$((${match[1]} + ${match[2]}))
        elif [[ $line =~ ^[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9]?[0-9][[:space:]][0-9]?[0-9]:[0-9][0-9]:[0-9][0-9][[:space:]]NOTICE:[[:space:]]*$ ]]; then
        elif [[ $line =~ ^Checks:[[:space:]]+[0-9]+[[:space:]]/[[:space:]][0-9]+,[[:space:]]100%$ ]]; then
        elif [[ $line =~ ^Elapsed[[:space:]]time:[[:space:]]+[0-9\\.smhd]+$ ]]; then
        else
            unparsed+=("$line")
        fi
    done <<< "$rclone_list"

    if [[ $noitem -eq 0 ]]; then
        local error_msg=""

        if [[ -z $size ]] && [[ -z $total ]]; then
            local error_msg="Failed to get both the total transfer size and the number of items to transfer."

        elif [[ -z $size ]]; then
            local error_msg="Failed to get the total transfer size."
        
        elif [[ -z $total ]]; then
            local error_msg="Failed to get the total number of items to transfer."
        
        elif [[ ${#items} -ne $total ]]; then
            local error_msg="Found \z[yellow]°${#items}\z[]°, but expected a total of \z[yellow]°$total\z[]° items to transfer!"
        
        elif (( ${#tomove} )) && [[ -z $renamed ]]; then
            local error_msg="Got a list of files to move but did not get their total count."
        
        elif [[ -n $renamed ]] && [[ ${#tomove} -ne $renamed ]]; then
            local error_msg="Found \z[yellow]°${#tomove}\z[]° items to move, but expected \z[yellow]°$renamed\z[]°!"
        
        elif (( ${#todelete} )) && [[ -z $deleted ]]; then
            local error_msg="Got a list of files to delete but did not get their total count."
        
        elif [[ -n $deleted ]] && [[ ${#todelete} -ne $deleted ]]; then
            local error_msg="Found \z[yellow]°${#todelete}\z[]° items to delete, but expected \z[yellow]°$deleted\z[]°!"
        fi

        if (( $error_msg )); then
            if (( ${#unparsed} )); then
                for line in $unparsed; do
                    echoerr "> Unparsed: >$line<"
                done
                echo ""
            fi
        
            echoerr "$error_msg"
            echoerr "Original output:"
            echowarn "$rclone_list"
            echoerr "Aborting transfer."

            return 9
        fi
    fi

    if (( ${#items} )); then
        local item_c=0
        while IFS= read -r item; do
            local item_c=$((item_c+1))
            echosuccess "> Going to transfer: \z[magenta]°$item\z[]° \z[yellow]°(${items_size[${items[(ie)$item]}]})\z[]°"
        done <<< $(printf '%s\n' "${items[@]}" | sort -n)
        echo ""
    fi

    if (( ${#tomove} )); then
        while IFS= read -r item; do
            echowarn "> Going to move: \z[magenta]°$item\z[]°"
        done <<< $(printf '%s\n' "${tomove[@]}" | sort -n)
        echo ""
    fi

    if (( ${#toupdatemodtime} )); then
        while IFS= read -r item; do
            echoinfo "> Going to update modtime for: \z[magenta]°$item\z[]°"
        done <<< $(printf '%s\n' "${toupdatemodtime[@]}" | sort -n)
        echo ""
    fi

    if (( ${#todelete} )); then
        while IFS= read -r item; do
            echowarn "> Going to delete: \z[magenta]°$item\z[]°"
        done <<< $(printf '%s\n' "${todelete[@]}" | sort -n)
        echo ""
    fi

    if (( ${#unparsed} )); then
        for line in $unparsed; do
            echoerr "> Unparsed: $line"
        done
        echo ""
    fi

    echoinfo "Built items list in \z[gray]°$(timer_elapsed "$started")\z[]°."
    echoinfo "Found \z[yellow]°${#items}\z[]° item(s) to transfer, \z[yellow]°${#tomove}\z[]° to move, \z[yellow]°${#toupdatemodtime}\z[]° to update modtime of and \z[yellow]°${#todelete}\z[]° to delete for a total of \z[yellow]°$size\z[]°."

    if [[ ${#items} -eq 0 && ${#toupdatemodtime} -eq 0 && ${#todelete} -eq 0 && ${#tomove} -eq 0 ]]; then
        echosuccess "Nothing to do."
        return
    fi

    if (( $DRY_RUN )); then
        return
    fi

    echo ""
    echowarn "Confirm the synchronization (Y/n)?"

    read "answer?"

    if [[ -n $answer && $answer != "y" && $answer != "Y" ]]; then
        return 2
    fi
    
    echoinfo "Sleeping 2 seconds before starting..."
    sleep 2

    if ! __rclone_sync_nocheck --check-first --progress "$@"; then
        return 10
    fi

    echosuccess "Successfully synchronized \z[magenta]°$1\z[]° to \z[magenta]°$2\z[]°."
}

function __rclone_sync_nocheck() {
    local cmdname="rclone"

    if (( $IS_WSL_ENV )); then
        local cmdname="$cmdname.exe"
    fi

    "$cmdname" sync \
        --progress-terminal-title \
        --stats-file-name-length 0 \
        --order-by "name,mixed,75" \
        --transfers 8 \
        --filter "- System Volume Information/**" \
        --filter "- \$RECYCLE.BIN/**" \
        --filter "- msdownld.tmp/**" \
        --filter "- desktop.ini" \
        --filter "- sync.ffs_db" \
        --create-empty-src-dirs \
        --track-renames \
        --track-renames-strategy "modtime,size" \
        "$@"

    # Use strategy "leaf,size" for other remotes when modtime not available
}