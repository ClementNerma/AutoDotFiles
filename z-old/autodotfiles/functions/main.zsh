
# A simple 'rm' with progress
function rmprogress() {
	if [[ -z $1 ]]; then
		echoerr "Missing operand for 'rmprogress'"
		return 1
	fi
	
	rm -rv "$1" | pv -l -s $( du -a "$1" | wc -l ) > /dev/null
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