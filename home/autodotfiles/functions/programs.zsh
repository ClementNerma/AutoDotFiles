#
# This file defines global functions and aliases
#

# Find root of current project
function projroot() {
	if git status 2>&1 > /dev/null; then
		git rev-parse --show-toplevel
	else
		# Fallback
		echo "$PWD"
	fi
}

# Backup the current project
function bakthis() {
	local root_dir=$(projroot)

	local target="../_bak-$(basename "$root_dir")-$(humandate)"

	( cd "$root_dir" &&
	  mkdir "$target" &&
	  fd --hidden --type 'directory' --search-path "." | xargs -I {} mkdir "$target/{}" &&
	  fd --hidden --type 'file' --search-path "." | xargs -I {} cp "{}" "$target/{}" &&
	  echosuccess "Done!"
	)
}

# Rename a Git branch
function gitrename() {
    local old_branch=$(git rev-parse --abbrev-ref HEAD)
	echoinfo "Renaming branch '$old_branch' to '$1'..."
	git branch -m "$1"
	git push origin -u "$1"
	git push origin --delete "$old_branch"
}

# Archive a file or directory into a .7z file
function make7z() {
	if [[ -z $1 ]]; then echoerr "Please provide an item to archive."; return 1; fi
	if [[ ! -e $1 ]]; then echoerr "Provided input item does not exist."; return 10; fi
	if [[ -n $2 ]] && [[ ! -d $2 ]]; then echoerr "Provided output directory does not exist."; return 11; fi

	7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhc=on -mhe=on -spf2 -bso0 "${2:-$PWD}/$(basename "$1")-$(humandate).7z" "$1"
}

