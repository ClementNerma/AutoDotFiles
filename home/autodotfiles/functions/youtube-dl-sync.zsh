export ADF_YS_URL=".ytdlsync-url"
export ADF_YS_CACHE=".ytdlsync-cache"
export ADF_YS_CACHE_V2=".ytdlsync-cache2"
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

    if (( $YTDL_SYNC_V2 )); then
        local v2_mode=1
        echosuccess "Using v2 mode as requested."
    elif ! (( $YTDL_SYNC_NO_V2 )) && [[ $url = "https://www.youtube.com/"* ]]; then
        local v2_mode=1
        echosuccess "YouTube platform detected, using v2 mode."
    else
        local v2_mode=0
        echosuccess "No specific mode indicated, falling back to v1 mode."
    fi

    if (( $v2_mode )); then
        local cache_name="$ADF_YS_CACHE_V2"
    else
        local cache_name="$ADF_YS_CACHE"
    fi

    if [[ -f $cache_name ]]; then
        local read_from_cache=1
        echoinfo "Retrieving videos list from cache file."
        local json=$(command cat "$cache_name")
    else
        local read_from_cache=0
        
        echoinfo "Downloading videos list from playlist URL \z[magenta]°$url\z[]°..."

        local started=$(timer_start)

        if (( $v2_mode )); then
            local json=$(yt-dlp -J --flat-playlist -i "$url")

            echoinfo "Videos list was retrieved in \z[yellow]°$(timer_end $started)\z[]°."

            echoverb "Checking and mapping JSON..."

            if ! json=$(echo -E "$json" | jq -c '[.entries[] | {id, title, url, ie_key}]'); then
                echoerr "Failed to parse JSON!"
                return 1
            fi

            echoverb "JSON is ready."
        else
            echoinfo "Counting videos from playlist URL \z[magenta]°$url\z[]°..."

            local count=$(
                yt-dlp "$url" --flat-playlist |
                grep "Downloading video" |
                tail -n1 |
                sed -E "s/\[download\] Downloading video ([0-9]+) of ([0-9]+)/\2/"
            )

            if [[ -z "$count" ]]; then
                echoerr "Got empty count (did the retrieval failed?)"
                return 2
            fi

            echoinfo "Total count of videos is estimated at \z[yellow]°$count\z[]°."
            echoinfo "Downloading videos list from playlist URL \z[magenta]°$url\z[]°..."

            local started=$(timer_start)
            local json=$(yt-dlp -J --get-filename -i "$url" "${@:2}" 2>/dev/null | pv -l -W -s "$((count+1))" | tail -n1)
            
            local fallible_json_path="$TEMPDIR/ytsync-fallible-$(humandate).json"
            echoverb "Writing JSON data to temporary file \z[magenta]°$fallible\z[]°..."
            echo -E "$json" > "$fallible_json_path"

            echoinfo "Videos list was retrieved in \z[yellow]°$(timer_end $started)\z[]°."

            echoinfo "Checking and mapping JSON..."

            if ! json=$(echo -E "$json" | jq -c '[.entries[] | {id, title, _type, upload_date, webpage_url}]'); then
                echoerr "Failed to parse JSON, dumped invalid content in file \z[magenta]°$fallible_json_path\z[]°."
                return 1
            fi

            echoinfo "JSON is ready."
            command rm "$fallible_json_path"
        fi
    fi

    echoverb "Checking JSON data..."

    local count=$(echo -E "$json" | jq 'length')

    echo -E "$json" > $cache_name
    echoverb "Written JSON output to the cache file."

    if ! (( $count )); then
        echosuccess "No video to download!"
        rm "$cache_name"
        return
    fi

    echoinfo "$count videos were found."
    echoinfo "Establishing the list of videos to download..."

    local empty_dir=0

    if [[ -z $(find . -not -name '.*') ]]; then
        empty_dir=1
    fi

    local download_list=()

    local max_spaces=$(echo -n "$count" | wc -c)

    if (( $v2_mode )); then
        IFS=$'\n' local video_ids=($(jq -r -c '.[] | .id' "$cache_name"))
        IFS=$'\n' local video_titles=($(jq -r -c '.[] | .title' "$cache_name"))
        IFS=$'\n' local video_ies=($(jq -r -c '.[] | .ie_key' "$cache_name"))
        IFS=$'\n' local video_urls=($(jq -r -c '.[] | .url' "$cache_name"))

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

            if (( ${blacklisted_video_ids[(Ie)$video_id]} )); then
                echowarn "Skipping blacklisted video: \z[red]°$video_id\z[]° \z[blue]°${video_title}\z[]°"
                continue
            fi

            if (( $empty_dir )) || [[ -z $(find . -name "*-${video_id}.*") ]]; then
                if [[ ! -z $video_id && $video_id != "null" ]]; then
                    local video_url=${ie_url}${video_id}
                fi

                local blacklist=${ADF_YS_IE_BLACKLIST[${video_ies[i]}]}

                if [[ ! -z "$blacklist" ]]; then
                    local final_url=$(curl -Ls -o /dev/null -w '%{url_effective}' "$video_url")

                    if [[ $final_url = "$blacklist"* ]]; then
                        echowarn "\z[gray]°$current / $count\z[]° Blacklisting redirected video (\z[blue]°$video_url\z[]° => \z[red]°$final_url\z[]°)"
                        echo "$video_id" >> "$ADF_YS_BLACKLIST"
                        continue
                    fi
                fi

                echoinfo "\z[gray]°$current / $count\z[]° \z[magenta]°[$video_id]\z[]° \z[yellow]°${video_title}\z[]°"
                download_list+=("$video_url")
            fi
        done
    else
        IFS=$'\n' local video_type=($(jq -r -c '.[] | ._type' "$cache_name"))
        IFS=$'\n' local video_ids=($(jq -r -c '.[] | .id' "$cache_name"))
        IFS=$'\n' local video_titles=($(jq -r -c '.[] | .title' "$cache_name"))
        IFS=$'\n' local video_uploaded=($(jq -r -c '.[] | .upload_date' "$cache_name"))
        IFS=$'\n' local video_urls=($(jq -r -c '.[] | .webpage_url' "$cache_name"))

        for i in {1..$count}; do
            local index=$((i-1))

            if [[ ${video_type[i]} != "null" ]]; then
                if [[ ${video_type[i]} = "playlist" ]]; then
                    echowarn "Found playlist entry: \z[yellow]°${video_titles[i]}\z[]°"
                else
                    echowarn "Found unknown entry type \z[blue]°${video_type[i]}\z[]°: \z[yellow]°${video_titles[i]}\z[]°"
                fi

                return 20
            fi

            if [[ ${video_ids[i]} = "null" ]]; then
                continue
            fi

            local current=$(printf "%${max_spaces}s" $i)

            if (( $empty_dir )) || [[ -z $(find . -name "*-${video_ids[i]}.*") ]]; then
                local uploaded=$(echo -E "${video_uploaded[i]}" | sed -E "s/([0-9][0-9][0-9][0-9])([0-9][0-9])([0-9][0-9])/\3\/\2\/\1/")
                echoinfo "\z[gray]°$current / $count\z[]° \z[magenta]°[${video_ids[i]}]\z[]° \z[cyan]°$uploaded\z[]° \z[yellow]°${video_titles[i]}\z[]°"
                download_list+=("${video_urls[i]}")
            fi
        done
    fi

    echoinfo "\nGoing to download \z[yellow]°${#download_list}\z[]° videos."

    if (( $read_from_cache )); then
        echowarn "Video list was retrieved from a cache file."
    fi

    if ! (( ${#download_list} )); then
        echosuccess "No video to download!"
        rm "$cache_name"
        return
    fi

    echoinfo "Do you want to continue (Y/n)?"

    read 'answer?'

    if [[ ! -z $answer && $answer != "y" && $answer != "Y" ]]; then
        return 2
    fi

    local errors=0
    local bandwidth_limit="$ADF_CONF_YTDL_SYNC_LIMIT_BANDWIDTH"

    if (( $v2_mode )); then
        local bandwidth_limit="$ADF_CONF_YTDL_SYNC_LIMIT_BANDWIDTH_V2"
    fi

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
        rm "$cache_name"
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
