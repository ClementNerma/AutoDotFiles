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

	if [[ -n $3 ]]; then
		local target="$target.$3"
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

		echo -n "\rCopying files: $i / $count ($(( 100 * $i / $count )) %)..."

		mkdir -p "$(dirname "$dest")"
		cp "$file" "$dest"
	done <<< "$files"

	echo ""

	echosuccess "Done in \z[magenta]°$target\z[]°"
	export LAST_BAKPROJ_DIR="$target"
}

# Backup the current project
function bakthis() {
	bakproj "$PWD" "$PWD-$(humandate)" "$1"
}

# Make an archive out of a project directory
function bakproj7z() {
	if [[ -z $1 ]]; then echoerr "Please provide a source directory."; return 1; fi
	if [[ -n $2 ]] && [[ ! -d $2 ]]; then echoerr "Provided target directory does not exist."; return 2; fi

	local target="$TEMPDIR/$(basename "$1")"

	ADF_SILENT=1 bakproj "$1" "$target"

	make7z "$target" "${2:-$PWD}"

	echosuccess "Sucessfully backed up in \z[magenta]°$__LAST_MADE_7Z\z[]°"

	rm "$target"
}

# Make an archive out of the current project directory
function bakthis7z() {
	bakproj7z "$PWD" "$(realpath "..")"
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
	if [[ -n $2 ]] && [[ ! -d $2 ]]; then echoerr "Provided output directory does not exist."; return 11; fi

	local dest="${2:-$PWD}/$(basename "$1")-$(humandate).7z"
	local cwd=$PWD

	cd "$(dirname "$1")"

	7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhc=on -mhe=on -spf2 -bso0 "$dest" "$(basename "$1")"

	cd "$cwd"

	export __LAST_MADE_7Z="$dest"
}

# Merge multiple ZIPs together
function merge_zips() {
	if (( $# < 3 )); then
		echoerr "Please provide at least two ZIPs as well as an output file."
		return 1
	fi

	local outfile="${@: -1}"

	if [[ $outfile = "-" ]]; then
		local outfile="$(dirname "$1").zip"
	fi

	if [[ -f $outfile ]] || [[ -d $outfile ]]; then
		echoerr "Output file already exists!"
		return 10
	fi

	local tmpdir=".zipmerge-$(date +%s%N)"
	mkdir "$tmpdir"

	for file in "${@:1:${#}-1}"; do
		unzip -q "$file" -d "$tmpdir/${file/.zip/}"
	done

	# NOTE: No compression
	7z a -mx=0 "$outfile" "$tmpdir"

	command rm -rf "$tmpdir"

	echosuccess "Done!"
}

# Measure time a command takes to complete
function howlong() {
	local started=$(now)
	"$@"
	local finished=$(now)
	local elapsed=$(((finished - started) / 1000000))

	printf 'Command "'
	printf '%s' "${@[1]}"
	if [[ -n $2 ]]; then printf ' %s' "${@:2}"; fi
	printf '" completed in ' "$@"

	humanduration_ms $elapsed
	printf "\n"
}

# Create a directory and go into it
function mkcd() {
	local name="$@"

	if [[ ! -d $name ]]; then
		mkdir -p "$name"
	fi

	cd "$name"
}

# Get most recent item in current directory
function latest() {
	command ls ${1:-$PWD} -Art | tail -n 1
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

# Get character bytecode
function charbytecode() {
	local input="$1"

	for i in {1..${#input}}; do
		printf '%x\n' "'${input[i]}'"
	done
}

# Run a command each time a Cargo project is modified
# NOTE: Requires 'cargo-watch' to be installed (otherwise: 'cargo install cargo-watch')
function cw() {
	local args="$@"
	cargo watch -x "run -- $args"
}

# Run a command each time a Cargo project is modified, in release mode
# NOTE: Requires 'cargo-watch' to be installed (otherwise: 'cargo install cargo-watch')
function cwr() {
	local args="$@"
	cargo watch -x "run --release -- $args"
}
