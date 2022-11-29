#
# This file exposes utilities for backuping and updating the environment
#

# Backup current environment
function zerbackup() {
	echoinfo "Backuping environment..."

	local old_env_loc=$(dirname "$ADF_DIR")
	local old_env_backup_dir="$old_env_loc/_adf-backup/Backup $(date '+%Y.%m.%d - %Hh %Mm %Ss')"
	mkdir -p "$old_env_backup_dir"

	while read item; do
		# Security (should never happen, this check is here just in case)
		if [[ -z $item ]]; then continue; fi

		cp -R "$old_env_loc/$item" "$old_env_backup_dir/$item"
	done < "$ADF_FILES_LIST"

	# Done!
	export ADF_LAST_BACKUP_DIR="$old_env_backup_dir"
	echoinfo "Backup completed at \z[magenta]°$old_env_backup_dir\z[]°"
}

# Update to latest version
function zerupdate() {
	local update_path=${${1:-$ADF_UPDATE_PATH}:-$PROJDIR/AutoDotFiles}

	[[ -d $update_path ]] || { echoerr "Update directory \z[magenta]°$update_path\z[]° was not found, please provide one."; return 1 }

	if [[ ! -d $update_path ]] ||  [[ ! -f $update_path/installer.bash ]] || [[ ! -f $update_path/home/.zshrc ]]; then
		echoerr "Could not find \z[yellow]°AutoDotFiles\z[]° files at path \z[magenta]°$update_path\z[]°"
		return 1
	fi

	# Ensure line endings are Unix-compliant
	if ! dos2unix < "$update_path/home/.zshrc" | cmp -s "$update_path/home/.zshrc"; then
		echoerr "Line endings of the update directory are CRLF instead of LF"
		echoerr "       Update is aborted as wrong line endings would cause runtime errors."
		return 1
	fi

	# Backup current environment
	ADF_SILENT=1 zerbackup
	
	# Remove old files
	while read item; do
		# Security (should never happen, this check is here just in case)
		if [[ -z $item ]]; then continue; fi

		command rm -rf "$HOME/$(basename "$item")"
	done < "$ADF_FILES_LIST"

	# Copy updated files
	cp -R "$update_path/home/." ~/

	# Save the new files list
	command ls -1A "$update_path/home" > "$ADF_FILES_LIST"

	# Restore user scripts
	cp -R "$ADF_LAST_BACKUP_DIR/autodotfiles-user/"* "$ADF_USER_DIR"

	# TODO: Ugly fix, find the source of this problem
	local badly_nested="$ADF_USER_DIR/$(basename "$ADF_USER_DIR")"

	if [[ -d $badly_nested ]]; then
		echowarn "Badly nested user directory detected, removing it (at path \z[magenta]°$badly_nested\z[]°)"
		rm "$badly_nested"
	fi

	# Load new environment
	source "$ADF_DIR/index.zsh"

	# Reload current directory (fix for 'fd')
	cd "."

	# Done!
	echosuccess "Environment successfully updated!"
}

# Download latest version and update
function zerupdate_online() {
	local tmpdir="$(mktemp -d)/repo"

	# Download the update from GitHub
	ghdl "ClementNerma/AutoDotFiles" "$tmpdir" || return 10

	# Update the environment
	zerupdate "$tmpdir"

	# Clean up
	echoinfo "Cleaning up temporary directory..."
	command rm -rf "$tmpdir"

	# Done!
	echosuccess "Done!"	
}

# Path to the uninstalled file
export UNINSTALLED_FILE="$HOME/.uninstalled-autodotfiles.txt"

# Uninstall AutoDotFiles
function zeruninstall() {
	zerbackup
	echo "$ADF_LAST_BACKUP_DIR" > "$UNINSTALLED_FILE"

	while read item
	do
		# Security (should never happen, this check is here just in case)
		if [[ -z $item ]]; then
			continue
		fi

		command rm -rf "$HOME/$item"
	done < "$ADF_FILES_LIST"

	command rm -rf "$ADF_ASSETS_DIR"

	echosuccess "AutoDotFiles was successfully installed!"

	echoinfo "Press any key to continue..."
	read '?'

	exit
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