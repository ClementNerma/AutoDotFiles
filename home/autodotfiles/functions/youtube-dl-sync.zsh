export ADF_YS_URL=".ytdlsync-url"
export ADF_YS_CACHE=".ytdlsync-cache"
export ADF_YS_BLACKLIST=".ytdlsync-blacklist"

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
        local json=$(command cat "$ADF_YS_CACHE")
    else
        local read_from_cache=0
        
        echoinfo "Downloading videos list from playlist URL \z[magenta]°$url\z[]°..."

        local started=$(timer_start)
        local json=$(yt-dlp -J --flat-playlist -i "$url")

        echoinfo "Videos list was retrieved in \z[yellow]°$(timer_end $started)\z[]°."

        echoverb "Checking and mapping JSON..."

        if ! json=$(echo -E "$json" | jq -c '[.entries[] | {id, title, url, ie_key}]'); then
            echoerr "Failed to parse JSON, dumped invalid content in file \z[magenta]°$fallible_json_path\z[]°."
            return 1
        fi

        echoverb "JSON is ready."
    fi

    echoverb "Checking JSON data..."

    local count=$(echo -E "$json" | jq 'length')

    echo -E "$json" > $ADF_YS_CACHE
    echoverb "Written JSON output to the cache file."

    if ! (( $count )); then
        echosuccess "No video to download!"
        rm "$ADF_YS_CACHE"
        return
    fi

    echoinfo "$count videos were found."
    echoinfo "Establishing the list of videos to download..."

    local empty_dir=0

    if [[ -z $(find . -not -name '.*') ]]; then
        empty_dir=1
    fi

    local display_list=()
    local download_list=()

    local max_spaces=$(echo -n "$count" | wc -c)

    IFS=$'\n' local video_ids=($(jq -r -c '.[] | .id' "$ADF_YS_CACHE"))
    IFS=$'\n' local video_titles=($(jq -r -c '.[] | .title' "$ADF_YS_CACHE"))
    IFS=$'\n' local video_ies=($(jq -r -c '.[] | .ie_key' "$ADF_YS_CACHE"))
    IFS=$'\n' local video_urls=($(jq -r -c '.[] | .url' "$ADF_YS_CACHE"))

    local blacklisted_video_ids=()

    if [[ -f "$ADF_YS_BLACKLIST" ]]; then
        IFS=$'\n' local blacklisted_video_ids=($(cat "$ADF_YS_BLACKLIST"))
    fi

    for i in {1..$count}; do
        local index=$((i-1))

        local current=$(printf "%${max_spaces}s" $i)

        local ie_url="${ADF_YS_IE_URLS[${video_ies[i]}]}"

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

        if (( ${blacklisted_video_ids[(Ie)video_id]} )); then
            echowarn "Skipping blacklisted video: \z[red]°$video_id\z[]° \z[blue]°${video_title}\z[]°"
            continue
        fi

        if (( $empty_dir )) || [[ -z $(find . -name "*-${video_id}.*") ]]; then
            if [[ ! -z $video_id && $video_id = "null" ]]; then
                local video_url=${ie_url}${video_ids[i]}
            fi

            local blacklist=${ADF_YS_IE_BLACKLIST[${video_ies[i]}]}

            if [[ ! -z "$blacklist" ]]; then
                local final_url=$(curl -Ls -o /dev/null -w '%{url_effective}' "$video_url")
                
                if [[ $final_url = "$blacklist"* ]]; then
                    echowarn "Blacklisting redirected video (\z[blue]°$video_url\z[]° => \z[red]°$final_url\z[]°)"
                    echo "$video_id" >> "$ADF_YS_BLACKLIST"
                fi
            fi

            echoinfo "\z[gray]°$current / $count\z[]° \z[magenta]°[$video_id]\z[]° \z[yellow]°${video_title}\z[]°"
            download_list+=("$video_url")
        fi
    done

    echoinfo "\nGoing to download \z[yellow]°${#download_list}\z[]° videos."

    if (( $read_from_cache )); then
        echowarn "Video list was retrieved from a cache file."
    fi

    if ! (( ${#download_list} )); then
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
    local bandwidth_limit="$ADF_CONF_YTDL_SYNC_LIMIT_BANDWIDTH"

    if [[ ! -z $SLOWSYNC ]]; then
        if [[ $SLOWSYNC = "1" ]]; then
            bandwidth_limit="2M"
        else
            bandwidth_limit="$SLOWSYNC"
        fi
    fi

    for i in {1..${#download_list}}; do
        echoinfo "| Downloading video \z[yellow]°${i}\z[]° / \z[yellow]°${#download_list}\z[]°: \z[magenta]°${download_list[$i]}\z[]°..."
    
        if ! YTDL_ALWAYS_THUMB=1 YTDL_LIMIT_BANDWIDTH="$bandwidth_limit" ytdl "${download_list[$i]}" --match-filter "!is_live"; then
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

# URL mapper for IDs in playlists
typeset -A ADF_YS_IE_URLS

function ytsync_register() {
    if [[ -z "$1" ]]; then
        echoerr "Please provide an IE key."
        return 1
    fi
    
    if [[ -z "$2" ]]; then
        echoerr "Please provide a URL prefix"
        return 2
    fi

    ADF_YS_IE_URLS[$1]="$2"
}

# URL blacklist for websites
typeset -A ADF_YS_IE_BLACKLIST

function ytsync_blacklist() {
    if [[ -z "$1" ]]; then
        echoerr "Please provide an IE key."
        return 1
    fi
    
    if [[ -z "$2" ]]; then
        echoerr "Please provide a URL prefix"
        return 2
    fi

    if [[ -z "${ADF_YS_IE_URLS[$1]}" ]]; then
        echoerr "Provided IE key is not registered."
        return 3
    fi

    ADF_YS_IE_BLACKLIST[$1]="$2"
}

# Look for videos that have a resolution lower than 1920x1080 pixels, and re-download them
# This function exists because the 'ytdl' function previously used the 'bestvideo+bestaudio/best' preset of Youtube-DL,
#  which doesn't always get the best quality unfortunately (only the highest bitrate, which is sometimes not the best resolution nor picture quality).
# By re-downloading these files, they keep the same filename and creation date, but in higher quality if they are still available.
function ytrepairres() {
    local loc="."

    if ! (( $YTDL_REPAIR_SIMULATE )) && [[ -z "$1" ]]; then
        echoerr "Please provide a download URL prefix."
        return 1
    fi

    if [[ ! -z "$2" ]]; then
        if [[ ! -d "$2" ]]; then
            echoerr "Provided path is not a directory."
            return 2
        fi

        loc="$2"
    fi

    local total=0
    local success=0
    local errors=0

    local prev_cwd=$(pwd)

    cd "$loc"
    
    for entry in *; do
        echoverb "Analyzing: $entry..."

        if [[ -d "$entry" ]]; then
            YTDL_REPAIR_SUBROUTINE=1 ytrepairres "$1" "$entry"
            continue
        fi

        total=$((total+1))

        local width=""
        
        if ! width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 "$entry"); then
            echoerr "Failed to get resolution for invalid video file \z[magenta]°$(basename "$entry")\z[]°."
            errors=$((errors+1))
            continue
        fi

        if (( $width < 1920 )); then
            if [[ $entry =~ ^[^\/]+\-([a-zA-Z0-9_\-]+)\.([^\.]+)$ ]]; then
                local url="$1${match[1]}"

                echoverb "Checking formats for $url..."

                if ! (yt-dlp -F "$url" | grep "1920x1080" > /dev/null); then
                    continue
                fi

                echoinfo "Previous file size: \z[yellow]°$(filesize "$entry")\z[]° for \z[magenta]°$(basename "$entry")\z[]°."
                echoinfo "URL: \z[gray]°$url\z[]°"

                if ! (( $YTDL_REPAIR_SIMULATE )) && ! YTDL_LIMIT_BANDWIDTH="$ADF_CONF_YTDL_SYNC_LIMIT_BANDWIDTH" ytdl "$url"; then
                    errors=$((errors+1))
                    echoerr "Failed to download video. Waiting 3 seconds now."
                    sleep 3
                else
                    echoinfo "New file size: \z[yellow]°$(filesize "$entry")\z[]° for \z[magenta]°$(basename "$entry")\z[]°."
                    echoinfo "------------------------------------------------------------------------------------------------"
                    success=$((success+1))
                fi
            else
                errors=$((errors+1))
                echoerr "Failed to match: $entry"
            fi
        fi
    done

    cd "$prev_cwd"

    if (( $YTDL_REPAIR_SUBROUTINE )); then
        return
    fi

    if (( $errors )); then
        echoerr "Failed with \z[yellow]°$errors\z[]° error(s)."
        return 9
    else
        echosuccess "Successfully downloaded in higher quality \z[yellow]°$success\z[]° videos (out of $total)!"
    fi
}
