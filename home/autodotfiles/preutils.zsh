
# Arguments: "<url>" "<download location>"
function dl() {
	[[ -z $1 ]] && { echoerr "Please provide an URL to download from."; return 1 }
	[[ -z $2 ]] && { echoerr "Please provide a download location."; return 2 }

	curl -L "$1" -o "$2"
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

	[[ ! -f $itempath && ! -d $itempath ]] && { echoerr "Provided path was not found: \z[green]°$itempath\z[]°"; return 1 }

	local renpath="$itempath-$(humandate)"

	mv "$itempath" "$renpath"
	export LAST_MVBAK_PATH="$renpath"
}

# Move an item if it exists
function mvoldbak() {
	if [[ ! -d $1 ]]; then return; fi

	echowarn "\!/ A previous version of \z[green]°$1\z[]° was found."

	mvbak "$1" || return 10

	echowarn "==> Moved it to \z[magenta]°$LAST_MVBAK_PATH\z[]°."
	echowarn ""
}

# Obfuscate a content
function adf_obf_encode() {
	[[ -z $1 ]] && { echoerr "Please provide a content to encode."; return 1 }

	local content="$1"

	for i in {1..$ADF_OBF_ROUNDS}; do
		content=$(base64 --wrap=0 <<< "|$content|")
	done

	printf '%s' "$content"
}

# De-obfuscate a content
function adf_obf_decode() {
	[[ -z $1 ]] && { echoerr "Please provide a content to decode."; return 1 }

	local content="$1"

	for i in {1..$ADF_OBF_ROUNDS}; do
		content=$(base64 -d --wrap=0 <<< "$content")
		content=${content:1:${#content}-2}
	done

	printf '%s' "$content"
}
