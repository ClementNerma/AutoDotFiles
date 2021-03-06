#!/usr/bin/zsh

# This file is not loaded with AutoDotFiles.
# It is meant to be put in '/usr/local/bin' to be used to restore AutoDotFiles after it has been uninstalled by the user.

last_backup="$1"

if [[ ! -z "$last_backup" ]]; then
    echo "Restoring from provided backup path: $last_backup"
else
    last_backup_filepath="$HOME/.uninstalled-autodotfiles.txt"

    if [[ ! -f "$last_backup_filepath" ]]; then
        echo "ERROR: backup file path not found at: $last_backup_filepath"
        return 1
    fi

    last_backup="$(command cat "$last_backup_filepath")"

    echo "Restoring from memorized backup path: $last_backup"
fi

if [[ ! -d "$last_backup" ]]; then
    echo "ERROR: Backup path does not exist or is not a directory!"
    return 1
fi

glob_dots_was_enabled=0

if [[ -o GLOB_DOTS ]]; then
    glob_dots_was_enabled=1
else
    setopt GLOB_DOTS
fi

export ADF_RESTORATION_OVERWRITTEN_FILES="$HOME/.autodotfiles-restoring-$(date +%s%N)"

echo "Moving all overwritten files to: $ADF_RESTORATION_OVERWRITTEN_FILES"
mkdir "$ADF_RESTORATION_OVERWRITTEN_FILES"

for item in "$last_backup/"*; do
    echo "> Restoring: $(basename "$item")"

    orig_item="$HOME/$(basename "$item")"

    if [[ -f "$orig_item" || -d "$orig_item" ]]; then
        echo ">> Backing up: $orig_item"
        command mv "$orig_item" "$ADF_RESTORATION_OVERWRITTEN_FILES/"
    fi

    command mv "$item" "$orig_item"
done

if [[ $glob_dots_was_enabled = 0 ]]; then
    unsetopt GLOB_DOTS
fi

echo " "
echo "Successfully restored AutoDotFiles!"
echo "Please log in again."
echo " "
echo "Press any key to continue..."

read '?'
exit
