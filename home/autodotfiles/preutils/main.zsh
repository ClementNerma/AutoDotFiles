
# Arguments: "<url>" "<download location>"
function dl() {
	if [[ -z $1 ]]; then
		echoerr "Please provide an URL to download from."
		return 1
	fi

	if [[ -z $2 ]]; then
		echoerr "Please provide a download location."
		return 2
	fi

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
	read -s 'answer?'
	
	if [[ ! -z $answer && $answer != "y" && $answer != "Y" ]]; then
		return 1
	fi
}

# Passive confirmation
# Set "$PC_TIMEOUT" to set a timeout
function passive_confirm() {
	export ___pc_aborted=0
	export ___pc_answer=""

	while [[ $___pc_answer != $'\n' ]] && ! (( $___pc_aborted )); do
		trap 'echowarn "Use Ctrl+D to abort." && export ___pc_aborted=1' SIGINT

		if ! (( $PC_TIMEOUT )); then
			read -sk ___pc_answer
		else
			read -sk -t $PC_TIMEOUT ___pc_answer
		fi

		trap SIGINT

		if [[ $___pc_answer = "p" ]]; then
			while true; do
				export ___pc_choice=""

				trap 'echo "Use A to abort."' SIGINT
				echoinfo "Sleeping, press C to continue or A to abort."
				read -sk ___pc_choice
				trap SIGINT

				if [[ $___pc_choice = "c" ]]; then
					return
				fi

				if [[ $___pc_choice = "a" ]]; then
					return 1
				fi

				echowarn "Invalid response (C or A expected)."
			done
		fi

		if (( $___pc_aborted )); then
			return 1
		fi
		
		if [[ $___pc_answer = $'\n' ]]; then
			return
		fi

		if (( $PC_TIMEOUT )) && [[ -z $___pc_answer ]]; then
			return
		fi

		echowarn "Unrecognized key (\z[blue]°<Enter>\z[]° to continue, \z[blue]°<Ctrl+C>\z[]° then \z[blue]°<Ctrl+D>\z[]° to abort, \z[blue]°<P>\z[]° to pause)"
	done
}

# Faster replacement for "date +%s%N"
function now() {
	printf ${${EPOCHREALTIME//.}:0:19}
}

# Required for CRON jobs
if [[ -z $EPOCHREALTIME ]]; then
	zmodload zsh/datetime 
fi

function humandate() {
	date '+%Y_%m_%d-%Hh_%Mm_%Ss'
}

function printabledate() {
	date +"%d/%m/%Y %T"
}

# Move an item called <something> to <something>.bak-<timestamp>
function mvbak() {
	local itempath="${1%/}"

	if [[ ! -f $itempath && ! -d $itempath ]]; then
		echoerr "Provided path was not found: \z[green]°$itempath\z[]°"
		return 1
	fi

	local renpath="$itempath-$(humandate)"

	mv "$itempath" "$renpath"
	export LAST_MVBAK_PATH="$renpath"
}

# Compute the 32-bit checksum of a flat directory (= only files)
# Checksum will only be the same if the directory's filenames and content are equal
# Files order and timestamps are not taken into consideration
function cksumdir() {
	if [[ -f $1 && ! -z $ADF_ALLOW_CKSUM_FILE ]]; then
		cksumfile "$1"
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

# Display the checksum of a file
function cksumfile() {
	cksum < "$1" | cut -d ' ' -f 1
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

# Pad start with spaces
function padspaces() {
	local len=$(echo -n "$1" | wc -c)
	local rem=$(($2 - len))

	if (( $rem > 0 )); then
		printf ' %.0s' {1..$rem}
	fi

	printf '%s' "$1"
}

# Pad end with spaces
function padendspaces() {
	local len=$(echo -n "$1" | wc -c)
	local rem=$(($2 - len))

	printf '%s' "$1"

	if (( $rem > 0 )); then
		printf ' %.0s' {1..$rem}
	fi
}