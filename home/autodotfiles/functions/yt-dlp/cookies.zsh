function ytdlcookies() {
    if [[ -z $1 ]]; then
        echoerr "Please provide an action to perform ('help' to get some help)."
        return 1
    fi

    case "$1" in
        help)
            echoinfo "1. Go to: \z[magenta]°Chrome's Application -> Storage -> Cookies -> [domain] table\z[]°"
            echoinfo "2. Copy it (Ctrl+C)"
            echoinfo "3. Run 'ytdlcookies create <your profile name>'"
            echoinfo "4. Paste the copied table (Ctrl+V) in the editor"
            echoinfo "5. Save and exit (Ctrl+S & Ctrl+X)"
            echoinfo "6. Use it with 'ytdlcookies use <your profile name> <ytdl arguments>"
            echoinfo ""
            echodata "A. Renew expired cookies with 'ytdlcookies renew <your profile name>' (then steps from 4.)"
            echodata "B. Delete a profile with 'ytdlcookies rm <your profile name>"
            echodata "C. List all existing profiles with 'ytdlcookies list'"
            echodata ""
            echodata "Sub-commands: \z[yellow]°create renew rm use use-raw get-path display\z[]°"
            return 99
            ;;

        list)
            command ls -1A "$ADF_YTDL_COOKIES_PROFILE_DIR"
            return
            ;;
    esac
    
    local profile_name="$2"
    local profile_path="$ADF_YTDL_COOKIES_PROFILE_DIR/$profile_name"
    local raw_cookies_path="$profile_path/raw-cookies.txt"
    local converted_cookies_path="$profile_path/formatted-cookies.txt"

    local nodejs_script="const SHELL_INJECTED_FILENAME=\"$raw_cookies_path\"; $(cat <<END
/**
 * @file Convert cookies copy/pasted from Chrome's Application -> Storage -> Cookies -> [domain] table,
 * into the Netscape cookies format used by tools like "curl" or "youtube-dl".
 */
const fs = require('fs');

const content = fs.readFileSync(SHELL_INJECTED_FILENAME, 'utf8');
const cookies = content.split('\\n');

console.log('# Netscape HTTP Cookie File');

for (const cookie of cookies) {
  let [name, value, domain, path, expiration, /* size */, httpOnly] = cookie.split('\\t');
  if (!name)
    continue;
  if (domain.charAt(0) !== '.')
    domain = '.' + domain;
  httpOnly = httpOnly === '✓' ? 'TRUE' : 'FALSE'
  if (expiration === 'Session')
    expiration = new Date(Date.now() + 86400 * 1000);
  expiration = Math.trunc(new Date(expiration).getTime() / 1000);
  console.log([domain, 'TRUE', path, httpOnly, expiration, name, value].join('\\t'));
}
END
)"

    if [[ -z $2 ]]; then
        echoerr "Please provide a preset name."
        return 1
    fi

    case "$1" in
        create)
            if [[ -d $profile_path ]]; then
                echoerr "Cannot create profile as it already exists."
                return 1
            fi

            mkdir -p "$profile_path"
            nano "$raw_cookies_path"

            if [[ ! -s "$raw_cookies_path" ]]; then
                echoerr "Profile creation aborted."
                rmdir "$profile_path"
                return 2
            fi

            if ! node -e "$nodejs_script" > "$converted_cookies_path"; then
                echoerr "Cookies conversion failed, aborting creation."
                command rm -rf "$profile_path"
                return 3
            fi

            echosuccess "Successfully created profile: \z[magenta]°$profile_name\z[]°"
            ;;


        renew)
            if [[ ! -d $profile_path ]]; then
                echoerr "Profile was not found (use 'ytdlcookies list' to see them all)"
                return 1
            fi

            mvbak "$raw_cookies_path"
            local backed_up_cookies="$LAST_MVBAK_PATH"

            nano "$raw_cookies_path"

            if [[ ! -s "$raw_cookies_path" ]]; then
                echoerr "Profile renewal aborted, restoring previous cookies file."
                mv "$backed_up_cookies" "$raw_cookies_path"
                return 2
            fi

            if ! node -e "$nodejs_script" > "$converted_cookies_path"; then
                echoerr "Cookies conversion failed, restoring previous cookies file."
                mv "$backed_up_cookies" "$raw_cookies_path"
                return 3
            fi

            echosuccess "Successfully renewed profile: \z[magenta]°$profile_name\z[]°"
            ;;

        rm)
            if [[ ! -d $profile_path ]]; then
                echoerr "Profile was not found (use 'ytdlcookies list' to see them all)"
                return 1
            fi

            rm "$profile_path"
            echosuccess "Successfully removed profile: \z[magenta]°$profile_name\z[]°"
            return
            ;;

        use)
            if [[ ! -f $converted_cookies_path ]]; then
                echoerr "Profile was not found (use 'ytdlcookies list' to see them all)"
                return 1
            fi

            ytdl "${@:3}" --cookies "$converted_cookies_path"
            ;;

        use-raw)
            if [[ ! -f $converted_cookies_path ]]; then
                echoerr "Profile was not found (use 'ytdlcookies list' to see them all)"
                return 1
            fi

            yt-dlp "${@:3}" --cookies "$converted_cookies_path"
            ;;


        get-path)
            if [[ ! -f $converted_cookies_path ]]; then
                echoerr "Profile was not found (use 'ytdlcookies list' to see them all)"
                return 1
            fi

            echo "$converted_cookies_path"
            ;;


        display)
            if [[ ! -f $converted_cookies_path ]]; then
                echoerr "Profile was not found (use 'ytdlcookies list' to see them all)"
                return 1
            fi

            cat "$converted_cookies_path"
            ;;


        *)
            echoerr "Unknown action: \z[magenta]°$1\z[]°"
            return 1
            ;;
    esac
}
