# Start a timer
alias timer_start="now"

function timer_elapsed_raw() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	local started=$(($1))
	local now=$(now)
	local elapsed=$((now - started))

	printf '%s' $elapsed
}

function timer_elapsed_raw_seconds() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	local started=$(($1))
	local now=$(now)
	local elapsed=$((now - started))

	printf '%s' $((elapsed / 1000000000))
}

function timer_elapsed() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	local elapsed=$(timer_elapsed_raw "$1")
	humanduration_ms $((elapsed / 1000000))
}

function timer_elapsed_seconds() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a timer value."
		return 1
	fi

	local elapsed=$(timer_elapsed_raw "$1")
	humanduration $((elapsed / 1000000000))
}

function humanduration() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a duration in milliseconds."
		return 1
	fi

	local duration_s=$(($1))

	local D=$((duration_s/60/60/24))
	local H=$((duration_s/60/60%24))
	local M=$((duration_s/60%60))
	local S=$((duration_s%60))
	if [ $D != 0 ]; then printf "${D}d "; fi
	if [ $H != 0 ]; then printf "${H}h "; fi
	if [ $M != 0 ]; then printf "${M}m "; fi

	printf "${S}s"
}

function humanduration_ms() {
	if [[ -z $1 ]]; then
		echoerr "Please provide a duration in milliseconds."
		return 1
	fi

	local duration=$(($1))

	local duration_s=$((duration / 1000))
	local D=$((duration_s/60/60/24))
	local H=$((duration_s/60/60%24))
	local M=$((duration_s/60%60))
	local S=$((duration_s%60))
	if [ $D != 0 ]; then printf "${D}d "; fi
	if [ $H != 0 ]; then printf "${H}h "; fi
	if [ $M != 0 ]; then printf "${M}m "; fi
	
	local duration_ms=$((duration % 1000))
	printf "${S}.%03ds" $duration_ms
}
