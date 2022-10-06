
# Arguments: "<url>" "<download location>"
function dl() {
	curl -L "$1" -o "$2"
}

# Ask for an input with a simple prompt
function prompt() {
	local input=""
	
	if [[ $1 = "-s" ]]; then
		read -s "input?$2"
	else
		read "input?$1"
	fi

	echo "$input"
}

# Ask for confirmation
function confirm() {
	read 'answer?'
	
	if [[ ! -z $answer && $answer != "y" && $answer != "Y" ]]; then
		return 1
	fi
}

# Passive confirmation
function passive_confirm() {
	export __adf__passive_confirm_aborted=0

	local started=$(timer_start)
	local elapsed=0

	while (( $elapsed < 5 )); do
		trap 'echo "Use Ctrl+D to abort." && export __adf__passive_confirm_aborted=1' SIGINT
		read -sk -t 5 __adf_passive_confirm_answer
		trap SIGINT

		if [[ ! -z $__adf__passive_confirm_answer ]] || (( $__adf__passive_confirm_aborted )) ; then
			break
		fi

		local elapsed=$(timer_elapsed_seconds "$started")
	done

    if [[ -z $__adf_passive_confirm_answer || $__adf_passive_confirm_answer != $'\n' ]] && (( $__adf__passive_confirm_aborted )); then
        return 1
    fi
}

# Faster replacement for "date +%s%N"
function now() {
	printf ${${EPOCHREALTIME//.}:0:19}
}

function humandate() {
	date '+%Y_%m_%d-%Hh_%Mm_%Ss'
}

# Move an item called <something> to <something>.bak-<timestamp>
function mvbak() {
	local itempath="${1%/}"

	if [[ ! -f $itempath && ! -d $itempath ]]; then
		echoerr "Provided path was not found: \z[green]°$itempath\z[]°"
		return 1
	fi

	local renpath="$itempath.bak-$(humandate)"

	mv "$itempath" "$renpath"
	export LAST_MVBAK_PATH="$renpath"
}

# Compute the 32-bit checksum of a flat directory (= only files)
# Checksum will only be the same if the directory's filenames and content are equal
# Files order and timestamps are not taken into consideration
function cksumdir() {
	if [[ -f $1 && ! -z $ADF_ALLOW_CKSUM_FILE ]]; then
		command cat "$1" | cksum
		return
	fi

	if [[ ! -d $1 ]]; then
		echoerr "Input directory not found at path: \z[yellow]°$1\z[]°"
		return 1
	fi

	local checksums=""

	for item in "$1/"*; do
		local checksum=""
		local filenamesum=$(basename "$item" | cksum)

		if checksum=$(ADF_ALLOW_CKSUM_FILE=1 cksumdir "$item"); then
			checksums+="$filenamesum$checksum"
		else
			return 2
		fi
	done

	cksumstr "$checksums"
}

# Display the checksum of a string
function cksumstr() {
	echo "$1" | cksum | cut -d ' ' -f 1
}

# Display the hash of a string
function hashstr() {
	echo "$1" | sha1sum | cut -d ' ' -f 1
}

# Check if a command exists
function commandexists() {
	command -v "$1" > /dev/null 2>&1
}
