export ADF_YS_URL=".ytdlsync-url"
export ADF_YS_CACHE=".ytdlsync-cache"
export ADF_YS_FILENAMING=".ytdlsync-filenaming"
export ADF_YS_LOCKFILES_DIR="$ADF_ASSETS_DIR/ytsync-lockfiles"

if [[ ! -d $ADF_YS_LOCKFILES_DIR ]]; then
    mkdir "$ADF_YS_LOCKFILES_DIR"
fi

function ytsync() {
    # === Determine the sync. URL and build the list of videos === #

    if [[ ! -z $1 ]]; then
        if [[ -f $ADF_YS_URL ]]; then
            echoerr "An URL was provided but an URL file already exists."
            return 1
        fi

        local url="$1"
        
        echowarn "Writing provided URL to local directory file."
        echo "$url" > "$ADF_YS_URL"

        if [[ ! -z $2 ]]; then
            local filenaming="$2"
            shift

            echowarn "Writing provided filenaming \z[cyan]°$filenaming\z[]° to local filenaming file."
            echo "$filenaming" > "$ADF_YS_FILENAMING"
        else
            local filenaming=""
        fi
    fi

    if [[ -f $ADF_YS_CACHE ]]; then
        local read_from_cache=1
        echoinfo "Retrieving videos list from cache file."
    else
        local read_from_cache=0
        
        if ! ytsync_build_cache; then
            return 10
        fi
    fi

    # === Parse and validate the cache === #

    IFS=$'\n' local entries=($(command cat "$ADF_YS_CACHE"))

    local count=$(head -n1 < "$ADF_YS_CACHE")

    local expected_lines=$((count * 5 + 1))

    if [[ $expected_lines -ne ${#entries} ]]; then
        echoerr "Corrupted sync cache: expected \z[yellow]°$expected_lines\z[]° for \z[magenta]°$count\z[]° entries, found \z[yellow]°${#entries}\z[]°."
        rm "$ADF_YS_CACHE"
        return 11
    fi

    if [[ $count -eq 0 ]]; then
        echosuccess "Nothing to download!"
        rm "$ADF_YS_CACHE"
        return
    fi

    local max_spaces=$(echo -n "$count" | wc -c)

    # === Build the list of videos to download === #

    local download_list=()
    local download_paths=()
    local download_ies=()
    local download_names=()
    local download_bandwidth_limits=()

    local last_pb=$(timer_start)

    local started=$(timer_start)

    for i in {1..${count}}; do
        # This system allows for super-fast checking
        local video_ie=${entries[((i*5-3))]}
        local video_path=${entries[((i*5-2))]}
        local video_id=${entries[((i*5-1))]}
        local video_title=${entries[(((i*5)))]}
        local video_url=${entries[((i*5+1))]}

        # This is the fastest checking method I've found, even faster than building a list of files beforehand
        # and checking if the file is in the array!
        # We don't check for videos existence if the data was read from cache as the files were already checked during its creation
        if ! (( $read_from_cache )) || [[ -z $(find "$video_path" -name "*-${video_id}.*") ]]; then
            local counter="\z[gray]°$(printf "%${max_spaces}s" $i) / $count\z[]°"

            if [[ $video_path = "." ]]; then
                local path_display=""
            else
                local path_display="\z[cyan]°$video_path\z[]° "
            fi

            progress_bar_print "$counter \z[magenta]°[$video_id]\z[]° $path_display\z[yellow]°${video_title}\z[]°"
            download_list+=("$video_url")
            download_paths+=("$video_path")
            download_names+=("$video_title")
            download_ies+=("$video_ie")
            download_bandwidth_limits+=("${ADF_YS_DOMAINS_BANDWIDTH_LIMIT[$video_ie]}")
        else
            local elapsed=$(timer_elapsed "$last_pb")

            if (( elapsed / 200000000 )) || [[ $i -eq $count ]]; then # 200 milliseconds
                local last_pb=$(timer_start)
                progress_bar_detailed "Checking videos from cache: " $i $count 0 $started
            fi
        fi
    done

    if [[ ${#download_list} -eq 0 ]]; then
        echosuccess "Nothing to download!"
        rm "$ADF_YS_CACHE"
        return
    fi

    echoinfo "\nGoing to download \z[yellow]°${#download_list}\z[]° videos."

    if ! (( ${count} )); then
        echosuccess "No video to download!"
        rm "$ADF_YS_CACHE"
        return
    fi

    echoinfo "Do you want to continue (Y/n)?"

    if ! confirm; then
        return 2
    fi

    # === Download videos === #

    local download_started=$(timer_start)
    local errors=0

    for i in {1..${#download_list}}; do
        local video_ie=${download_ies[i]}
        local lockfile="$ADF_YS_LOCKFILES_DIR/$video_ie.lock"

        if (( ${ADF_YS_DOMAINS_USE_LOCKFILE[$video_ie]} )); then
            while true; do
                if [[ -f $lockfile ]]; then
                    local started_waiting=$(timer_start)

                    while [[ -f $lockfile ]]; do
                        local pending=$(command cat "$lockfile")
                        local waiting_for=$(timer_show_seconds "$started_waiting")
                        ADF_UPDATABLE_LINE=1 echowarn ">> Waiting for lockfile removal (download pending at \z[magenta]°$pending\z[]°)... \z[cyan]°$waiting_for\z[]°"
                        sleep 1
                    done
                fi

                echo "$(pwd)" > "$lockfile"
                echowarn "\n>> Writting current path to lockfile"

                if [[ $(command cat "$lockfile") != "$(pwd)" ]]; then
                    echoerr "Internal error: inconsistency in the lockfile."
                else
                    break
                fi
            done
        fi

        local cookie_preset=${ADF_YS_DOMAINS_PRESET[$global_ie]}
        local cookie_msg=""

        if [[ ! -z $cookie_preset ]]; then
            local cookie_msg=" (with cookie preset \z[yellow]°$cookie_preset\z[]°)"
        fi

        echoinfo "| Downloading video \z[yellow]°${i}\z[]° / \z[yellow]°${#download_list}\z[]°: \z[magenta]°${download_names[i]}\z[]°..."
        echoinfo "| Video from \z[cyan]°$global_ie\z[]° at \z[green]°${download_list[i]}\z[]°$cookie_msg"

        if ! YTDL_ALWAYS_THUMB=1 YTDL_FILENAMING="$filenaming" YTDL_COOKIE_PRESET="$cookie_preset" \
             YTDL_LIMIT_BANDWIDTH="${YTDL_LIMIT_BANDWIDTH:-${download_bandwidth_limits[i]}}" \
             YTDL_OUTPUT_DIR="${download_paths[i]}" \
             ytdl "${download_list[i]}" --write-sub --sub-lang fr,en \
             --match-filter "!is_live"
        then
            local errors=$((errors+1))
            echowarn "Waiting 5 seconds before next video..."
            
            if ! passive_confirm; then
                if (( ${ADF_YS_DOMAINS_USE_LOCKFILE[$global_ie]} )); then
                    echowarn ">> Removing lockfile..."
                    rm "$lockfile"
                fi

                return
            fi
        fi

        progress_bar_detailed "Instant progress: " $i ${#download_list} 0 $download_started
        printf "\n\n"
    done

    if (( ${ADF_YS_DOMAINS_USE_LOCKFILE[$ie]} )); then
        echowarn ">> Removing lockfile..."
        rm "$lockfile"
    fi

    if [[ $errors -eq 0 ]]; then
        echosuccess "Done!"
        rm "$ADF_YS_CACHE"
    else
        echoerr "Failed to download \z[yellow]°$errors\z[]° video(s)."
        return 5
    fi
}

# Build cache for 'ytsync' (download videos and write them into the cache file)
# The goal is to make a cache which is both human-readable and super-fast to parse
function ytsync_build_cache() {
    # Download the list of videos

    echoinfo "Downloading videos list from all available playlists..."

    local started=$(timer_start)

    IFS=$'\n' local playlist_url_files=($(fd --hidden "$ADF_YS_URL"))

    if [[ -z $playlist_url_files ]]; then
        echoerr "No playlist to synchronize!"
        return 1
    fi

    echoinfo "Found \z[yellow]°${#playlist_url_files}\z[]° playlist(s) to treat."

    local fetching_started=$(timer_start)
    local json="[]"
    local total=0

    for i in {1..${#playlist_url_files}}; do
        local url=$(command cat "${playlist_url_files[i]}")
        local sub_json=$(yt-dlp -J --flat-playlist -i "$url")

        if ! sub_json=$(echo -E "$sub_json" |
            jq -c '[.entries[] | {ie_key, id, title, url} | .path = $path]' --arg path "$(dirname "${playlist_url_files[i]}")"
        ); then
            echoerr "Failed to parse JSON response!"
            return 1
        fi

        local sub_total=$(echo -E "$sub_json" | jq 'length')
        local total=$((total + sub_total))

        if ! json=$(echo -E "[ $json, $sub_json ]" | jq '.[0,1]' | jq -s 'add'); then
            echoerr "Failed to merge JSONs together!"
            return 2
        fi

        progress_bar_detailed "Getting playlists content: " $i ${#playlist_url_files} 0 $fetching_started " | $sub_total new videos ($total total)"
        printf "\n"
    done

    echoinfo "Videos list was retrieved in \z[yellow]°$(timer_end $started)\z[]°."

    echoverb "Checking and mapping JSON..."

    echoverb "JSON is ready. Checking JSON data..."

    local count=$(echo -E "$json" | jq 'length')

    if [[ $count -ne $total ]]; then
        echoerr "Internal error: count ($count) and total ($total) are not equal!"
        return 90
    fi
    
    if ! (( $count )); then
        echosuccess "No video to download!"
        return
    fi

    echoinfo "\z[yellow]°$count\z[]° videos were found."

    # === Get complete informations on the video and check the ones to download === #

    echoinfo "Establishing the list of videos to download..."

    local empty_dir=0

    if [[ -z $(find . -not -name '.*') ]]; then
        local empty_dir=1
    fi

    local download_list=()

    local check_list_ies=()
    local check_list_ids=()
    local check_list_titles=()
    local check_list_urls=()

    local max_spaces=$(echo -n "$count" | wc -c)

    IFS=$'\n' local video_paths=($(echo -E "$json" | jq -r -c '.[] | .path'))
    IFS=$'\n' local video_ies=($(echo -E "$json" | jq -r -c '.[] | .ie_key'))
    IFS=$'\n' local video_ids=($(echo -E "$json" | jq -r -c '.[] | .id'))
    IFS=$'\n' local video_titles=($(echo -E "$json" | jq -r -c '.[] | .title'))
    IFS=$'\n' local video_urls=($(echo -E "$json" | jq -r -c '.[] | .url'))

    local cache_content=""
    local total=0

    local started=$(timer_start)
    local last_pb=$(timer_start)

    for i in {1..$count}; do
        local elapsed=$(timer_elapsed "$last_pb")

        if (( elapsed / 200000000 )) || [[ $i -eq $count ]]; then # 200 milliseconds
            local last_pb=$(timer_start)
            progress_bar_detailed "Checking videos: " $i $count 0 $started
        fi

        # IE = extractor name
        local ie_url="${ADF_YS_DOMAINS_IE_URLS[${video_ies[i]}]}"

        if [[ -z $ie_url ]]; then
            echoerr "Found unregistered IE: \z[yellow]°${video_ies[i]}\z[]°"
            return 20
        fi

        local video_path=${video_paths[i]}
        local video_id=${video_ids[i]}
        local video_title=${video_titles[i]}
        local video_url=${video_urls[i]}
        
        # Some extractors won't give us the video identifier with "--flat-playlist"
        # So we get it using the video's URL thanks to the user-registered extractors
        if [[ -z $video_id || $video_id = "null" ]]; then
            if [[ -z $video_url || $video_url = "null" ]]; then
                echoerr "Video \z[yellow]°${video_title} does not have an ID nor an URL."
                return 21
            fi
            
            if [[ ! $video_url = "$ie_url"* ]]; then
                echoerr "Video \z[yellow]°${video_title}\z[]° with URL \z[yellow]°$video_url\z[]° does not follow the IE's URL convention: \z[yellow]°$ie_url\z[]°"
                return 22
            fi

            local video_id=${video_url[$((${#ie_url}+1)),-1]}
        fi

        # Don't download videos that are already present on the disk
        if ! (( $empty_dir )) && [[ ! -z $(find "$video_path" -name "*-${video_id}.*") ]]; then
            continue
        fi

        if [[ ! -z $video_id && $video_id != "null" ]]; then
            local video_url=${ie_url}${video_id}
        fi

        # Add the video to the checklist if the domain is marked as requiring a check for each video
        # (e.g. videos with paywalls etc.)
        if (( ${ADF_YS_DOMAINS_CHECKING_MODE[${video_ies[i]}]} )); then
            check_list_ies+=("${video_ies[i]}")
            check_list_ids+=("$video_id")
            check_list_titles+=("$video_title")
            check_list_urls+=("$video_url")
        else
            cache_content+="${video_ies[i]}\n${video_path}\n${video_id}\n${video_title}\n${video_url}\n\n"
            local total=$((total+1))
        fi
    done

    # Check videos if required
    if [[ ${#check_list_ids} -ne 0 ]]; then
        echoinfo "Checking availibility of \z[yellow]°${#check_list_ids}\z[]° videos..."

        for i in {1..${#check_list_ids}}; do
            echoinfo -n "| Checking video \z[yellow]°$(printf "%${max_spaces}s" $i)\z[]° / \z[yellow]°${#check_list_ids}\z[]° \z[gray]°(${check_list_ids[i]})\z[]°..."

            if ! yt-dlp "${check_list_urls[i]}" --get-url > /dev/null 2>&1; then
                echoc " \z[red]°ERROR\z[]°"
                echoverb "| > Video \z[magenta]°${check_list_titles[i]}\z[]° is unavailable, skipping it."
                continue
            else
                echoc " \z[green]°OK\z[]°"
            fi

            cache_content+="${check_list_ies[i]}\n${check_list_ids[i]}\n${check_list_titles[i]}\n${check_list_urls[i]}\n\n"
            local total=$((total+1))
        done
    fi

    echo "$total\n\n$cache_content" > "$ADF_YS_CACHE"
    echoinfo "Written download informations to cache."
}

# URL mapper for IDs in playlists
typeset -A ADF_YS_DOMAINS_IE_URLS
typeset -A ADF_YS_DOMAINS_CHECKING_MODE
typeset -A ADF_YS_DOMAINS_BANDWIDTH_LIMIT
typeset -A ADF_YS_DOMAINS_PRESET
typeset -A ADF_YS_DOMAINS_USE_LOCKFILE

# Register a domain to use with 'ytsync'
# Usage: ytsync_register <IE key> <URL prefix> <nocheck | alwayscheck> <bandwidth limit> [<use lockfile>] [<cookie preset>]
function ytsync_register() {
    if [[ -z $1 ]]; then
        echoerr "Please provide an IE key."
        return 1
    fi
    
    if [[ -z $2 ]]; then
        echoerr "Please provide a URL prefix"
        return 2
    fi

    if [[ -z $3 ]]; then
        echoerr "Please provide a checking mode."
        return 3
    fi

    if [[ -z $4 ]]; then
        echoerr "Please provide a bandwidth limit."
        return 4
    fi

    ADF_YS_DOMAINS_IE_URLS[$1]="$2"

    if [[ $3 = "nocheck" ]]; then
        ADF_YS_DOMAINS_CHECKING_MODE[$1]=0
    elif [[ $3 = "alwayscheck" ]]; then
        ADF_YS_DOMAINS_CHECKING_MODE[$1]=1
    else
        echoerr "Invalid checking mode provided for IE key \z[yellow]°$1\z[]°: \z[gray]°$3\z[]°"
        return 5
    fi

    ADF_YS_DOMAINS_BANDWIDTH_LIMIT[$1]="$4"

    if [[ $5 = "1" ]]; then
        ADF_YS_DOMAINS_USE_LOCKFILE[$1]=1
    elif [[ ! -z $5 ]] && [[ $5 != "1" ]]; then
        echoerr "Invalid value provided for lockfile status, must be either 0 or 1."
        return 6
    fi

    if [[ ! -z $6 ]]; then
        ADF_YS_DOMAINS_PRESET[$1]="$6"
    fi
}

# Remove a lockfile
function ytsync_unlock() {
    if [[ -z $1 ]]; then
        echoerr "Please provide an IE."
        return 1
    fi

    if [[ -z ${ADF_YS_DOMAINS_IE_URLS[$1]} ]]; then
        echoerr "Unknown IE provided."
        return 2
    fi

    if ! (( ${ADF_YS_DOMAINS_USE_LOCKFILE[$1]} )); then
        echoerr "This IE does not use lockfiles."
        return 3
    fi

    local lockfile="$ADF_YS_LOCKFILES_DIR/$1.lock"

    if [[ -f $lockfile ]]; then
        rm "$lockfile"
        echowarn "Lockfile forcefully removed."
    else
        echowarn "This IE was not locked."
    fi
}
