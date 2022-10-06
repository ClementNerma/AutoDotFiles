# Software: Youtube-DL

export ADF_YTDL_DEFAULT_BEST_FORMAT="bestvideo*[height>2160]+bestaudio/best[height>2160]/bestvideo*[height=2160]+bestaudio/best[height=2160]/bestvideo*[height>1440]+bestaudio/best[height>1440]/bestvideo*[height=1440]+bestaudio/best[height=1440]/bestvideo*[height>1080]+bestaudio/best[height>1080]/bestvideo*[height=1080]+bestaudio/best[height=1080]/bestvideo*[height>720]+bestaudio/best[height>720]/bestvideo*[height=720]+bestaudio/best[height=720]/bestvideo*[height>480]+bestaudio/best[height>480]/bestvideo*[height=480]+bestaudio/best[height=480]/bestvideo*[height>320]+bestaudio/best[height>320]/bestvideo*[height=320]+bestaudio/best[height=320]/bestvideo*[height>240]+bestaudio/best[height>240]/bestvideo*[height=240]+bestaudio/best[height=240]/bestvideo*[height>144]+bestaudio/best[height>144]/bestvideo*[height=144]+bestaudio/best[height=144]/bestvideo+bestaudio/best"
export ADF_YTDL_DEFAULT_FILENAMING="%(title)s-%(id)s.%(ext)s"

# Overriding variables:
# * YTDL_FORMAT          => use a custom format
# * YTDL_TEMP_DIR        => download in the specified temporary directory before moving it to the final one
# * YTDL_OUTPUT_DIR      => download to the specified directory (default: the current working directory)
# * YTDL_FILENAMING      => use specific filenaming for output files
# * YTDL_ITEM_CMD        => run a command for each root item when download is finished
# * YTDL_LIMIT_BANDWIDTH => limit download bandwidth
# * YTDL_COOKIE_PRESET   => load a cookie preset using "ytdlcookies"
# * YTDL_NO_THUMBNAIL    => don't download the thumbnail
function ytdl() {
	local prev_cwd=$(pwd)
	local tempdir=""
	
	local download_to=$(pwd)

	if [[ ! -z $YTDL_LIMIT_BANDWIDTH && ! $YTDL_LIMIT_BANDWIDTH = *"K" && ! $YTDL_LIMIT_BANDWIDTH = *"M" ]]; then
		echoerr "Invalid bandwidth limit provided."
		return 1
	fi

	local cookie_file=""

	if [[ ! -z $YTDL_COOKIE_PRESET ]]; then
		echoverb "> Using preset \z[yellow]°$YTDL_COOKIE_PRESET\z[]°..."

		if ! cookie_file=$(ytdlcookies get-path "$YTDL_COOKIE_PRESET"); then
			return 2
		fi
	fi

	if [[ ! -z $YTDL_OUTPUT_DIR ]]; then
		local download_to="${YTDL_OUTPUT_DIR%/}"
		echoinfo "Downloading to custom directory: \z[magenta]°$download_to\z[]°"
	fi

	# Check if download must be performed in a temporary directory
	local tempdir="$ADF_CONF_YTDL_TEMP_DL_DIR_PATH/$(humandate)-$(now)"

	if [[ -z $YTDL_TEMP_DIR ]]; then
		mkdir -p "$tempdir"
	elif [[ ! -d $YTDL_TEMP_DIR ]]; then
		echoerr "Resume path is not a directory!"
		return 1
	else
		local tempdir="${YTDL_TEMP_DIR%/}"
	fi

	if [[ "$(realpath "$prev_cwd")" == "$(realpath "$tempdir")" ]]; then
		local is_tempdir_cwd=1
	else
		local is_tempdir_cwd=0
		echoinfo "> Downloading first to temporary directory: \z[magenta]°$tempdir\z[]°"
	fi

	cd "$tempdir"

	# Store the command in an history
	if (( $YTDL_NO_THUMBNAIL )); then
		local thumbnail_params=()
	else
		local thumbnail_params=("--embed-thumbnail")

		if [[ $1 == "https://www.youtube.com/"* || $1 == "https://music.youtube.com/"* ]]; then
			thumbnail_params+=("--merge-output-format" "mkv")
		fi
	fi

	if [[ ! -z $cookie_file ]]; then
		local cookie_param="--cookies"
	else
		local cookie_param=""
	fi

	# Perform the download
	if ! yt-dlp \
			--format "${YTDL_FORMAT:-$ADF_YTDL_DEFAULT_BEST_FORMAT}" \
			--add-metadata \
			"${thumbnail_params[@]}" \
			--limit-rate ${YTDL_LIMIT_BANDWIDTH:-$ADF_CONF_YTDL_DEFAUT_LIMIT_BANDWIDTH} $cookie_param $cookie_file \
			--abort-on-unavailable-fragment \
			--compat-options abort-on-error \
			-o "${YTDL_FILENAMING:-$ADF_YTDL_DEFAULT_FILENAMING}" \
			"$@"
	then
		cd "$prev_cwd"
		echoerr "Failed to download videos with Youtube-DL!"
		echoerr "You can resume the download with:"
		echoinfo "ytdlresume '$tempdir' '$1' ${@:2}"
		return 1
	fi

	if (( $is_tempdir_cwd )); then
		return
	fi

	# Move ready files & clean up
	cd "$prev_cwd"

	local files_count="$(command ls "$tempdir" -1A | wc -l)"
	local counter=0

	if [[ ! -z $YTDL_ITEM_CMD ]]; then
		local command_count=0
		
		for cmd in ${YTDL_ITEM_CMD[@]}; do
			if [[ ! -z $cmd ]]; then
				command_count=$((command_count + 1))
			fi
		done

		echoinfo "> Running custom commands ($command_count) on downloaded items..."

		for cmd in ${YTDL_ITEM_CMD[@]}; do
			if [[ -z $cmd ]]; then
				continue
			fi

			echoinfo ">> Running custom command: \z[magenta]°$cmd\z[]°..."

			for item in "$tempdir"/*(N)
			do
				if ! "$cmd" "$item"; then
					echoerr "Custom command failed"
					echoerr "You can resume the download with:"
					echoinfo "ytdlresume '$tempdir' '$1' ${*:2}"
					cd "$prev_cwd"
					return 1
				fi

				# Ensure we're still in the current working directory to avoid causing bugs if the executed commands decide to change it
				cd "$prev_cwd"
			done
		done
	fi

	echoinfo "> Moving [$files_count] files to output directory: \z[magenta]°$download_to\z[]°..."

	if [[ ! -d $download_to ]]; then
		mkdir -p "$download_to"
	fi

	for item in "$tempdir"/*(N)
	do
		local counter=$((counter+1))
		echoinfo "> Moving item $counter / $files_count: \z[magenta]°$(basename "${item%/}")\z[]°..."

		local tomove="${item%/}"

		if [[ -d $item ]]; then
			local item="$item/"
		fi

		if ! sudo mv "$item" "$download_to"
		then
			echoerr "Failed to move Youtube-DL videos! Temporary download path is:"
			echodata "$tempdir"
			return 1
		fi
	done

	echoinfo "Done!"
	rmdir "$tempdir"
}

function ytdlresume() {
	YTDL_TEMP_DIR="$1" ytdl "${@:2}"
}

function ytdlhere() {
	YTDL_TEMP_DIR="." ytdl "$@"
}

function ytdlclean() {
	rm "$ADF_CONF_YTDL_TEMP_DL_DIR_PATH"
}
