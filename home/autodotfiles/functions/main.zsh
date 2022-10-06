#
# This file defines global functions and aliases
#

# Backup a project
function bakproj() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a source directory."
		return 1
	fi

	local target="$2"

	if [[ -z $target ]]; then
		local input_path=$(realpath "$1")
		local target="$(dirname "$input_path")/$(basename "$input_path")-$(humandate)"
	fi

	if [[ ! -d $1 ]]; then
		echoerr "Source does not exist!"
		return 3
	fi

	if [[ -f $target || -d $target ]]; then
		echoerr "Target already exists!"
		return 4
	fi

	local files=""
	
	local cwd=$(pwd)

	if ! files=$(fd --threads=1 --hidden --one-file-system --type 'file' --search-path "$1" --absolute-path); then
		cd "$cwd"
		echoerr "Command \z[yellow]°fd\z[]° failed."
		return 2
	fi

	local files=$(printf "%s" "$files" | grep "\S" | sort)
	
	if [[ -z $files ]]; then
		echoerr "Directory is empty."
		return 3
	fi

	local count=$(wc -l <<< "$files")

	mkdir "$target"

	local i=0

	while IFS= read -r file; do
		local i=$((i+1))
		local relative="$(realpath --relative-to="$1" "$file")"
		local dest="$target/$relative"

		CLEAR_COMPLETE_SUFFIX=1 progress_bar "Copying: " $i $count 0 " \z[magenta]°$relative\z[]°"

		mkdir -p "$(dirname "$dest")"
		cp "$file" "$dest"
	done <<< "$files"

	echosuccess "Done in \z[magenta]°$target\z[]°"
}

# Backup the current project
function bakthis() {
	bakproj "$(pwd)" "$(dirname "$(pwd)")/$(basename "$(pwd)")-$(humandate)"
}

# Run a Cargo project located in the projects directory
function cargext() {
	cargo run "--manifest-path=$PROJDIR/$1/Cargo.toml" -- ${@:2}
}

# Run a Cargo project located in the projects directory in release mode
function cargextr() {
	cargo run "--manifest-path=$PROJDIR/$1/Cargo.toml" --release -- ${@:2}
}

# Rename a Git branch
function gitrename() {
    local old_branch=$(git rev-parse --abbrev-ref HEAD)
	echoinfo "Renaming branch '$old_branch' to '$1'..."
	git branch -m "$1"
	git push origin -u "$1"
	git push origin --delete "$old_branch"
}

# A simple 'rm' with progress
function rmprogress() {
	if [[ -z $1 ]]; then
		echoerr "Missing operand for 'rmprogress'"
		return 1
	fi
	
	rm -rv "$1" | pv -l -s $( du -a "$1" | wc -l ) > /dev/null
}

