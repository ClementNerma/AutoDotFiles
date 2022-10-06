
# Download a full album from Youtube Music
# Ability to download to a custom output directory using the "$YTDL_ALBUM_OUTPUT_DIR"
# You can also run a custom command on each album directory by providing a command in "$YTDL_ALBUM_ITEM_CMD"
# It's also possible to suffix the downloaded items with their playlist ID by setting "$YTDL_ALBUM_ID_SUFFIX"
# Thumbnails downloading can be skipped by setting "$YTDL_SKIP_THUMBNAIL"
# Custom Youtube-DL folder can be set with "$YTDL_DIR_FORMAT"
function ytdlalbum() {
    if [[ -z $YTDL_ALBUM_PROFILE ]]; then
        echoerr "Please provide a cookies profile in variable \$YTDL_ALBUM_PROFILE. To list them, type: \z[magenta]°ytdlcookies list\z[]°"
        return 1
    fi

    if [[ -z $1 ]]; then
        echoerr "Please provide an album URL to download."
        return 1
    fi

    if [[ "$1" != "https://music.youtube.com/playlist?list="* ]]; then
        echoerr "This is not a valid YouTube Music Album/Playlist URL!"
        return 1
    fi

    local id_suffix=""

    if (( $YTDL_ALBUM_ID_SUFFIX )); then
        local id_suffix=" [%(playlist_id)s]"
    fi

    local dir_format="%(artist)s - %(release_year)s - %(album)s$id_suffix"

    if [[ ! -z $YTDL_DIR_FORMAT ]]; then
        local dir_format="$YTDL_DIR_FORMAT"
    fi

    local thumbnail_cmd="__ytdlalbumthumbnail"
    local thumbnail_args=""

    if (( $YTDL_SKIP_THUMBNAIL )); then
        local thumbnail_cmd=""
        local thumbnail_args=" --no-id4cover"
    fi

    YTDL_FORMAT="bestaudio" YTDL_OUTPUT_DIR="$YTDL_ALBUM_OUTPUT_DIR" YTDL_ITEM_CMD=("$thumbnail_cmd" "${YTDL_ALBUM_ITEM_CMD[@]}") YTDL_NO_THUMBNAIL=1 \
    ytdlcookies use "$YTDL_ALBUM_PROFILE" "$@" \
        -o "$dir_format/%(playlist_index)s.%(release_year)s.%(id)s. %(track)s.%(ext)s" \
        --exec "zsh $ADF_EXTERNAL_DIR/ytdl-ytmusic-tagger.zsh$thumbnail_args"
}

# Download a playlist from Youtube Music
function ytdlplaylist() {
    YTDL_DIR_FORMAT="%(playlist_title)s" YTDL_SKIP_THUMBNAIL=1 ytdlalbum "$@"
}

# (Internal) Download a thumbnail (requires tagging)
function __ytdlalbumthumbnail() {
    if [[ -z $1 || -z $YTDL_ALBUM_PROFILE ]]; then
        echoerr "Either profile, directory or both were not provided."
        return 1
    fi

    if [[ ! -d $1 ]]; then
        echoerr "Input directory \z[magenta]°$1\z[]° does not exist."
        return 1
    fi

    local id4cover_file="$1/__id4cover.txt"

    if [[ ! -f $id4cover_file ]]; then
        echoerr "Cannot download thumbnail (missing identification file \z[magenta]°$id4cover_file\z[]°)"
        return 1
    fi

    local id=$(cat "$id4cover_file")

    if [[ -z $id ]]; then
        echoerr "Cannot download thumbnail (identifier is empty)"
        return 1
    fi

    local thumbnail_url=$(ytdlcookies use-raw "$YTDL_ALBUM_PROFILE" --get-thumbnail "https://music.youtube.com/watch?v=$id")
    local thumbnail_url="${thumbnail_url%%\?*}"
    local thumbnail_url="${thumbnail_url/hqdefault/maxresdefault}"

    if [[ $? != 0 ]]; then
        echoerr "Failed to get thumbnail's URL."
        return 1
    fi
    
    local thumbnail_tmp="$1/cover.tmp.${thumbnail_url:t:e}"

    echoinfo ">> Downloading thumbnail for album \z[magenta]°$(basename "$1")\z[]° at \z[yellow]°$thumbnail_url\z[]°..."

    if ! dl "$thumbnail_url" "$thumbnail_tmp"; then
        echoerr "Failed to download thumbnail."
        return 1
    fi

    if ! ffmpeg -hide_banner -loglevel error -i "$thumbnail_tmp" -filter:v "crop=720:720:280:1000" "$1/cover.jpg"; then
        echoerr "Failed to crop thumbnail with FFMPEG."
        return 1
    fi

    rm "$thumbnail_tmp"
    rm "$id4cover_file"
}

export ADF_YTDL_COOKIES_PROFILE_DIR="$ADF_DATA_DIR/ytdl-cookie-profiles"

if [[ ! -d $ADF_YTDL_COOKIES_PROFILE_DIR ]]; then
    mkdir -p "$ADF_YTDL_COOKIES_PROFILE_DIR"
fi

alias yr="ytdlcookies renew"
alias yu="ytdlcookies use"
