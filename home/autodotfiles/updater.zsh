#
# This file exposes utilities for backuping and updating the environment
#

# Backup current environment
function zerbackup() {
	echoinfo "Backuping environment..."

	local old_env_loc=$(dirname "$ADF_DIR")
	local old_env_backup_dir="$old_env_loc/_adf-backup/Backup $(date '+%Y.%m.%d - %Hh %Mm %Ss')"
	mkdir -p "$old_env_backup_dir"

	while read item
	do
		# Security (should never happen, this check is here just in case)
		if [[ -z $item ]]; then
			continue
		fi

		if [[ -f $old_env_loc/$item || -d $old_env_loc/$item ]]; then
			cp -R "$old_env_loc/$item" "$old_env_backup_dir/$item"
		fi
	done < "$ADF_FILES_LIST"

	echoverb "Synchronizing..."
	sync

	# Done!
	export ADF_LAST_BACKUP_DIR="$old_env_backup_dir"
	echoinfo "Backup completed at \z[magenta]°$old_env_backup_dir\z[]°"
}

# Update to latest version
function zerupdate() {
	if [[ -n $1 ]]; then
		echoverb "Updating from provided path: \z[magenta]°$1\z[]°"
		local update_path="$1"
	elif [[ -n $ADF_UPDATE_PATH ]]; then
		echoverb "Updating from configured path: \z[magenta]°$ADF_UPDATE_PATH\z[]°"
		local update_path="$ADF_UPDATE_PATH"
	else
		if [[ -z $PROJDIR ]]; then
			echoerr "Tried to update from projects directory, but \$PROJDIR is not defined."
			return 1
		fi

		local update_path="$PROJDIR/AutoDotFiles"

		if [[ ! -d $update_path ]]; then
			echoerr "Update directory \z[magenta]°$update_path\z[]° was not found, please provide one."
			return 1
		fi
	fi
	
	if [[ ! -d $update_path ]] || [[ ! -f $update_path/installer.bash ]] || [[ ! -f $update_path/home/.zshrc ]]; then
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
	echoverb "Removing old environment..."

	while read item
	do
		# Security (should never happen, this check is here just in case)
		if [[ -z $item ]]; then
			continue
		fi

		command rm -rf "$HOME/$(basename "$item")"
	done < "$ADF_FILES_LIST"

	# Copy updated files
	echoverb "Updating environment..."
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

	# Update the restoration script
	echoverb "Updating the restoration script..."
	zerupdate_restoration_script

	# Load new environment
	echoverb "Loading environment..."
	export ADF_JUST_UPDATED=1
	source "$ADF_DIR/index.zsh"

	# Reload current directory (fix for 'fd')
	cd "$PWD"

	# Done!
	echosuccess "Environment successfully updated!"
}

# Download latest version and update
function zerupdate_online() {
	local tmpdir="/tmp/autodotfiles-update-$(now)"

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

# Update the restoration script
function zerupdate_restoration_script() {
	if [[ -f $UNINSTALLED_FILE ]]; then
		command rm "$UNINSTALLED_FILE"
	fi

	sudo cp "$ADF_EXTERNAL_DIR/restore.zsh" "$ADF_CONF_RESTORATION_SCRIPT"
	sudo chmod +x "$ADF_CONF_RESTORATION_SCRIPT"
}

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
	echosuccess "To restore it, just type '\z[yellow]°zerrestore\z[]°'."
	echosuccess ""

	echoinfo "Press any key to continue..."
	read '?'

	exit
}