# Move a folder's content with progress
function mvprogress() {
	if [[ ! -d $1 ]]; then
		echoerr "Please provide a source directory."
		return 1
	fi
	
	if [[ ! -d $2 ]]; then
		echoerr "Please provide a target directory."
		return 2
	fi

	local files_count="$(command ls "$1" -1A | wc -l)"
	local counter=0

	for item in "$1"/*(N)
	do
		counter=$((counter+1))
		echoinfo "> Moving item $counter / $files_count: \z[magenta]°$(basename "${item%/}")\z[]°..."

		local tomove="${item%/}"

		if [[ -d $item ]]; then
			item="$item/"
		fi

		if ! sudo mv "$item" "$2"
		then
			echoerr "Failed to move a file!"
			return 1
		fi
	done
}

# Archive a file or directory into a .7z file
function make7z() {
	if [[ -z $1 ]]; then echoerr "Please provide an item to archive."; return 1; fi
	if [[ ! -e $1 ]]; then echoerr "Provided input item does not exist."; return 10; fi

	7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhc=on -mhe=on -spf2 -bso0 "$(basename "$1")-$(humandate).7z" "$1"
}

# Measure time a command takes to complete
function howlong() {
	local started=$(($(date +%s%N)))
	"$@"
	local finished=$(($(date +%s%N)))
	local elapsed=$(((finished - started) / 1000000))

	printf 'Command "'
	printf '%s' "${@[1]}"
	if [[ ! -z $2 ]]; then printf ' %s' "${@:2}"; fi
	printf '" completed in ' "$@"

	humanduration_ms $elapsed
	printf "\n"
}

# Create a directory and go into it
function mkcd() {
	if [[ ! -d $1 ]]; then
		mkdir -p "$1"
	fi

	cd "$1"
}

# Software: Trasher
function trasher() {
	sudo "$ADF_BIN_DIR/trasher" --create-trash-dir --trash-dir "$TRASHDIR" "$@"
}

function rm() {
	trasher rm --move-ext-filesystems "$@"
}

function unrm() {
	trasher unrm --move-ext-filesystems "$@"
}

# Install a Debian package
function debi() {
	sudo apt update
	sudo dpkg -i "$1"
	sudo apt install -f
}

# Install a Debian package from the web
function debir() {
	local debpath="/tmp/$(date +%s%N).deb"
	dl "$1" "$debpath"
	debi "$debpath"
	command rm "$debpath"
}

# Start a timer
function timer_start() {
	date +%s%N
}

function timer_elapsed() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	local started=$(($1))
	local now=$(($(date +%s%N)))
	local elapsed=$((now - started))

	printf '%s' $elapsed
}

function timer_show() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	local elapsed=$(timer_elapsed "$1")
	humanduration_ms $((elapsed / 1000000))
}

function timer_show_seconds() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	local elapsed=$(timer_elapsed "$1")
	humanduration $((elapsed / 1000000000))
}

function timer_end() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	timer_show "$1"
	unset "ADF_TIMERS[$1]"
}

function humanduration() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a duration in milliseconds."
		return 1
	fi

	local duration_s=$(($1))

	local D=$((duration_s/60/60/24))
	local H=$((duration_s/60/60%24))
	local M=$((duration_s/60%60))
	local S=$((duration_s%60))
	if [ $D != 0 ]; then printf "${D}d "; fi
	if [ $H != 0 ]; then printf "${H}h "; fi
	if [ $M != 0 ]; then printf "${M}m "; fi

	printf "${S}s"
}

function humanduration_ms() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a duration in milliseconds."
		return 1
	fi

	local duration=$(($1))

	local duration_s=$((duration / 1000))
	local D=$((duration_s/60/60/24))
	local H=$((duration_s/60/60%24))
	local M=$((duration_s/60%60))
	local S=$((duration_s%60))
	if [ $D != 0 ]; then printf "${D}d "; fi
	if [ $H != 0 ]; then printf "${H}h "; fi
	if [ $M != 0 ]; then printf "${M}m "; fi
	
	local duration_ms=$((duration % 1000))
	printf "${S}.%03ds" $duration_ms
}

function filesize() {
	if [[ ! -f $1 ]]; then
		echoerr "Path \z[magenta]°$1\z[]° is not a file!"
		return 1
	fi

	humansize "$(stat -c %s "$1")"
}

function humansize() {
	if [[ -z $1 ]]; then
		echoerr "Please provide an integer size."
		return 1
	fi

	if [[ $1 =~ [^0-9] ]]; then
		echoerr "Provided size (\z[yellow]°$1\z[]°) is invalid."
		return 2
	fi
	
	if (( $1 < 1024 )); then
		echo "${1}B"
	else
		numfmt --to=iec-i --suffix=B --format="%.2f" "$1"
	fi
}

# Display a progressbar
# Usage: <prefix> <current value> <maximum> <width in percents (0 for auto)> <suffix>
function progress_bar() {
	if [[ -z $1 ]]; then echoerr "Please provide a prefix."; return 1; fi
	if [[ -z $2 ]]; then echoerr "Please provide the current value."; return 1; fi
	if [[ -z $3 ]]; then echoerr "Please provide the maximum value."; return 1; fi
	if [[ -z $4 ]]; then echoerr "Please provide the progress bar's width."; return 1; fi

	local current=$(($2))
	local max=$(($3))

	if (( $4 )); then
		local width=$(($4 * COLUMNS / 100))
	else
		local width=$((COLUMNS / 3))
	fi
	
	# This formula is used to round the result to the nearest instead of doing a floor()
	local progress_bar=$((current * width / max))

	if (( $progress_bar )); then
		local filled=$(printf '█%.0s' {1..$progress_bar})
	else
		local filled=""
	fi

	if (( $progress_bar < $width )); then
		local remaining=$(printf '█%.0s' {1..$((width - progress_bar))})
	else
		local remaining=""
	fi

	local suffix="$5"

	if (( $CLEAR_COMPLETE_SUFFIX )) && [[ $current -eq $max ]]; then
		local suffix=""
	fi

	ADF_UPDATABLE_LINE=1 echoc "$1\z[white]°$filled\z[]°\z[gray]°$remaining\z[]°$suffix"

	if [[ $current -eq $max ]]; then
		echo ""
	fi
}

# Display a progressbar with full informations
# Usage: <prefix> <current value> <maximum> <width in percents (0 for auto)> <started> <suffix>
function progress_bar_detailed() {
	if [[ -z $1 ]]; then echoerr "Please provide a prefix."; return 1; fi
	if [[ -z $2 ]]; then echoerr "Please provide the current value."; return 2; fi
	if [[ -z $3 ]]; then echoerr "Please provide the maximum value."; return 3; fi
	if [[ -z $4 ]]; then echoerr "Please provide the progress bar's width."; return 4; fi
	if [[ -z $5 ]]; then echoerr "Please provide the start timestamp."; return 5; fi

	local progress=$(((100 * $2) / $3))
	local suffix=" $progress % ($2 / $3) | ETA: $(compute_eta $5 $2 $3) | Elapsed: $(timer_show_seconds $5)"
	progress_bar "$1" $2 $3 $4 "$suffix$6"
}

# Display a message while a progress bar is still in place
# Usage: same as 'echoc'
function progress_bar_print() {
	ADF_REPLACE_UPDATABLE_LINE=1 echoc "$@"
}

# Estimate remaining time
# Usage: <start date (from $(date +%s%N))> <current> <max>
function compute_eta() {
	local started=$(($1))
	local progress=$(($2))
	local maximum=$(($3))

	if ! (( $2 )); then
		printf "%s" "<computing...>"
		return
	elif [[ $2 -eq $3 ]]; then
		printf "%s" "<complete>"
		return
	fi

	local now=$(date +%s%N)
	local elapsed=$((now - started))
	local remaining=$((maximum - progress))

	local eta_nanos=$((elapsed * remaining / progress))
	local eta_s=$((eta_nanos / 1000 / 1000 / 1000))

	humanduration $eta_s
}