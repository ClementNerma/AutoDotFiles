
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
	local cancelled=0

	trap 'echowarn "Ctrl+C is not allowed here." && cancelled=1' SIGINT
	read -ks 'answer?'
	trap - SIGINT

	if [[ -z $answer ]] || (( $cancelled )); then
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

	local renpath="$itempath-$(humandate)"

	mv "$itempath" "$renpath"
	export LAST_MVBAK_PATH="$renpath"
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
