export ADF_YS_URL_FILE=".ytdlsync-url"
export ADF_YS_CACHE_FILE=".ytdlsync-cache"
export ADF_YS_FILENAMING_FILE=".ytdlsync-filenaming"
export ADF_YS_FORMAT_FILE=".ytdlsync-quality"
export ADF_YS_AUTO_BLACKLIST_FILE=".ytdlsync-blacklist"
export ADF_YS_CUSTOM_BLACKLIST_FILE=".ytdlsync-custom-blacklist"

export ADF_YS_LOCKFILES_DIR="$ADF_ASSETS_DIR/ytsync-lockfiles"

if [[ ! -d $ADF_YS_LOCKFILES_DIR ]]; then
    mkdir "$ADF_YS_LOCKFILES_DIR"
fi

# To set up a playlist to synchronize: ytsync <url>
# To set up with a specific filenaming: ytsync <url> <filenaming>
# To set up with a specific profile: ytsync "withprofile[<profile> with_ie <alternative_ie>]:<url>"
function ytsync() {
    # === Determine the sync. URL and build the list of videos === #

    if [[ -n $1 ]]; then
        if [[ -f $ADF_YS_URL_FILE ]]; then
            echoerr "An URL was provided but an URL file already exists."
            return 1
        fi

        local url="$1"
        
        echowarn "Writing provided URL to local directory file."
        echo "$url" > "$ADF_YS_URL_FILE"

        if [[ -n $2 ]]; then
            local filenaming="$2"
            shift

            echowarn "Writing provided filenaming \z[cyan]°$filenaming\z[]° to local filenaming file."
            echo "$filenaming" > "$ADF_YS_FILENAMING_FILE"
        else
            local filenaming=""
        fi
    fi

    local cache_builder_config=$(ytsync_cache_builder_config)
    
    # TODO: install as a global package, put it in the installer scripts, and call it from here
    if ! TERM_WIDTH=$COLUMNS ytsync-cache-builder --config "$cache_builder_config" --sync-dir "$PWD" --display-colored-list; then
        return 10
    fi

    local format=""

    if [[ -f $ADF_YS_FORMAT_FILE ]]; then
        local format=$(command cat "$ADF_YS_FORMAT_FILE")
    fi

    # === Parse and validate the cache === #

    IFS=$'\n' local entries=($(command cat "$ADF_YS_CACHE_FILE"))

    local cache=$(cat "$ADF_YS_CACHE_FILE" | jq -r ".entries")

    if [[ $cache = "null" ]]; then
        echoerr "Invalid cache: no entries property!"
        return 11
    fi

    local count=$(echo -E "$cache" | jq -r ". | length")

    if [[ $count -eq 0 ]]; then
        echosuccess "Nothing to download!"
        rm "$ADF_YS_CACHE_FILE"
        return
    fi

    local max_spaces=$(echo -n "$count" | wc -c)

    # === Build the list of videos to download === #

    echoinfo "\nGoing to download \z[yellow]°$count\z[]° videos."

    if ! (( ${count} )); then
        echosuccess "No video to download!"
        rm "$ADF_YS_CACHE_FILE"
        return
    fi

    echoinfo "Do you want to continue (Y/n)?"

    confirm || return 2

    # === Download videos === #

    local download_started=$(timer_start)
    local errors=0
    local forecast_lock=0

    local di=0

    while (( $di <= $count )); do
        local di=$(($di + 1))

        local entry=$(echo -E "$cache" | jq -r ".[$((di - 1))]")

        local video_ie=$(echo -E "$entry" | jq -r ".ie_key")
        local video_dir=$(echo -E "$entry" | jq -r ".sync_dir")
        local video_id=$(echo -E "$entry" | jq -r ".id")
        local video_title=$(echo -E "$entry" | jq -r ".title")
        local video_url=$(echo -E "$entry" | jq -r ".url")

        local next_video_ie=$(echo -E "$cache" | jq -r ".[$((di))].ie_key")

        if [[ -z $video_ie ]] || [[ -z $video_dir ]] || [[ -z $video_id ]] || [[ -z $video_title ]] || [[ -z $video_url ]]; then
            echoerr "Invalid cache content: entry n°\z[yellow]°$i\z[]° has some missing data."
            return 11
        fi

        local lockfile="$ADF_YS_LOCKFILES_DIR/$video_ie.lock"
        local needlockfile=${ADF_YS_DOMAINS_USE_LOCKFILE[$video_ie]}

        if (( $forecast_lock )) && [[ $(command cat "$lockfile") != $PWD ]]; then
            echoerr "\nInternal error: inconsistency in the lockfile."
            local forecast_lock=0
        fi

        if ! (( $forecast_lock )) && (( $needlockfile )); then
            ytsync_wait_lockfile
        fi

        local cookie_profile=${ADF_YS_DOMAINS_PROFILE[$video_ie]}
        local cookie_msg=""

        if [[ -n $cookie_profile ]]; then
            local cookie_msg=" (with cookie profile \z[yellow]°$cookie_profile\z[]°)"
        fi

        if (( ${ADF_YS_DOMAINS_REPAIR_DATE_MODE[$video_ie]} )); then
            local repair_date="$video_ie"
        else
            local repair_date=""
        fi

        local bandwidth_limit=${ADF_YS_DOMAINS_BANDWIDTH_LIMIT[$video_ie]}

        if [[ -z $bandwidth_limit ]]; then
            echoerr "Internal error: failed to get bandwidth limit from pre-validated video: \z[magenta]°$video_url\z[]°"
            local errors=$((errors+1))
            continue
        fi

        local ytdl_out_file="$TEMPDIR/ytdl-err-$(date +%s%N).log"

        echoinfo "| Downloading video \z[yellow]°$di\z[]° / \z[yellow]°$count\z[]°: \z[magenta]°$video_title\z[]°..."
        echoinfo "| Video from \z[cyan]°$video_ie\z[]° at \z[green]°$video_url\z[]°$cookie_msg"

        if ! YTDL_FILENAMING="$filenaming" \
             YTDL_COOKIE_PROFILE="$cookie_profile" \
             YTDL_REPAIR_DATE="$repair_date" \
             YTDL_LIMIT_BANDWIDTH="${YTSYNC_OVERRIDE_BANDWIDTH_LIMIT:-${YTDL_LIMIT_BANDWIDTH:-$bandwidth_limit}}" \
             YTDL_OUTPUT_DIR="$video_dir" \
             YTDL_FORMAT="$format" \
             YTDL_FILENAMING_PREFIX="${ADF_YS_DOMAINS_FILENAME_PREFIX[$video_ie]}" \
             ytdl "$video_url" --write-sub --sub-lang fr,en \
             --match-filter "!is_live" \
             1>&1 2>&2 1>"$ytdl_out_file"
        then
            local ytdl_err=$(cat "$ytdl_out_file")
            command rm "$ytdl_out_file"

            if [[ $ytdl_err = *"HTTP Error 429: Too Many Requests."* ]]; then
                echowarn "Failed due to too many requests being made to server."
                echowarn ""

                local waiting=$((10 * 60))

                while (( $waiting > 0 )); do
                    local waiting=$((waiting - 1))
                    local waiting_for=$(humanduration "$waiting")

                    ADF_UPDATABLE_LINE=1 echowarn ">> Waiting before retry... \z[cyan]°$waiting_for\z[]°"
                    sleep 1
                done

                local di=(($di - 1))
                continue
            fi

            local errors=$((errors+1))
            echowarn "Waiting 5s before the next video..."
            
            if ! passive_confirm 5; then
                if (( $needlockfile )); then
                    echoverb ">> Removing lockfile..."
                    command rm "$lockfile"
                fi

                return
            fi
        fi

        command rm "$tmp_err_file"

        if (( $needlockfile )) && (( $di < $count )); then
            if [[ $next_video_ie = $video_ie ]]; then
                local forecast_lock=1
            else
                command rm "$lockfile"
            fi
        fi

        progress_bar_detailed "Instant progress: " $di $count 0 $download_started
        printf "\n\n"
    done

    if (( $needlockfile )); then
        echoverb ">> Removing lockfile..."
        command rm "$lockfile"
    fi

    if [[ $errors -eq 0 ]]; then
        echosuccess "Done!"
        rm "$ADF_YS_CACHE_FILE"
    else
        echoerr "Failed to download \z[yellow]°$errors\z[]° video(s)."
        return 5
    fi
}

