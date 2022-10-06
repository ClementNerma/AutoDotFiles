# Filename for the cache containing the list of files to repair
export ADF_YT_REPAIR_CACHE_FILE=".ytrepair-cache"

# Prefix for the stage number
export __yt_repair_stage_prefix="Stage: "

# Prefix for file lines
export __yt_repair_file_prefix="file: "

# Prefix for URL lines
export __yt_repair_url_prefix="url: "

# Look for videos that have a resolution lower than 1920x1080 pixels, and re-download them
# This function exists because the 'ytdl' function previously used the 'bestvideo+bestaudio/best' preset of Youtube-DL,
#  which doesn't always get the best quality unfortunately (only the highest bitrate, which is sometimes not the best resolution nor picture quality).
# By re-downloading these files, they keep the same filename and creation date, but in higher quality if they are still available.
function ytrepairres() {
    if ! (( $YTDL_REPAIR_SIMULATE )) && [[ -z $1 ]]; then
        echoerr "Please provide a download URL prefix."
        return 1
    fi

    if [[ -z $2 ]]; then
        echoerr "Please provide a bandwidth limit."
        return 2
    fi

    local bw_limit=$2

    local total=0
    local success=0
    local errors=0

    if [[ ! -f $ADF_YT_REPAIR_CACHE_FILE ]]; then
        if ! __ytrepairres_build_stage_1_cache "$1"; then
            return 10
        fi
    fi
    
    local cache_total=$(command cat "$ADF_YT_REPAIR_CACHE_FILE" | head -n1)

    local cache_stage=$(command cat "$ADF_YT_REPAIR_CACHE_FILE" | grep "^$__yt_repair_stage_prefix")
    local cache_stage=${cache_stage:${#__yt_repair_stage_prefix}}

    if [[ $cache_stage != "1" ]] && [[ $cache_stage != "2" ]] && [[ $cache_stage != "3" ]]; then
        echoerr "Corrupted cache: invalid stage number"
        rm "$ADF_YT_REPAIR_CACHE_FILE"
        return 4
    fi

    IFS=$'\n' local cache_files=($(command cat "$ADF_YT_REPAIR_CACHE_FILE" | grep "^$__yt_repair_file_prefix"))
    IFS=$'\n' local cache_urls=($(command cat "$ADF_YT_REPAIR_CACHE_FILE" | grep "^$__yt_repair_url_prefix"))

    if [[ ${#cache_files} -ne ${#cache_urls} ]]; then
        echoerr "Corrupted cache: mismatching number of files (${#cache_files}) and URLs (${#cache_urls})"
        rm "$ADF_YT_REPAIR_CACHE_FILE"
        return 3
    fi

    if [[ ${#cache_files} -ne $cache_total ]]; then
        echoerr "Corrupted cache: mismatching number of entries (${#cache_files}) with expected total ($cache_total)"
        rm "$ADF_YT_REPAIR_CACHE_FILE"
        return 4
    fi

    local stage=$((cache_stage + 1))

    echoinfo "Beginning \z[green]°stage $stage\z[]°, found \z[yellow]°${#cache_files}\z[]° videos to check."

    local max_spaces=$(echo -n "${#cache_files}" | wc -c)

    if [[ $stage = "2" ]]; then
        local stage_message="checking resolution"
    elif [[ $stage = "3" ]]; then
        local stage_message="checking availability of higher resolutions"
    elif [[ $stage = "4" ]]; then
        local stage_message="downloading higher-res"
    fi

    local outlist_files=()
    local outlist_urls=()

    for i in {1..${#cache_files}}; do
        local video_file=${${cache_files[i]}:${#__yt_repair_file_prefix}}
        local url=${${cache_urls[i]}:${#__yt_repair_url_prefix}}

        local filename=$(basename "$video_file")

        local progress=$(printf "%2s" $(($i * 100 / ${#cache_files})))

        echoinfo "\z[green]°Stage $((cache_stage + 1)) ($stage_message) |\z[]° Analyzing \z[gray]°$(printf "%${max_spaces}s" $i)/$cache_total ($progress%)\z[]° \z[cyan]°$(dirname "$video_file")/\z[]°\z[yellow]°$filename\z[]°..."

        if [[ $stage = "2" ]]; then
            if ! width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 "$video_file"); then
                echoerr "Failed to get resolution for invalid video file \z[magenta]°$filename\z[]°."
                local errors=$((errors+1))
                continue
            fi

            if (( $width >= 1920 )); then
                continue
            fi

            outlist_files+=("$video_file")
            outlist_urls+=("$url")

            continue
        fi
        
        if [[ $stage = "3" ]]; then
            if (yt-dlp -F "$url" | grep "1920x1080" > /dev/null); then
                outlist_files+=("$video_file")
                outlist_urls+=("$url")
            fi

            continue
        fi
        
        if [[ $stage = "4" ]]; then
            echoinfo "Previous file size: \z[yellow]°$(filesize "$video_file")\z[]° for \z[magenta]°$(basename "$video_file")\z[]°."

            if ! (( $YTDL_REPAIR_SIMULATE )) && ! YTDL_LIMIT_BANDWIDTH="$2" YTDL_OUTPUT_DIR=$(dirname "$video_file") ytdl "$url"; then
                local errors=$((errors+1))
                echoerr "Failed to download video. Waiting 3 seconds now."
                sleep 3
            else
                local success=$((success+1))
                echoinfo "New file size: \z[yellow]°$(filesize "$video_file")\z[]° for \z[magenta]°$(basename "$video_file")\z[]°."
                echoinfo "------------------------------------------------------------------------------------------------"
            fi
        fi
    done

    if (( $errors )); then
        echoerr "Finished stage $stage with \z[yellow]°$errors\z[]° error(s)."
    else
        echosuccess "Success!"
    fi

    if [[ ${#outlist_files} -eq 0 ]]; then
        echosuccess "No more files to treat!"
        return
    fi

    if (( $stage < 4 )); then
        local cache="${#outlist_files}\n${__yt_repair_stage_prefix}$stage"

        for i in {1..${#outlist_files}}; do
            cache+="\n\n${__yt_repair_file_prefix}${outlist_files[i]}\n${__yt_repair_url_prefix}${outlist_urls[i]}"
        done

        echo "$cache" > "$ADF_YT_REPAIR_CACHE_FILE"
        
        echoinfo "Waiting 5 seconds before next stage..."
        sleep 5

        ytrepairres "$@"
    else
        echosuccess "Successfully repaired videos!"
    fi
    
}

# Build the cache for 'ytrepairres'
function __ytrepairres_build_stage_1_cache() {
    if ! (( $YTDL_REPAIR_SIMULATE )) && [[ -z $1 ]]; then
        echoerr "Please provide a download URL prefix."
        return 1
    fi

    if [[ -f $ADF_YTREPAIR_CACHE_FILE ]]; then
        echoerr "A repair cache file already exists!"
        return 2
    fi

    echoinfo "Establishing the list of video files to check..."

    IFS=$'\n' local entries=($(fd -e mp4 -e mkv -e ogg -e webm -e flv -e avi -e gif | sort))

    echoinfo "Found \z[yellow]°${#entries}\z[]° video files."

    local cache_content=""

    local total=0
    local i=0
    local started=$(timer_start)

    for i in {1..${#entries}}; do
        local filename=$(basename "${entries[i]}")

        progress_bar_detailed "Stage 1: " $i ${#entries} 0 $started " | \z[cyan]°$(dirname "${entries[i]}")/\z[]°\z[yellow]°${filename:0:$((COLUMNS / 4))}\z[]°"

        if [[ ! ${entries[i]} =~ ^.+\-([a-zA-Z0-9_\-]+)\.([^\.]+)$ ]]; then
            continue
        fi

        local total=$((total + 1))
        cache_content+="Entry n°$total\n${__yt_repair_file_prefix}${entries[i]}\n${__yt_repair_url_prefix}$1${match[1]}\n\n"
    done

    echo "$total\n${__yt_repair_stage_prefix}1\n\n$cache_content" > "$ADF_YT_REPAIR_CACHE_FILE"
}
