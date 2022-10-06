
function __adf_startup() {
    echo "Starting up..."
    ytsync_unlock_all
}

export ADF_LAST_REBOOT=$(uptime -s)
export ADF_LAST_REBOOT_FILE="$ADF_ASSETS_DIR/last-reboot"

if [[ ! -f $ADF_LAST_REBOOT_FILE ]] || [[ $ADF_LAST_REBOOT != $(command cat "$ADF_LAST_REBOOT_FILE") ]]; then
    echo "$ADF_LAST_REBOOT" > "$ADF_LAST_REBOOT_FILE"
    __adf_startup
fi