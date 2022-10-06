# Download a file from the latest of a GitHub repository
# Arguments: "<repo author>/<reponame>" "<file grep pattern>" "<download location>"
function dlghrelease() {
	if ! api_response=$(curl -s -S "https://api.github.com/repos/$1/releases/latest"); then
		echoerr "Failed to fetch GitHub API (listing releases)."
		echoerr "API response: \z[blue]°$(echo -E "${api_response:0:$((COLUMNS - 25))}" | tr '\n' ' ')\z[]°"
		return 10
	fi

	if ! release_urls=($(echo -E "$api_response" | jq -r '.assets[].browser_download_url')); then
		echoerr "Failed to parse JSON response: $release_urls"
		return 11
	fi

	if [[ -z $release_urls ]]; then
		echoerr "Failed to get release URLs from GitHub API."
		echoerr "API reponse: \z[cyan]°$(echo -E "${api_response:0:$((COLUMNS - 25))}" | tr '\n' ' ')\z[]°"
		return 12
	fi

	local found=""

	for url in $release_urls; do
		if [[ $url =~ $2 ]]; then
			if [[ ! -z $found ]]; then
				echoerr "Found multiple URLs matching the provided pattern:"
				echoerr "* \z[yellow]°$found\z[]°"
				echoerr "* \z[yellow]°$url\z[]°"
				return 20
			fi

			local found="$url"
		fi
	done

	if [[ -z $found ]]; then
		echoerr "Failed to find an URL matching in repository \z[yellow]°$1\z[]° (pattern \z[cyan]°$2\z[]°)"
		return 12
	fi

    dl "$found" "$3"
}

# Download a .tar.gz from GitHub releases and extract a single file to the binaries directory
# Usage: dlbin <github repo name> <asset pattern for AMD64> <asset pattern for ARM64> <file to extract> <binary name>
function dlghbin() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a GitHub repository name."
		return 1
	fi

	if [[ -z $2 ]]; then
		echoerr "Please provide an asset pattern."
		return 2
	fi

	if [[ -z $3 ]]; then
		echoerr "Please provide an extraction pattern for AMD64."
		return 3
	fi

	if [[ -z $4 ]]; then
		echoerr "Please provide an extraction pattern for ARM64."
		return 4
	fi

	if [[ -z $5 ]]; then
		echoerr "Please provide a binary name."
		return 4
	fi

	if [[ ! $2 = *.zip ]] && [[ ! $2 = *.tar.gz ]] && [[ ! $2 = *.tgz ]]; then
		echoerr "Please provide an explicit file extension in the asset pattern."
		return 5
	fi

	local dldir="$TEMPDIR"

	if [[ ! -z $INSTALLER_TMPDIR ]]; then
		local dldir="$INSTALLER_TMPDIR"
	fi

	local file="$dldir/dlbin-$5-$(humandate)"
	local exdir="$dldir/dlbin-$5-$(humandate)-extract"

	local asset_pattern="$2"

	if [[ $(dpkg --print-architecture) = "arm64" ]]; then
		local asset_pattern="$3"
	fi

	echoinfo "> (1/4) Download release from GitHub..."

	if ! dlghrelease "$1" "$2" "$file"; then
		return 10
	fi

	echoinfo "> (2/4) Extracting archive..."

	if [[ $2 = *.zip ]]; then
		# Cannot test for exit code as 'unzip' will return a non-zero code if the value is valid but with extra bytes
		unzip "$file" -d "$exdir"
	elif [[ $2 = *.tar.gz ]] || [[ $2 = *.tgz ]]; then
		mkdir "$exdir"

		if ! tar zxf "$file" -C "$exdir"; then
			return 12
		fi
	else
		echoerr "Internal error: unhandled file extension in pattern \z[yellow]°$2\z[]°"
		return 13
	fi

	echoinfo "> (3/4) Moving final binary..."

	if ! mv "$exdir/"${~4} "$ADF_BIN_DIR/$5"; then
		return 14
	fi

	chmod +x "$ADF_BIN_DIR/$5"

	echoinfo "> (4/4) Cleaning up..."
	
	command rm "$file"
	command rm -rf "$exdir"
}

# Download the latest version of the source code from a GitHub repository
# Arguments: "<repo author>/<repo name>" "<download location>"
function ghdl() {
	local repo_url="$1"

	if [[ $repo_url = "https://"* ]]; then
		if [[ $repo_url != "https://github.com/"* ]]; then
			echoerr "Invalid GitHub repository URL: \z[yellow]°$repo_url\z[]°"
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

	if [[ ! -z $2 ]]; then
		outdir="$2"
	fi
	
	reponame="${reponame%.git}"

	echosuccess "Cloning from repository: \z[yellow]°$repoauthor/$reponame\z[]°..."

	if [[ -d $outdir ]]; then
		echoerr "> Directory \z[magenta]°$outdir\z[]° already exists!"
		return 1
	fi

	echoinfo "> Fetching default branch..."
	local branch=$(curl -s -S "https://api.github.com/repos/$repoauthor/$reponame" | jq -r ".default_branch")

	if [[ $branch == "null" ]]; then
		echoerr "> Failed to determine default branch!"
		return 1
	fi

	local filename="$reponame-$(humandate).zip"
	echoinfo "> Fetching archive for branch \z[yellow]°$branch\z[]° to \z[magenta]°$filename\z[]°..."
	
	local zipurl="https://codeload.github.com/$repoauthor/$reponame/zip/$branch"

	if ! dl "$zipurl" "$filename"; then
		echoerr "> Failed to fetch archive from URL: \z[yellow]°$zipurl\z[]°!"
		return 1
	fi

	echoinfo "> Extracting archive to directory \z[yellow]°$outdir\z[]°..."
	unzip -q "$filename"
	command rm "$filename"
	mv "$reponame-$branch" "$outdir"

	if [[ -z $2 ]]; then
		cd "$outdir"
	fi

	echosuccess "Done!"
}