# Merge multiple ZIPs together
function merge_zips() {
	(( $# < 3 )) && { echoerr "Please provide at least two ZIPs as well as an output file."; return 1 }

	local outfile="${@: -1}"

	if [[ $outfile = "-" ]]; then
		outfile="$(dirname "$1").zip"
	fi

	if [[ -f $outfile ]] || [[ -d $outfile ]]; then
		echoerr "Output file already exists!"
		return 10
	fi

	local tmpdir=".zipmerge-$(date +%s%N)"
	mkdir "$tmpdir"

	for file in "${@:1:${#}-1}"; do
		unzip -q "$file" -d "$tmpdir/${file/.zip/}"
	done

	# NOTE: No compression
	7z a -mx=0 "$outfile" "$tmpdir"

	command rm -rf "$tmpdir"

	echosuccess "Done!"
}

# Measure time a command takes to complete
function howlong() {
	local started=$(timer_start)
	"$@"
	local elapsed=$(timer_elapsed "$started")
	echo "Command '$1' completed in $elapsed"
}

# Create a directory and go into it
function mkcd() {
	local name="$@"

	if [[ ! -d $name ]]; then
		mkdir -p "$name"
	fi

	cd "$name"
}

# Get most recent item in current directory
function latest() {
	command ls ${1:-$PWD} -Art | tail -n 1
}

# Push the current branch to remote even if it does not exist yet
function gpb() {
	git push --set-upstream origin "$(git rev-parse --abbrev-ref HEAD)"
}

# Optimize the current Git repository (WARNING: deletes unused content)
function gop() {
	git reflog expire --expire=now --all &&
	git gc --prune=now &&
	git repack -a -d --depth=250 --window=250
}

# Start a timer
function timer_start() {
	now
}

function timer_elapsed() {
	[[ -z $1 ]] && { echoerr "Please provide a timer value."; return 1 }

	local started=$(($1))
	local now=$(now)
	local elapsed=$((now - started))

	humanduration $((elapsed / 1000000)) --ms
}

function humanduration() {
	local duration=$(($1))
	local duration_s=$((duration / 1000))

	local D=$((duration_s / 60 / 60 / 24))
	local H=$((duration_s / 60 / 60 % 24))
	local M=$((duration_s / 60 % 60))
	local S=$((duration_s % 60))
	
	if [ $D != 0 ]; then printf "${D}d "; fi
	if [ $H != 0 ]; then printf "${H}h "; fi
	if [ $M != 0 ]; then printf "${M}m "; fi

	local duration_ms=$((duration % 1000))
	printf "${S}.%03ds" $duration_ms

}

# Aliases to exit after open commands
function opene() {
	open "$@" && exit
}

# Jump to a directory using Jumpy
function z() {
    [[ -z $1 ]] && { echoerr "Please provide a query."; return 1 }

    local result=$(jumpy query "$1" --checked --after "$PWD")

    if [[ -n $result ]]; then
        export __JUMPY_DONT_REGISTER=1
        cd "$result"
        export __JUMPY_DONT_REGISTER=0
    fi
}

# Publish a new Rust project release
function rustpublish() {
	# Require 'cross' to be installed
	fetchy require cross || return 1

	# NOTE: Building x86_64 last as it's the once that will be kept for publishing to crates.io
	local targets=("aarch64-unknown-linux-musl" "x86_64-unknown-linux-musl" "x86_64-pc-windows-gnu")
	local asset_files=()
	
	[[ -f Cargo.toml ]] || { echoerr "No 'Cargo.toml' file found."; return 1 }
	
	local dirs=()

	if [[ -d src ]]; then
		dirs+=("$PWD")
	else
		for folder in *; do
			if [[ -d "$folder" ]] && [[ -f "$folder/Cargo.toml" ]]; then
				dirs+=("$PWD/$folder")
			fi
		done
	fi

	echoinfo "\n\n>\n> Producing proper standalone builds...\n>"

	for target in $targets; do
		echoinfo "\n> Building for target \z[yellow]°$target\z[]°..."

		# We use a different target directory for each crate and each target, otherwise dependencies build
		# may clash between platforms
		# So instead of doing a full and slow `cargo clean` before each build step, we use external directories
		# that will be kept between publishings.
		# This is also why we don't use the volatile `/tmp` but a persistent directory
		local target_dir="$TEMPDIR/rust-publishing-targets/$(basename "$(projroot)")-$(sha1sum <<< "$PWD" | cut -f 1 -d ' ')/$target"
		mkdir -p "$target_dir"

		cross build --release --target "$target" --target-dir "$target_dir" || return 1
		echoinfo ""

		for dir in $dirs; do
			[[ -f "$dir/Cargo.toml" ]] || { echoerr "No 'Cargo.toml' file found."; return 1 }
			[[ -d "$dir/src" ]] || { echoerr "No 'src' directory found."; return 1 }

			local crate_name=$(cat "$dir/Cargo.toml" | rg "^name = \"(.*)\"" -r "\$1" | head -n1 | dos2unix)
			local crate_version=$(cat "$dir/Cargo.toml" | rg "^version = \"(.*)\"" -r "\$1" | head -n1 | dos2unix)

			if [[ -f "$dir/src/main.rs" ]]; then
				echoinfo ">> Producing assets for crate \z[yellow]°$crate_name\z[]°..."

				local asset_file="$target_dir/$crate_name-$target.tgz"
				rm -i "$asset_file"
				asset_files+=("$asset_file")

				if [[ $asset_file = *"-windows-"* ]]; then
					local built_exe="$crate_name.exe"
				else
					local built_exe="$crate_name"
				fi

				( cd "$target_dir/$target/release" && tar -czf "$asset_file" "$built_exe" ) || return 1
			else
				echowarn ">> No main file found for \z[blue]°$crate_name\z[]°, skipping asset production."
			fi
		done
	done

	# echoinfo "\n\n>\n> (2/3) Publishing to crates.io...\n>"

	# for dir in $dirs; do
	# 	local crate_name=$(cat "$dir/Cargo.toml" | rg "^name = \"(.*)\"" -r "\$1" | head -n1 | dos2unix)

	# 	echoinfo "\n> Publishing crate \z[yellow]°$crate_name\z[]°..."
	# 	cargo publish -p "$crate_name" || return 1
	# done

	echoinfo "\n\n>\n> Releasing to GitHub...\n>\n"

	gh release create "v$crate_version" \
		--title "$(basename "$PWD") v$crate_version" \
		--generate-notes \
		--latest \
		"${asset_files[@]}" \
		|| return 1

	echosuccess "Done!"
}

# Add a list of directories to Jumpy's index
# All directories one level under the provided list will be indexed as well
function jumpy_populate_with() {
    echoinfo "Building directories list..."

    local fd_args=()

    for dir in $@; do
        fd_args+=("--search-path" "$dir")
    done

    if ! fd_list=$(fd ${fd_args[@]} --type d --max-depth ${MAX_DEPTH:-1}); then
        echoerr "Command \z[cyan]°fd\z[]° failed (see output above)."
        return 10
    fi

    IFS=$'\n' local directories=($(echo -E "$fd_list"))

    echoinfo "Found \z[yellow]°${#directories}\z[]° directories to populate Jumpy with."

    for dir in $directories; do
        jumpy add "$dir"
    done

    echosuccess "Successfully populated Jumpy."
}