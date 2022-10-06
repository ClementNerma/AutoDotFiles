
function echocolored() {
    printf "$1"
    shift
    while IFS= read -r line ; do echo $line; done <<< "$@"
    printf "\e[0m"
}

function echoerr() {
    echocolored "\e[91mERROR: " "$@"
}

function echosuccess() {
    echocolored "\e[92m" "$@"
}

function echoinfo() {
    echocolored "\e[93m" "$@"
}

function echopath() {
	echocolored "\e[95m" "$@"
}

# Arguments: "<url>" "<download location>"
function dl() {
    local url="$1"
    local outpath="$2"
    shift

    if [[ ! -z "$outpath" ]]; then
        shift
        wget -q --show-progress -O "$outpath" "$url" "$@"
    else
        wget -q --show-progress "$url" "$@"
    fi
}

function sudodl() {
    local url="$1"
    local outpath="$2"
    shift

    if [[ ! -z "$outpath" ]]; then
        shift
        sudo wget -q --show-progress -O "$outpath" "$url" "$@"
    else
        sudo wget -q --show-progress "$url" "$@"
    fi
}

# Download files whose URL will be provided through STDIN
# Arguments: "<download location>"
function dli() { wget -qi - --show-progress -O "$1" }
function sudodli() { sudo wget -qi - --show-progress -O "$1" }

# Download a file from the latest of a GitHub repository
# Arguments: "<repo author>/<reponame>" "<file grep pattern>" "<download location>"
function dlghrelease() {
    curl -s "https://api.github.com/repos/$1/releases/latest" \
        | grep "browser_download_url.*$2" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | dli "$3"
}

# Download the latest version of the source code from a GitHub repository
# Arguments: "<repo author>/<repo name>" "<download location>"
function ghdl() {
	local repo_url="$1"

	if [[ $repo_url = "https://"* ]]; then
		if [[ $repo_url != "https://github.com/"* ]]; then
			echoerr "Invalid GitHub repository URL: \e[93m$repo_url"
			return 1
		fi
	elif [[ $repo_url = "http://"* ]]; then
		echoerr "Cannot get from HTTP link with GitHub"
		return 1
	else
		repo_url="https://github.com/$repo_url"
	fi

	local repoauthor=$(echo "$repo_url" | cut -d'/' -f4)
	local reponame=$(echo "$repo_url" | cut -d'/' -f5)
	local outdir="$reponame"

	if [[ ! -z "$2" ]]; then
		outdir="$2"
	fi
	
	reponame="${reponame%.git}"

	echosuccess "Cloning from repository: \e[93m$repoauthor/$reponame\e[92m..."

	if [[ -d "$outdir" ]]; then
		echoerr "> Directory \e[95m$outdir\e[91m already exists!"
		return 1
	fi

	echo -e "\e[34m> Fetching default branch..."
	local branch=$(curl -s "https://api.github.com/repos/$repoauthor/$reponame" | jq -r ".default_branch")

	if [[ $branch == "null" ]]; then
		echoerr "> Failed to determine default branch!"
		return 1
	fi

	local filename="$reponame-$(date +%s).zip"
	echo -e "\e[34m> Fetching archive for branch \e[93m$branch\e[34m to \e[95m$filename\e[34m...\e[0m"
	
	local zipurl="https://codeload.github.com/$repoauthor/$reponame/zip/$branch"

	if ! dl "$zipurl" "$filename"; then
		echoerr "> Failed to fetch archive from URL: \e[93m$zipurl\e[91m!"
		return 1
	fi

	echo -e "\e[34m> Extracting archive to directory \e[93m$outdir\e[34m...\e[0m"
	unzip -q "$filename"
	command rm "$filename"
	mv "$reponame-$branch" "$outdir"

	if [[ -z "$2" ]]; then
		cd "$outdir"
	fi

	echosuccess "Done!"
}

# Move an item called <something> to <something>.bak-<timestamp>
function mvbak() {
	if [[ ! -f "$1" && ! -d "$1" ]]; then
		echoerr "Provided path was not found: \e[92m$1"
		return 1
	fi

	local renpath="$1.bak-$(date +%s)"

	mv "$1" "$renpath"
	export LAST_MVBAK_PATH="$renpath"
}