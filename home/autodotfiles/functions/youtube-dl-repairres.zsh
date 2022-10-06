
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