# Lockfile handling
function ytsync_wait_lockfile() {
    while true; do
        if [[ -f $lockfile ]]; then
            local started_waiting=$(timer_start)
            local waited=0

            while [[ -f $lockfile ]]; do
                local waited=1
                local pending=$(command cat "$lockfile")
                local waiting_for=$(timer_elapsed_seconds "$started_waiting")

                ADF_UPDATABLE_LINE=1 echowarn ">> Waiting for lockfile removal (download pending at \z[magenta]°$pending\z[]°)... \z[cyan]°$waiting_for\z[]°"
                
                sleep 1
            done

            if (( $waited )); then
                echo ""
            fi
        fi

        echo "$PWD" > "$lockfile"
        echoverb ">> Writing current path to lockfile\n"

        local lockfile_content=$(command cat "$lockfile")

        if [[ $lockfile_content != $PWD ]]; then
            echoerr "Internal error: inconsistency in the lockfile, expected \z[yellow]°$PWD\z[]° but got \z[gray]°$lockfile_content\z[]°"
        else
            break
        fi
    done
}

# URL mapper for IDs in playlists
typeset -A ADF_YS_DOMAINS_IE_PLAYLISTS_URL_REGEX
typeset -A ADF_YS_DOMAINS_IE_VIDEOS_URL_REGEX
typeset -A ADF_YS_DOMAINS_IE_VIDEOS_URL_PREFIX
typeset -A ADF_YS_DOMAINS_CHECKING_MODE
typeset -A ADF_YS_DOMAINS_REPAIR_DATE_MODE
typeset -A ADF_YS_DOMAINS_BANDWIDTH_LIMIT
typeset -A ADF_YS_DOMAINS_PROFILE
typeset -A ADF_YS_DOMAINS_USE_LOCKFILE
typeset -A ADF_YS_DOMAINS_FILENAME_PREFIX
typeset -A ADF_YS_DOMAINS_RATE_LIMITED

