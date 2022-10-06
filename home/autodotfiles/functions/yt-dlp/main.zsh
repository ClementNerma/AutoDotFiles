# Software: Youtube-DL

# (NOTE: when updating this list, update "_ytdl_uncomplex_format" as well)
export ADF_YTDL_BEST_FORMAT_SUB_HD="bestvideo*[height>480]+bestaudio/best[height>480]/bestvideo*[height=480]+bestaudio/best[height=480]/bestvideo*[height>320]+bestaudio/best[height>320]/bestvideo*[height=320]+bestaudio/best[height=320]/bestvideo*[height>240]+bestaudio/best[height>240]/bestvideo*[height=240]+bestaudio/best[height=240]/bestvideo*[height>144]+bestaudio/best[height>144]/bestvideo*[height=144]+bestaudio/best[height=144]/bestvideo+bestaudio/best"
export ADF_YTDL_BEST_FORMAT_720P="bestvideo*[height>720][height<1080]+bestaudio/best[height>720][height<1080]/bestvideo*[height=720]+bestaudio/best[height=720]/$ADF_YTDL_BEST_FORMAT_SUB_HD"
export ADF_YTDL_BEST_FORMAT_1080P="bestvideo*[height>1080][height<1440]+bestaudio/best[height>1080][height<1440]/bestvideo*[height=1080]+bestaudio/best[height=1080]/$ADF_YTDL_BEST_FORMAT_720P"
export ADF_YTDL_BEST_FORMAT_1440P="bestvideo*[height>1440][height<2160]+bestaudio/best[height>1440][height<2160]/bestvideo*[height=1440]+bestaudio/best[height=1440]/$ADF_YTDL_BEST_FORMAT_1080P"
export ADF_YTDL_BEST_FORMAT_2160P="bestvideo*[height>2160][height<4320]+bestaudio/best[height>2160][height<4320]/bestvideo*[height=2160]+bestaudio/best[height=2160]/$ADF_YTDL_BEST_FORMAT_1440P"
export ADF_YTDL_DEFAULT_BEST_FORMAT="bestvideo*[height>=4320]+bestaudio/best[height>=4320]/$ADF_YTDL_BEST_FORMAT_2160P"

export ADF_YTDL_DEFAULT_FILENAMING="%(title)s-%(id)s.%(ext)s"

