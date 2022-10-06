# Filename for the cache containing the list of files to repair
export ADF_YT_REPAIR_CACHE_FILE=".ytrepair-cache"

# Prefix for file lines
export ADF_YT_REPAIR_CACHE_FILE_PREFIX="file: "

# Prefix for URL lines
export ADF_YT_REPAIR_CACHE_URL_PREFIX="url: "

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
        if ! __ytrepairres_build_cache "$1"; then
            return 10
        fi
    fi
    
    local total=$(command cat "$ADF_YT_REPAIR_CACHE_FILE" | head -n1)

    IFS=$'\n' local to_repair_files=($(command cat "$ADF_YT_REPAIR_CACHE_FILE" | grep "^$ADF_YT_REPAIR_CACHE_FILE_PREFIX"))
    IFS=$'\n' local to_repair_urls=($(command cat "$ADF_YT_REPAIR_CACHE_FILE" | grep "^$ADF_YT_REPAIR_CACHE_URL_PREFIX"))

    if [[ ${#to_repair_files} -ne ${#to_repair_urls} ]]; then
        echoerr "Corrupted cache: mismatching number of files (${#to_repair_files}) and URLs (${#to_repair_urls})"
        rm "$ADF_YT_REPAIR_CACHE_FILE"
        return 3
    fi

    if [[ ${#to_repair_files} -ne $total ]]; then
        echoerr "Corrupted cache: mismatching number of entries (${#to_repair_files}) with expected total ($total)"
        return 4
    fi

    echoinfo "\nFound \z[yellow]°${#to_repair_files}\z[]° videos to repair."

    for i in {1..${#to_repair_files}}; do
        local video_file=${to_repair_files[i]}
        local url=${to_repair_urls[i]}

        echoinfo "Treating file \z[yellow]°$i/${#to_repair_files}\z[]°: \z[cyan]°$(dirname "$video_file")/\z[]°\z[magenta]°$(basename "$video_file")\z[]°..."
        echoverb "Checking formats for \z[yellow]°$url\z[]°..."

        if ! (yt-dlp -F "$url" | grep "1920x1080" > /dev/null); then
            continue
        fi

        echoinfo "Previous file size: \z[yellow]°$(filesize "$entry")\z[]° for \z[magenta]°$(basename "$entry")\z[]°."

        if ! (( $YTDL_REPAIR_SIMULATE )) && ! YTDL_LIMIT_BANDWIDTH="$2" YTDL_OUTPUT_DIR=$(dirname "$video_file") ytdl "$url"; then
            local errors=$((errors+1))
            echoerr "Failed to download video. Waiting 3 seconds now."
            sleep 3
        else
            local success=$((success+1))
            echoinfo "New file size: \z[yellow]°$(filesize "$entry")\z[]° for \z[magenta]°$(basename "$entry")\z[]°."
            echoinfo "------------------------------------------------------------------------------------------------"
        fi
    done

    if (( $errors )); then
        echoerr "Failed with \z[yellow]°$errors\z[]° error(s)."
        return 9
    else
        echosuccess "Successfully downloaded in higher quality \z[yellow]°$success\z[]° videos (out of ${#entries})!"
    fi
}

# Build the cache for 'ytrepairres'
function __ytrepairres_build_cache() {
    if ! (( $YTDL_REPAIR_SIMULATE )) && [[ -z $1 ]]; then
        echoerr "Please provide a download URL prefix."
        return 1
    fi

    if [[ -f $ADF_YT_REPAIR_CACHE_FILE ]]; then
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

        progress_bar_detailed "Analyzing: " $i ${#entries} 0 $started " | \z[cyan]°$(dirname "${entries[i]}")/\z[]°\z[yellow]°${filename:0:$((COLUMNS / 4))}\z[]°"

        local width=""
        
        if ! width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 "${entries[i]}"); then
            echoerr "Failed to get resolution for invalid video file \z[magenta]°$filename\z[]°."
            local errors=$((errors+1))
            continue
        fi

        if (( $width >= 1920 )); then
            continue
        fi

        if [[ ! ${entries[i]} =~ ^.+\-([a-zA-Z0-9_\-]+)\.([^\.]+)$ ]]; then
            local errors=$((errors+1))
            continue
        fi

        local total=$((total + 1))
        cache_content+="Entry n°$total\n${ADF_YT_REPAIR_CACHE_FILE_PREFIX}${entries[i]}\n${ADF_YT_REPAIR_CACHE_URL_PREFIX}$1${match[1]}\n\n"
    done

    echo "$total\n\n$cache_content" > "$ADF_YT_REPAIR_CACHE_FILE"

    if (( $errors )); then
        echoerr "Failed to analyze \z[yellow]°$errors\z[]° files."
    fi
}