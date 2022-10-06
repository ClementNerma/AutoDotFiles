export ADF_YT_REPAIR_DATE_LIST=".ytrepairdate"

function ytrepairdate() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a domain to use."
        return 1
    fi

    local url_prefix=${ADF_YS_DOMAINS_IE_URLS[$1]}

    if [[ -z $url_prefix ]]; then
        echoerr "Unknown cookie profile provided."
        return 2
    fi

    local cookie_profile=${ADF_YS_DOMAINS_PROFILE[$1]}
    local cookie_params=()

    if [[ ! -z $cookie_profile ]]; then
        local cookie_params=("--cookies" "$(ytdlcookies get-path "$cookie_profile")")
    fi

    echoinfo "Establishing the list of videos to repair..."

    IFS=$'\n' local entries=($(fd -e mp4 -e mkv -e ogg -e webm -e flv -e avi -e gif | sort))

    echoinfo "Found \z[yellow]°${#entries}\z[]° video files."

    if [[ ! -f $ADF_YT_REPAIR_DATE_LIST ]]; then
        touch "$ADF_YT_REPAIR_DATE_LIST"
    fi

    local max_spaces=$(echo -n "${#entries}" | wc -c)
    local errors=0

    for i in {1..${#entries}}; do
        local entry=${entries[i]}

        if [[ ! ${entries[i]} =~ ^.+\-([a-zA-Z0-9_\-]+)\.([^\.]+)$ ]]; then
            echoinfo "| Skipping file: \z[magenta]°$entry\z[]° (failed to extract ID)"
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

        echoinfo -n "| Treating video \z[yellow]°$(printf "%${max_spaces}s" $i)\z[]° / \z[yellow]°${#entries}\z[]°: \z[gray]°$video_id\z[]° \z[magenta]°$display_path\z[]°$suffix "

        if grep -Fx "$video_id" "$ADF_YT_REPAIR_DATE_LIST" > /dev/null; then
            echoc "\z[green]°ALREADY\z[]°"
            continue
        fi

        if ! upload_date=$(yt-dlp --get-filename -o "%(upload_date)s" "${cookie_params[@]}" "$url_prefix$video_id"); then
            local errors=$((errors + 1))
            echoc "\z[]°FAILED\z[]°"
            continue
        fi

        if [[ ! $upload_date =~ ^20[0-9]{6}$ ]]; then
            local errors=$((errors + 1))
            echoc "\z[]°INVALID\z[]° DATE\z[]°"
            continue
        fi

        if ! touch "$entry" -m -d "$upload_date"; then
            local errors=$((errors + 1))
            echoc "\z[]°FAILED TO SET DATE\z[]°"
            continue
        fi

        echosuccess "OK"
        printf "%s\n" "$video_id" >> "$ADF_YT_REPAIR_DATE_LIST"
    done

    if (( errors > 0 )); then
        echoerr "Failed with \z[yellow]°$errors\z[]° errors."
        return 1
    fi

    echosuccess "Successfully set date for \z[yellow]°${#entries}\z[]° videos!"
    rm "$ADF_YT_REPAIR_DATE_LIST"
}
