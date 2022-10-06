#
# This file defines global functions and aliases
#

# Backup the current project
function bakthis() {
	local target="../$(basename "$PWD")-$(humandate)"
	mkdir "$target"
	fd --hidden --type 'directory' --search-path "." | xargs -I {} mkdir "$target/{}"
	fd --hidden --type 'file' --search-path "." | xargs -I {} cp "{}" "$target/{}"
	echosuccess "Done!"
}

# Rename a Git branch
function gitrename() {
    local old_branch=$(git rev-parse --abbrev-ref HEAD)
	echoinfo "Renaming branch '$old_branch' to '$1'..."
	git branch -m "$1"
	git push origin -u "$1"
	git push origin --delete "$old_branch"
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
	local started=$(timer_start)
	"$@"
	local elapsed=$(timer_elapsed "$started")
	echo "Command '$1' completed in $elapsed"
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

# Push the current branch to remote even if it does not exist yet
function gpb() {
	git push --set-upstream origin "$(git rev-parse --abbrev-ref HEAD)"
}

# Optimize the current Git repository (WARNING: deletes unused content)
function gop() {
	git reflog expire --expire=now --all &&
	git gc --prune=now &&
	git repack -a -d --depth=250 --window=250
}

# Start a timer
function timer_start() {
	now
}

function timer_elapsed() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	local started=$(($1))
	local now=$(now)
	local elapsed=$((now - started))

	humanduration $((elapsed / 1000000)) --ms
}

function humanduration() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a duration in milliseconds."
		return 1
	fi

	local duration=$(($1))
	local duration_s=$duration
	local ms_precision=0

	if [[ ! -z $2 ]]; then
		if [[ $2 != "--ms" ]]; then
			echoerr "Second argument must be '\z[yellow]°--ms\z[]°' or nothing."
			return 2
		fi

		local ms_precision=1
		local duration_s=$((duration / 1000))
	fi

	local D=$((duration_s / 60 / 60 / 24))
	local H=$((duration_s / 60 / 60 % 24))
	local M=$((duration_s / 60 % 60))
	local S=$((duration_s % 60))
	if [ $D != 0 ]; then printf "${D}d "; fi
	if [ $H != 0 ]; then printf "${H}h "; fi
	if [ $M != 0 ]; then printf "${M}m "; fi

	if (( $ms_precision )); then
		local duration_ms=$((duration % 1000))
		printf "${S}.%03ds" $duration_ms
	else
		printf "${S}s"
	fi

}
