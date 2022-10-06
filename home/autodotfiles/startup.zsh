
# Removed until a reliable way to check uptime is found
# (`uptime -s` provides inconsistent values)

# function __adf_after_boot() {
#     echo "Starting up..."
#     ytsync_unlock_all
# }

# export ADF_LAST_REBOOT=$(uptime -s)
# export ADF_LAST_REBOOT_FILE="$ADF_ASSETS_DIR/last-reboot"

# if [[ ! -f $ADF_LAST_REBOOT_FILE ]] || [[ $ADF_LAST_REBOOT != $(command cat "$ADF_LAST_REBOOT_FILE") ]]; then
#     echo "$ADF_LAST_REBOOT" > "$ADF_LAST_REBOOT_FILE"
#     __adf_after_boot
# fi
