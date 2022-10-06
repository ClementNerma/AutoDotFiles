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
	
	if ! files=$(fd --threads=1 --hidden --one-file-system --type 'file' --search-path "$1" --absolute-path); then
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
	local started=$(timer_start)

	while IFS= read -r file; do
		local i=$((i+1))
		local relative="$(realpath --relative-to="$1" "$file")"
		local dest="$target/$relative"

		PB_EVERY=10 progress_bar_detailed "Copying: " $i $count 0 $started

		mkdir -p "$(dirname "$dest")"
		cp "$file" "$dest"
	done <<< "$files"

	echosuccess "\nDone in \z[magenta]°$target\z[]°"
}

# Backup the current project
function bakthis() {
	bakproj "$PWD" "$PWD-$(humandate)"
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

# Archive a file or directory into a .7z file
function make7z() {
	if [[ -z $1 ]]; then echoerr "Please provide an item to archive."; return 1; fi
	if [[ ! -e $1 ]]; then echoerr "Provided input item does not exist."; return 10; fi

	7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhc=on -mhe=on -spf2 -bso0 "$(basename "$1")-$(humandate).7z" "$1"
}

# Measure time a command takes to complete
function howlong() {
	local started=$(now)
	"$@"
	local finished=$(now)
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
	local debpath="/tmp/$(now).deb"
	dl "$1" "$debpath"
	debi "$debpath"
	command rm "$debpath"
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
# Set PB_EVERY to X => display the progress bar every X values (= if current value is dividable by X), and for the minimum and maximum values
function progress_bar() {
	if [[ -z $1 ]]; then echoerr "Please provide a prefix."; return 1; fi
	if [[ -z $2 ]]; then echoerr "Please provide the current value."; return 1; fi
	if [[ -z $3 ]]; then echoerr "Please provide the maximum value."; return 1; fi
	if [[ -z $4 ]]; then echoerr "Please provide the progress bar's width."; return 1; fi

	local current=$(($2))
	local max=$(($3))

	if (( PB_EVERY )) && (( current > 0 )) && (( current < max )) && (( current % PB_EVERY )); then
		return
	fi

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

	if ! (( $NO_CLEAR_ON_COMPLETE )) && [[ $current -eq $max ]]; then
		echof -n "\r" ""
	else
		echof -n "\r$1$ADF_FORMAT_WHITE$filled$ADF_FORMAT_GRAY$remaining$ADF_FORMAT_RESET$suffix" "$1$filled$remaining$suffix"
	fi
}

# Display a progressbar with full informations
# Usage: <prefix> <current value> <maximum> <width in percents (0 for auto)> <started> <suffix>
# Set PB_EVERY to X => display the progress bar every X values (= if current value is dividable by X), and for the minimum and maximum values
function progress_bar_detailed() {
	if [[ -z $1 ]]; then echoerr "Please provide a prefix."; return 1; fi
	if [[ -z $2 ]]; then echoerr "Please provide the current value."; return 2; fi
	if [[ -z $3 ]]; then echoerr "Please provide the maximum value."; return 3; fi
	if [[ -z $4 ]]; then echoerr "Please provide the progress bar's width."; return 4; fi
	if [[ -z $5 ]]; then echoerr "Please provide the start timestamp."; return 5; fi

	if (( PB_EVERY )) && (( $2 > 0 )) && (( $2 < $3 )) && (( $2 % PB_EVERY )); then
		return
	fi

	local progress=$(((100 * $2) / $3))
	local suffix=" $progress % ($2 / $3) | ETA: $(compute_eta $2 $3 $5) | Elapsed: $(timer_show_seconds $5)"

	if [[ ! -z $6 ]]; then
		suffix+=$(echoc "$6")
	fi

	progress_bar "$1" $2 $3 $4 "$suffix"
}

# Display a message while a progress bar is still in place
# Usage: same as 'echoc'
function progress_bar_print() {
	ADF_REPLACE_UPDATABLE_LINE=1 echoc "$@"
}

# Estimate remaining time
# Usage: <current> <max> <start date (from $(now))> 
function compute_eta() {
	local current=$(($1))
	local maximum=$(($2))
	local started=$(($3))

	if ! (( $current )); then
		printf "%s" "<computing...>"
		return
	elif [[ $current -eq $maximum ]]; then
		printf "%s" "<complete>"
		return
	fi

	local now=$(now)
	local elapsed=$((now - started))
	local remaining=$((maximum - current))

	local eta_nanos=$((elapsed * remaining / current))
	local eta_s=$((eta_nanos / 1000 / 1000 / 1000))

	humanduration $eta_s
}