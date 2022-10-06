# Download a file from the latest of a GitHub repository
# Arguments: "<repo author>/<reponame>" "<file grep pattern>" "<download location>"
function dlghrelease() {
	if ! api_response=$(curl -s -S "https://api.github.com/repos/$1/releases/latest"); then
		echoerr "Failed to fetch GitHub API (listing releases)."
		echoerr "API response: \z[blue]°$(echo -E "${api_response:0:$((COLUMNS - 25))}" | tr '\n' ' ')\z[]°"
		return 10
	fi

	release_urls=($(echo -E "$api_response" | jq -r '.assets[].browser_download_url')) || { echoerr "Failed to parse JSON response: $release_urls"; return 11 }

	if [[ -z $release_urls ]]; then
		echoerr "Failed to get release URLs from GitHub API."
		echoerr "API reponse: \z[cyan]°$(echo -E "${api_response:0:$((COLUMNS - 25))}" | tr '\n' ' ')\z[]°"
		return 12
	fi

	local found=""

	for url in $release_urls; do
		local filename=${url##*/}

		if [[ $filename =~ ($2) ]]; then
			if [[ ${match[1]} != $filename ]]; then
				echowarn "Found incomplete match: \z[cyan]°$filename\z[]°"
				continue
			fi

			if [[ -n $found ]]; then
				echoerr "Found multiple filenames matching the provided pattern:"
				echoerr "* \z[yellow]°${found##*/}\z[]°"
				echoerr "* \z[yellow]°$filename\z[]°"
				return 20
			fi

			local found="$url"
		fi
	done

	[[ -z $found ]] && { echoerr "Failed to find an URL matching in repository \z[yellow]°$1\z[]° (pattern \z[cyan]°$2\z[]°)"; return 12 }

    dl "$found" "$3"
}

# Download a .tar.gz from GitHub releases and extract a single file to the binaries directory
# Usage: dlbin <github repo name> <asset pattern for AMD64> <file to extract> <binary name>
function dlghbin() {
	[[ -z $1 ]] && { echoerr "Please provide a GitHub repository name."; return 1 }
	[[ -z $2 ]] && { echoerr "Please provide an asset pattern."; return 1 }
	[[ -z $3 ]] && { echoerr "Please provide an extraction pattern for AMD64."; return 1 }
	[[ $3 != "-" ]] && [[ -z $4 ]] && { echoerr "Please provide a target filename."; return 1 }

	local dldir="${INSTALLER_TMPDIR:-$(mktemp -d)}"
	local file="$dldir/dlbin-$4-$(humandate)"
	
	echoinfo "> (1/4) Downloading release from GitHub..."

	dlghrelease "$1" "$2" "$file" || return 10

	echoinfo "> (2/4) Extracting archive..."

	local exdir="$dldir/dlbin-$4-$(humandate)-extract"
	mkdir "$exdir"

	if [[ $2 = *.zip ]]; then
		# Cannot test for exit code as 'unzip' will return a non-zero code if the value is valid but with extra bytes
		unzip "$file" -d "$exdir" || return 12
	elif [[ $2 = *.tar.gz ]] || [[ $2 = *.tgz ]]; then
		tar zxf "$file" -C "$exdir" || return 12
	elif [[ $3 != "-" ]]; then
		echoerr "Unknown archive format provided: \z[yellow]°$2\z[]°"
		return 10
	fi

	echoinfo "> (3/4) Moving final binary..."

	if [[ $3 = "-" ]]; then
		local to_move="$file"
		local target_name=${4:-$(basename "$2")}
	else
		local expanded=("$exdir/"${~3})
		local to_move=${expanded[1]}
		local target_name=$4
	fi

	mv "$to_move" "$ADF_BIN_DIR/$target_name" || return 14
	chmod +x "$ADF_BIN_DIR/$target_name"

	echoinfo "> (4/4) Cleaning up..."
	
	[[ -f $file ]] && command rm "$file"
	command rm -rf "$exdir"
}

# Download the latest version of the source code from a GitHub repository
# Arguments: "<repo author>/<repo name>" "<download location>"
function ghdl() {
	local repo_url="$1"

	if [[ $repo_url = "https://"* ]]; then
		if ! [[ $repo_url != "https://github.com/"* ]]; then
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

	if [[ -n $2 ]]; then
		outdir="$2"
	fi
	
	reponame="${reponame%.git}"

	echosuccess "Cloning from repository: \z[yellow]°$repoauthor/$reponame\z[]°..."

	[[ -d $outdir ]] && { echoerr "> Directory \z[magenta]°$outdir\z[]° already exists!"; return 1 }

	echoinfo "> Fetching default branch..."
	local branch=$(curl -s -S "https://api.github.com/repos/$repoauthor/$reponame" | jq -r ".default_branch")

	[[ $branch != "null" ]] || { echoerr "> Failed to determine default branch!"; return 1 }

	local filename="$reponame-$(humandate).zip"
	echoinfo "> Fetching archive for branch \z[yellow]°$branch\z[]° to \z[magenta]°$filename\z[]°..."
	
	local zipurl="https://codeload.github.com/$repoauthor/$reponame/zip/$branch"

	dl "$zipurl" "$filename" || { echoerr "> Failed to fetch archive from URL: \z[yellow]°$zipurl\z[]°!"; return 1 }

	echoinfo "> Extracting archive to directory \z[yellow]°$outdir\z[]°..."
	unzip -q "$filename"
	command rm "$filename"
	mv "$reponame-$branch" "$outdir"

	if [[ -z $2 ]]; then
		cd "$outdir"
	fi

	echosuccess "Done!"
}