# Overriding variables:
# (NOTE: when updating this list, update "_ytdl_build_resume_cmdline" as well)
#
# * YTDL_FORMAT          => use a custom format
# * YTDL_TEMP_DIR        => download in the specified temporary directory before moving it to the final one
# * YTDL_OUTPUT_DIR      => download to the specified directory (default: the current working directory)
# * YTDL_FILENAMING      => use specific filenaming for output files
# * YTDL_ITEM_CMD        => run a command for each root item when download is finished
# * YTDL_LIMIT_BANDWIDTH => limit download bandwidth
# * YTDL_COOKIE_PROFILE  => load a cookie profile using "ytdlcookies"
# * YTDL_REPAIR_DATE     => repair date of all videos after download
# * YTDL_NO_THUMBNAIL    => don't download the thumbnail
function ytdl() {
	local tempdir=""
	
	local download_to=$PWD

	if [[ ! -z $YTDL_LIMIT_BANDWIDTH && ! $YTDL_LIMIT_BANDWIDTH = *"K" && ! $YTDL_LIMIT_BANDWIDTH = *"M" ]]; then
		echoerr "Invalid bandwidth limit provided."
		return 1
	fi

	local cookie_file=""

	if [[ ! -z $YTDL_COOKIE_PROFILE ]]; then
		echoverb "> Using profile \z[yellow]°$YTDL_COOKIE_PROFILE\z[]°..."

		if ! cookie_file=$(ytdlcookies get-path "$YTDL_COOKIE_PROFILE"); then
			echoerr "Unknown cookie profile provided"
			return 2
		fi
	fi

	if [[ ! -z $YTDL_OUTPUT_DIR ]]; then
		local download_to="${YTDL_OUTPUT_DIR%/}"

		if [[ $download_to != "." ]] && [[ $download_to != $PWD ]]; then
			echoinfo "> Downloading to provided directory: \z[cyan]°$download_to\z[]°"
		fi
	fi

	# Check if download must be performed in a temporary directory
	local tempdir="$ADF_CONF_YTDL_TEMP_DL_DIR_PATH/$RANDOM$RANDOM"

	if [[ -z $YTDL_TEMP_DIR ]]; then
		mkdir -p "$tempdir"
	elif [[ ! -d $YTDL_TEMP_DIR ]]; then
		echoerr "Resume path is not a directory!"
		return 1
	else
		local tempdir="${YTDL_TEMP_DIR%/}"
	fi

	if [[ "$(realpath "$PWD")" == "$(realpath "$tempdir")" ]]; then
		if [[ ! -z $YTDL_REPAIR_DATE ]]; then
			echoerr "Cannot repair date in non-temporary directory."
			return 3
		fi

		local is_tempdir_cwd=1
	else
		local is_tempdir_cwd=0
		echoinfo "> Downloading first to temporary directory: \z[magenta]°$tempdir\z[]°"
	fi

	if [[ ! -z $YTDL_REPAIR_DATE ]] && [[ -z ${ADF_YS_DOMAINS_IE_URLS[$YTDL_REPAIR_DATE]} ]]; then
		echoerr "Unknown profile provided for date repairing."
		return 4
	fi

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
		local cookie_params=("--cookies" "$cookie_file")
	else
		local cookie_params=()
	fi

	local resume_cmdline=$(_ytdl_build_resume_cmdline "$tempdir" "$@")

	local args=(
		--format "${YTDL_FORMAT:-$ADF_YTDL_DEFAULT_BEST_FORMAT}"
		--add-metadata
		--limit-rate "${YTDL_LIMIT_BANDWIDTH:-$ADF_CONF_YTDL_DEFAUT_LIMIT_BANDWIDTH}"
		--abort-on-unavailable-fragment
		--compat-options abort-on-error
		-o "$tempdir/${YTDL_FILENAMING:-$ADF_YTDL_DEFAULT_FILENAMING}"
		"${thumbnail_params[@]}"
		"${cookie_params[@]}"
		"$@"
	)

	# Perform the download
	if ! yt-dlp "${args[@]}"; then
		echoerr "Failed to download videos with Youtube-DL!"
		echoerr "You can resume the download with:"
		echowarn "$resume_cmdline"
		return 1
	fi

	# Repair date
	if [[ ! -z $YTDL_REPAIR_DATE ]]; then
		echoinfo "> Repairing date as requested"

		if ! ADF_NO_VERBOSE=1 ytrepairdate "$YTDL_REPAIR_DATE" "$tempdir"; then
			echoerr "Failed to get repair date!"
			echoerr "You can retry with:"
			echowarn "$resume_cmdline"
			return 1
		fi
	fi

	if (( $is_tempdir_cwd )); then
		return
	fi

	# Move ready files & clean up
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
					echowarn "$ytdl_cmdline"
					return 1
				fi
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

# Usage: _ytdl_build_resume_cmdline <tempdir> <arguments provided to 'ytdl'>
function _ytdl_build_resume_cmdline() {
	local ytdl_resume_vars=(
		"YTDL_FORMAT"
		# "YTDL_TEMP_DIR"
		"YTDL_OUTPUT_DIR"
		"YTDL_FILENAMING"
		"YTDL_ITEM_CMD"
		"YTDL_LIMIT_BANDWIDTH"
		"YTDL_COOKIE_PROFILE"
		"YTDL_REPAIR_DATE"
		"YTDL_NO_THUMBNAIL"
	)

	local setvars=()

	for varname in $ytdl_resume_vars; do
		if [[ ! -z ${(P)varname} ]]; then
			if [[ $varname != "YTDL_FORMAT" ]]; then
				setvars+=("$varname='${(P)varname}'")
				continue
			fi

			local uncomplexed=$(_ytdl_uncomplex_format "${(P)varname}")

			if [[ $uncomplexed =~ ^\\$ ]]; then
				setvars+=("$varname=\"$uncomplexed\"")
			else
				setvars+=("$varname='$uncomplexed'")
			fi
		fi
	done

	local args=()

	for arg in "$@"; do
		if [[ $arg =~ ^\-\-?[a-zA-Z0-9_]+$ ]]; then
			args+=("$arg")
		else
			args+=("'$arg'")
		fi
	done

	if ! (( ${#setvars} )); then
		printf '%s' "ytdlresume ${(j: :)args}"
	else
		printf '%s' "${(j: :)setvars} ytdlresume ${(j: :)args}"
	fi
}

function _ytdl_uncomplex_format() {
	local candidates=(
		"ADF_YTDL_BEST_FORMAT_SUB_HD"
		"ADF_YTDL_BEST_FORMAT_720P"
		"ADF_YTDL_BEST_FORMAT_1080P"
		"ADF_YTDL_BEST_FORMAT_1440P"
		"ADF_YTDL_BEST_FORMAT_2160P"
		"ADF_YTDL_DEFAULT_BEST_FORMAT"
	)

	for candidate in $candidates; do
		if [[ $1 = ${(P)candidate} ]]; then
			printf '%s' "\$$candidate"
			return
		fi
	done

	printf '%s' "$1"
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
