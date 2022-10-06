
# Run a command in background
function runback() {
	(nohup "$@" > "${NOHUP_FILE:-/dev/null}" 2>&1 &)
}

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
	trap 'echowarn "Ctrl+C is not allowed here."' SIGINT
	read -s 'answer?'
	trap - SIGINT

	if [[ -n $answer && $answer != "y" && $answer != "Y" ]]; then
		return 1
	fi
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

# Obfuscate a content
function adf_obf_encode() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a content to encode."
		return 1
	fi

	local content="$1"

	for i in {1..$ADF_OBF_ROUNDS}; do
		local content=$(base64 --wrap=0 <<< "|$content|")
	done

	printf '%s' "$content"
}

# De-obfuscate a content
function adf_obf_decode() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a content to decode."
		return 1
	fi

	local content="$1"

	for i in {1..$ADF_OBF_ROUNDS}; do
		local content=$(base64 -d --wrap=0 <<< "$content")
		local content=${content:1:${#content}-2}
	done

	printf '%s' "$content"
}