# Register a domain to use with 'ytsync'
function ytsync_register() {
    typeset -A __args_declaration=(
        [required_positional]=1
        [optional_positional]=1
        [required_args]="playlists-url-regex, videos-url-regex, videos-url-prefix, bandwidth-limit"
        [optional_args]="always-check, repair-date, use-lockfile, cookie-profile, filename-prefix, rate-limited"
    )

    adf_args_parser

    local ie_key=${rest[1]}

    ADF_YS_DOMAINS_IE_PLAYLISTS_URL_REGEX[$ie_key]=${arguments[playlists-url-regex]}
    ADF_YS_DOMAINS_IE_VIDEOS_URL_REGEX[$ie_key]=${arguments[videos-url-regex]}
    ADF_YS_DOMAINS_IE_VIDEOS_URL_PREFIX[$ie_key]=${arguments[videos-url-prefix]}
    ADF_YS_DOMAINS_CHECKING_MODE[$ie_key]=${arguments[always-check]:-0}
    ADF_YS_DOMAINS_REPAIR_DATE_MODE[$ie_key]=${arguments[repair-date]:-0}
    ADF_YS_DOMAINS_USE_LOCKFILE[$ie_key]=${arguments[use-lockfile]:-0}
    ADF_YS_DOMAINS_BANDWIDTH_LIMIT[$ie_key]=${arguments[bandwidth-limit]}
    ADF_YS_DOMAINS_PROFILE[$ie_key]=${arguments[cookie-profile]}
    ADF_YS_DOMAINS_FILENAME_PREFIX[$ie_key]=${arguments[filename-prefix]}
    ADF_YS_DOMAINS_RATE_LIMITED[$ie_key]=${arguments[rate-limited]}
}

# Remove a lockfile
function ytsync_unlock() {
    if [[ -z $1 ]]; then
        echoerr "Please provide an IE."
        return 1
    fi

    if [[ -z ${ADF_YS_DOMAINS_IE_VIDEOS_URL_REGEX[$1]} ]]; then
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

# Remove all lockfiles
function ytsync_unlock_all() {
    for lockfile in "$ADF_YS_LOCKFILES_DIR/"*.lock(N); do
        command rm "$lockfile"
    done
}

function ytsync_cache_builder_config() {
    local config=$(
        echo -E "{}" \
        | jq ".url_filename = \$file" --arg file "$ADF_YS_URL_FILE" \
        | jq ".cache_filename = \$file" --arg file "$ADF_YS_CACHE_FILE" \
        | jq ".auto_blacklist_filename = \$file" --arg file "$ADF_YS_AUTO_BLACKLIST_FILE" \
        | jq ".custom_blacklist_filename = \$file" --arg file "$ADF_YS_CUSTOM_BLACKLIST_FILE" \
        | jq ".platforms = {}"
    )

    for id in ${(k)ADF_YS_DOMAINS_IE_VIDEOS_URL_REGEX}; do
        if (( ${ADF_YS_DOMAINS_CHECKING_MODE[$id]} )); then
            local checking_mode="true"
        else
            local checking_mode="false"
        fi

        if (( ${ADF_YS_DOMAINS_RATE_LIMITED[$id]} )); then
            local rate_limited="true"
        else
            local rate_limited="false"
        fi

        local platform_config=$(
            echo -E "{}" \
            | jq ".playlists_url_regex = \$value" --arg value "${ADF_YS_DOMAINS_IE_PLAYLISTS_URL_REGEX[$id]}" \
            | jq ".videos_url_regex = \$value" --arg value "${ADF_YS_DOMAINS_IE_VIDEOS_URL_REGEX[$id]}" \
            | jq ".needs_checking = \$value" --argjson value "$checking_mode" \
            | jq ".rate_limited = \$value" --argjson value "$rate_limited"
        )

        local config=$(
            echo -E "$config" \
            | jq ".platforms[\$name] = \$value" --arg name "$id" --argjson value "$platform_config"
        )
    done

    printf '%s' "$config"
}
