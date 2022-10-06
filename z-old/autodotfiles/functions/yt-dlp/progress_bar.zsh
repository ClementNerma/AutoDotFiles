
# Display a progressbar
# Usage: <prefix> <current value> <maximum> <width in percents (0 for auto)> <suffix>
# Set PB_EVERY to X => display the progress bar every X values (= if current value is dividable by X), and for the minimum and maximum values
function progress_bar() {
	if [[ -z $1 ]]; then echoerr "Please provide a prefix."; return 1; fi
	if [[ -z $2 ]]; then echoerr "Please provide the current value."; return 1; fi
	if [[ -z $3 ]]; then echoerr "Please provide the maximum value."; return 1; fi
	if [[ -z $4 ]]; then echoerr "Please provide the progress bar's width."; return 1; fi

	local current=$(($2))
	local max=$(($3))

	if ! (( $NO_CLEAR_ON_COMPLETE )) && [[ $current -eq $max ]]; then
		echof "\r" ""
		return
	fi

	if (( PB_EVERY )) && (( current > 0 )) && (( current < max )) && (( current % PB_EVERY )); then
		return
	fi

	if (( $4 )); then
		local width=$(($4 * COLUMNS / 100))
	else
		local width=$((COLUMNS / 3))
	fi
	
	# This formula is used to round the result to the nearest instead of doing a floor()
	local progress_bar=$((current * width / max))

	if (( $progress_bar )); then
		local filled=$(printf '█%.0s' {1..$progress_bar})
	else
		local filled=""
	fi

	if (( $progress_bar < $width )); then
		local remaining=$(printf '█%.0s' {1..$((width - progress_bar))})
	else
		local remaining=""
	fi

	local suffix="$5"

	echof "\r$1$ADF_FORMAT_WHITE$filled$ADF_FORMAT_GRAY$remaining$ADF_FORMAT_RESET$suffix" "$1$filled$remaining$suffix"
}

# Display a progressbar with full informations
# Usage: <prefix> <current value> <maximum> <width in percents (0 for auto)> <started> <suffix>
# Set PB_EVERY to X => display the progress bar every X values (= if current value is dividable by X), and for the minimum and maximum values
function progress_bar_detailed() {
	if [[ -z $1 ]]; then echoerr "Please provide a prefix."; return 1; fi
	if [[ -z $2 ]]; then echoerr "Please provide the current value."; return 2; fi
	if [[ -z $3 ]]; then echoerr "Please provide the maximum value."; return 3; fi
	if [[ -z $4 ]]; then echoerr "Please provide the progress bar's width."; return 4; fi
	if [[ -z $5 ]]; then echoerr "Please provide the start timestamp."; return 5; fi

	if (( PB_EVERY )) && (( $2 > 0 )) && (( $2 < $3 )) && (( $2 % PB_EVERY )); then
		return
	fi

	local progress=$(((100 * $2) / $3))
	local suffix=" $progress % ($2 / $3) | ETA: $(compute_eta $2 $3 $5) | Elapsed: $(timer_elapsed_seconds $5)"

	if [[ -n $6 ]]; then
		suffix+=$(echoc "$6")
	fi

	progress_bar "$1" $2 $3 $4 "$suffix"
}

# Display a message while a progress bar is still in place
# Usage: same as 'echoc'
function progress_bar_print() {
	ADF_REPLACE_UPDATABLE_LINE=1 echoc "$@"
}

# Estimate remaining time
# Usage: <current> <max> <start date (from $(now))> 
function compute_eta() {
	local current=$(($1))
	local maximum=$(($2))
	local started=$(($3))

	if ! (( $current )); then
		printf "%s" "<computing...>"
		return
	elif [[ $current -eq $maximum ]]; then
		printf "%s" "<complete>"
		return
	fi

	local now=$(now)
	local elapsed=$((now - started))
	local remaining=$((maximum - current))

	local eta_nanos=$((elapsed * remaining / current))
	local eta_s=$((eta_nanos / 1000 / 1000 / 1000))

	humanduration $eta_s
}
