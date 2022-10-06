export ADF_YT_REPAIR_DATE_LIST=".ytrepairdate"
export ADF_YT_REPAIR_DATE_ERROR_LOG="$TEMPDIR/.ytrepairdate-log"

function ytrepairdate() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a domain to use."
        return 1
    fi

    if [[ -z $2 ]]; then
        local check_dir=$PWD
    elif [[ ! -d $2 ]]; then
        echoerr "Provided directory does not exist."
        return 2
    else
        local check_dir=$2
    fi

    local url_prefix=${ADF_YS_DOMAINS_IE_URLS[$1]}

    if [[ -z $url_prefix ]]; then
        echoerr "Unknown cookie profile provided."
        return 3
    fi

    local cookie_profile=${ADF_YS_DOMAINS_PROFILE[$1]}
    local cookie_params=()

    if [[ ! -z $cookie_profile ]]; then
        local cookie_params=("--cookies" "$(ytdlcookies get-path "$cookie_profile")")
    fi

    if ! (( $ADF_NO_VERBOSE )); then
        echoinfo "Establishing the list of videos to repair..."
    fi

    if ! _fdout=$(fd -e mp4 -e mkv -e ogg -e webm -e flv -e avi -e gif --search-path "$check_dir"); then
        echoerr "Command \z[yellow]°fd\z[]° failed (see error above)"
        return 10
    fi

    IFS=$'\n' local entries=($(echo -E "$_fdout" | sort))

    if [[ ${#entries} -eq 0 ]]; then
        echowarn "No video found."
        return
    fi

    if ! (( $ADF_NO_VERBOSE )); then
        echoinfo "Found \z[yellow]°${#entries}\z[]° video files."
    fi

    if [[ ! -f $ADF_YT_REPAIR_DATE_LIST ]]; then
        touch "$ADF_YT_REPAIR_DATE_LIST"
    fi

    local max_spaces=$(echo -n "${#entries}" | wc -c)
    local errors=0
    local warnings=0

    echo "===== Going to treat ${#entries} for IE: $1 =====\n" >> "$ADF_YT_REPAIR_DATE_ERROR_LOG"

    for i in {1..${#entries}}; do
        local entry=${entries[i]}

        if [[ ! ${entries[i]} =~ ^.+\-([a-zA-Z0-9_\-]+)\.([^\.]+)$ ]]; then
            echoinfo "| Skipping file: \z[magenta]°$entry\z[]° (failed to extract ID)"
            continue
        fi

        local video_id=${match[1]}
        local display_path=$entry
        local suffix=""

        if (( ${#entry} > 80 )); then
            local display_path="${entry:0:77}"
            local suffix="..."
        elif (( ${#entry} < 80 )); then
            local display_path="$entry$(printf " %.0s" {1..$((80 - ${#entry}))})"
        fi

        if grep -Fx "$video_id" "$ADF_YT_REPAIR_DATE_LIST" > /dev/null; then
            echoverb "Already treated: \z[entry]°"
            continue
        fi

        echoinfo -n "| Treating video \z[yellow]°$(printf "%${max_spaces}s" $i)\z[]° / \z[yellow]°${#entries}\z[]°: \z[gray]°$video_id\z[]° \z[magenta]°$display_path\z[]°$suffix "
        
        if ! upload_date=$(yt-dlp --get-filename -o "%(upload_date)s" "${cookie_params[@]}" "$url_prefix$video_id" 2>> "$ADF_YT_REPAIR_DATE_ERROR_LOG"); then
            local errors=$((errors + 1))
            echoc "\z[red]°FAILED\z[]°"
            printf "%s\n" "$video_id" >> "$ADF_YT_REPAIR_DATE_LIST"
            continue
        fi

        if [[ $upload_date = "NA" ]]; then
            local warnings=$((warnings + 1))
            echoc "\z[yellow]°NO DATE FOUND\z[]°"
            continue
        fi

        if [[ ! $upload_date =~ ^20[0-9]{6}$ ]]; then
            local errors=$((errors + 1))
            echoc "\z[red]°INVALID DATE: \z[yellow]°$upload_date\z[]°\z[]°"
            continue
        fi

        if ! sudo touch "$entry" -m -d "$upload_date"; then
            local errors=$((errors + 1))
            echoc "\z[red]°FAILED TO SET DATE\z[]°"
            continue
        fi

        echosuccess "OK"
        printf "%s\n" "$video_id" >> "$ADF_YT_REPAIR_DATE_LIST"
    done

    echo "=========================\n\n" >> "$ADF_YT_REPAIR_DATE_ERROR_LOG"

    if (( errors > 0 )); then
        echoerr "Failed with \z[yellow]°$errors\z[]° errors."
        echowarn "Please check the log file at \z[yellow]°$ADF_YT_REPAIR_DATE_ERROR_LOG\z[]°!"
        return 1
    fi

    if (( warnings > 0 )); then
        echowarn "Emitted $warnings warnings!"
        echowarn "Please check the log file at \z[yellow]°$ADF_YT_REPAIR_DATE_ERROR_LOG\z[]°!"
    fi

    if ! (( $ADF_NO_VERBOSE )); then
        echosuccess "Successfully set date for \z[yellow]°${#entries}\z[]° videos!"
    fi
    
    command rm "$ADF_YT_REPAIR_DATE_LIST"
}
