export ADF_YS_URL=".ytdlsync-url"
export ADF_YS_CACHE=".ytdlsync-cache"

function ytsync() {
    if [[ -z $1 ]]; then
        if [[ ! -f $ADF_YS_URL ]]; then
            echoerr "Missing URL container file \z[yellow]°$ADF_YS_URL\z[]°"
            return 1
        fi

        local url=$(command cat "$ADF_YS_URL")
    elif [[ -f $ADF_YS_URL ]]; then
        echoerr "An URL was provided but an URL file already exists."
        return 1
    else
        local url="$1"
        shift
        
        echowarn "Writing provided URL to local directory file."
        if [[ -f $ADF_YS_URL ]]; then rm "$ADF_YS_URL"; fi
        echo "$url" > "$ADF_YS_URL"
    fi

    if [[ -f $ADF_YS_CACHE ]]; then
        local read_from_cache=1
        echoinfo "Retrieving videos list from cache file."
    else
        local read_from_cache=0
        
        if ! ytsync_build_cache "$url"; then
            return 10
        fi

        echo
    fi

    IFS=$'\n' local entries=($(command cat "$ADF_YS_CACHE"))

    local count=$(head -n1 < "$ADF_YS_CACHE")

    local expected_lines=$((count * 4 + 1))

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

    local download_list=()
    local download_ies=()
    local download_names=()
    local download_bandwidth_limits=()

    for i in {1..${count}}; do
        local video_ie=${entries[((i*4-2))]}
        local video_id=${entries[((i*4-1))]}
        local video_title=${entries[(((i*4)))]}
        local video_url=${entries[((i*4+1))]}

        local beginning="\z[gray]°$(printf "%${max_spaces}s" $i) / $count\z[]° \z[magenta]°[$video_id]\z[]°"

        if [[ -z $(find . -name "*-${video_id}.*") ]]; then
            echoinfo "$beginning \z[yellow]°${video_title}\z[]°"
            download_list+=("$video_url")
            download_names+=("$video_title")
            download_ies+=("$video_ie")
            download_bandwidth_limits+=("${ADF_YS_DOMAINS_BANDWIDTH_LIMIT[$video_ie]}")
        else
            echoverb "$beginning Skipping \z[yellow]°${video_title}\z[]° (already downloaded)"
        fi
    done

    if [[ ${#download_list} -eq 0 ]]; then
        echosuccess "Nothing to download!"
        rm "$ADF_YS_CACHE"
        return
    fi

    echoinfo "\nGoing to download \z[yellow]°${#download_list}\z[]° videos."

    if (( $read_from_cache )); then
        echowarn "Video list was retrieved from a cache file."
    fi

    if ! (( ${count} )); then
        echosuccess "No video to download!"
        rm "$ADF_YS_CACHE"
        return
    fi

    echoinfo "Do you want to continue (Y/n)?"

    read 'answer?'

    if [[ ! -z $answer && $answer != "y" && $answer != "Y" ]]; then
        return 2
    fi

    local errors=0

    for i in {1..${#download_list}}; do
        local cookie_preset=${ADF_YS_DOMAINS_PRESET[$download_ies[i]]}
        local cookie_msg=""

        if [[ ! -z $cookie_preset ]]; then
            local cookie_msg=" (with cookie preset \z[cyan]°$cookie_preset\z[]°)"
        fi

        echoinfo "| Downloading video \z[yellow]°${i}\z[]° / \z[yellow]°${#download_list}\z[]°$cookie_msg: \z[magenta]°${download_names[i]}\z[]°..."

        if ! YTDL_ALWAYS_THUMB=1 YTDL_COOKIE_PRESET="$cookie_preset" YTDL_LIMIT_BANDWIDTH="${download_bandwidth_limits[i]}" ytdl "${download_list[i]}" --match-filter "!is_live"; then
            errors=$((errors+1))
            echowarn "Waiting 5 seconds before next video..."
            sleep 5
        fi
    done

    if [[ $errors -eq 0 ]]; then
        echosuccess "Done!"
        rm "$ADF_YS_CACHE"
    else
        echoerr "Failed to download \z[yellow]°$errors\z[]° video(s)."
        return 5
    fi
}

# Build cache for YTSync
function ytsync_build_cache() {
    if [[ -z "$1" ]]; then
        echoerr "Please provide a URL to build the cache from."
        return 1
    fi

    local url="$1"
        
    echoinfo "Downloading videos list from playlist URL \z[magenta]°$url\z[]°..."

    local started=$(timer_start)

    local json=$(yt-dlp -J --flat-playlist -i "$url")

    echoinfo "Videos list was retrieved in \z[yellow]°$(timer_end $started)\z[]°."

    echoverb "Checking and mapping JSON..."

    if ! json=$(echo -E "$json" | jq -c '[.entries[] | {ie_key, id, title, url}]'); then
        echoerr "Failed to parse JSON!"
        return 1
    fi

    echoverb "JSON is ready. Checking JSON data..."

    local count=$(echo -E "$json" | jq 'length')
    
    if ! (( $count )); then
        echosuccess "No video to download!"
        return
    fi

    echoinfo "$count videos were found."
    echoinfo "Establishing the list of videos to download..."

    local empty_dir=0

    if [[ -z $(find . -not -name '.*') ]]; then
        empty_dir=1
    fi

    local download_list=()

    local check_list_ies=()
    local check_list_ids=()
    local check_list_titles=()
    local check_list_urls=()

    local max_spaces=$(echo -n "$count" | wc -c)

    IFS=$'\n' local video_ies=($(echo -E "$json" | jq -r -c '.[] | .ie_key'))
    IFS=$'\n' local video_ids=($(echo -E "$json" | jq -r -c '.[] | .id'))
    IFS=$'\n' local video_titles=($(echo -E "$json" | jq -r -c '.[] | .title'))
    IFS=$'\n' local video_urls=($(echo -E "$json" | jq -r -c '.[] | .url'))

    local cache_content=""
    local total=0

    for i in {1..$count}; do
        local ie_url="${ADF_YS_DOMAINS_IE_URLS[${video_ies[i]}]}"

        if [[ -z $ie_url ]]; then
            echoerr "Found unregistered IE: \z[yellow]°${video_ies[i]}\z[]°"
            return 20
        fi

        local video_id=${video_ids[i]}
        local video_title=${video_titles[i]}
        local video_url=${video_urls[i]}
        
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

        if (( $empty_dir )) || [[ -z $(find . -name "*-${video_id}.*") ]]; then
            if [[ ! -z $video_id && $video_id != "null" ]]; then
                local video_url=${ie_url}${video_id}
            fi

            if (( ${ADF_YS_DOMAINS_CHECKING_MODE[${video_ies[i]}]} )); then
                check_list_ies+=("${video_ies[i]}")
                check_list_ids+=("$video_id")
                check_list_titles+=("$video_title")
                check_list_urls+=("$video_url")
            else
                cache_content+="${video_ies[i]}\n${video_id}\n${video_title}\n${video_url}\n\n"
                total=$((total+1))
            fi
        fi
    done

    if [[ ${#check_list_ids} -ne 0 ]]; then
        echoinfo "Checking availibility of \z[yellow]°${#check_list_ids}\z[]° videos..."

        for i in {1..${#check_list_ids}}; do
            ADF_DISPLAY_NO_NEWLINE=1 echoinfo "| Checking video \z[yellow]°$(printf "%${max_spaces}s" $i)\z[]° / \z[yellow]°${#check_list_ids}\z[]° \z[gray]°(${check_list_ids[i]})\z[]°..."

            if ! yt-dlp "${check_list_urls[i]}" --get-url > /dev/null 2>&1; then
                echoc " \z[red]°ERROR\z[]°"
                echoverb "| > Video \z[magenta]°${check_list_titles[i]}\z[]° is unavailable, skipping it."
                continue
            else
                echoc " \z[green]°OK\z[]°"
            fi

            cache_content+="${check_list_ies[i]}\n${check_list_ids[i]}\n${check_list_titles[i]}\n${check_list_urls[i]}\n\n"
            total=$((total+1))
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

function ytsync_register() {
    if [[ -z "$1" ]]; then
        echoerr "Please provide an IE key."
        return 1
    fi
    
    if [[ -z "$2" ]]; then
        echoerr "Please provide a URL prefix"
        return 2
    fi

    if [[ -z "$3" ]]; then
        echoerr "Please provide a checking mode."
        return 3
    fi

    if [[ -z "$4" ]]; then
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

    if [[ ! -z "$5" ]]; then
        ADF_YS_DOMAINS_PRESET[$1]="$5"
    fi
}
