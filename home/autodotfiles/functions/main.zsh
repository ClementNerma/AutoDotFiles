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

	7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhc=on -mhe=on -spf2 -bso0 "${2:-$PWD}/$(basename "$1")-$(humandate).7z" "$1"
}

# Merge multiple ZIPs together
function merge_zips() {
	(( $# < 3 )) && { echoerr "Please provide at least two ZIPs as well as an output file."; return 1 }

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
	local debpath=$(mktemp)
	dl "$1" "$debpath"
	debi "$debpath"
	command rm "$debpath"
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
	[[ -z $1 ]] && { echoerr "Please provide a timer value."; return 1 }

	local started=$(($1))
	local now=$(now)
	local elapsed=$((now - started))

	humanduration $((elapsed / 1000000)) --ms
}

function humanduration() {
	local duration=$(($1))
	local duration_s=$((duration / 1000))

	local D=$((duration_s / 60 / 60 / 24))
	local H=$((duration_s / 60 / 60 % 24))
	local M=$((duration_s / 60 % 60))
	local S=$((duration_s % 60))
	
	if [ $D != 0 ]; then printf "${D}d "; fi
	if [ $H != 0 ]; then printf "${H}h "; fi
	if [ $M != 0 ]; then printf "${M}m "; fi

	local duration_ms=$((duration % 1000))
	printf "${S}.%03ds" $duration_ms

}

# Aliases to exit after open commands
function opene() {
	open "$@" && exit
}


function z() {
    [[ -z $1 ]] && { echoerr "Please provide a query."; return 1 }

    local result=$(jumpy query "$1" --checked --after "$PWD")

    if [[ -n $result ]]; then
        export __JUMPY_DONT_REGISTER=1
        cd "$result"
        export __JUMPY_DONT_REGISTER=0
    fi
}
