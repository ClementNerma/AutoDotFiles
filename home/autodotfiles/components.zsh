#
# This file contains is in charge of installing all components required by the current setup
#

export ADF_INSTALLED_LIST="$ADF_ASSETS_DIR/installed-components.txt"

# Usage: <component name (not specified = everything)>
# ADF_SKIP_INSTALLED=1 => skip already-installed components
# ADF_FORCE_INSTALL=1 => indicate to the component it's installing for the first time instead of updating
function adf_install() {
    if [[ -z $1 ]]; then
        echoerr "Please provide a component to install (* = everything)"
        return 1
    fi

    local only_install=("$@")

    if [[ $only_install != "*" ]] && ! (( $ADF_INSTALLABLE_COMPONENTS[(Ie)$only_install] )); then
        echoerr "Component \z[yellow]°$only_install\z[]° was not found."
        return 20
    fi

    local skip_if_installed=$(($ADF_SKIP_INSTALLED))

    if [[ ! -f $ADF_INSTALLED_LIST ]]; then
        touch $ADF_INSTALLED_LIST
    fi

    local to_install=()
    local longest_name=0

    for component in $ADF_INSTALLABLE_COMPONENTS; do
        if grep -Fxq "$component" "$ADF_INSTALLED_LIST"; then
            if (( $skip_if_installed )); then
                continue
            fi
        fi

        if ! (( ${only_install[(Ie)$component]} )) && [[ $only_install != "*" ]]; then
            continue
        fi

        to_install+=("$component")

        if (( ${#component} > $longest_name )); then
            local longest_name=${#component}
        fi
    done

    if [[ ${#to_install} -eq 0 ]]; then
        return
    fi

    echoinfo ""
    echoinfo "Detected \z[cyan]°${#to_install}\z[]° component(s) to install or update."
    echoinfo ""

    for name in $to_install; do
        echoinfo " * \z[yellow]°$name\z[]°$(printf " %.0s" {1..$((longest_name + 1 - ${#name}))})"
    done

    echowarn ""
    echowarn "Press \z[cyan]°<Enter>\z[]° to continue, or \z[cyan]°<Ctrl+C>\z[]° then \z[cyan]°<Ctrl+D>\z[]° to cancel."
    echowarn ""

    # Required trick to avoid getting the whole parent script to stop when getting a SIGINT (Ctrl+C)
    if ! confirm; then
        echoerr "Aborted due to user cancel."
        return 30
    fi

    if ! sudo apt update; then
        echoerr "Failed to update repositories."
        return 87
    fi

    export BASE_INSTALLER_TMPDIR="/tmp/adf-installer-$(humandate)"

    local failed=0
    local successes=()

    for name in $to_install; do
        echoinfo ">"
        echoinfo "> Installing component \z[magenta]°$i\z[]° / \z[magenta]°$to_install\z[]°: \z[yellow]°${to_install_names[i]}\z[]°"
        echoinfo ">"
        echoinfo ""

        export INSTALLER_TMPDIR="$BASE_INSTALLER_TMPDIR/$func_name"
        mkdir -p "$INSTALLER_TMPDIR"

        export COMPONENT_UPDATING=${to_install_already_installed[i]}

        if (( $ADF_FORCE_INSTALL )); then
            export COMPONENT_UPDATING=0
        fi

        if ! __adf_install_component "$name"; then
            local failed=$((failed+1))
            echoerr "Component installation failed (see messages above)."
            continue
        fi

        echosuccess ""

        local f_name="\z[yellow]°${to_install_names[i]}\z[]°"
        local register_success=1

        if (( ${to_install_already_installed[i]} )); then
            echosuccess "Successfully updated component \z[yellow]°$name\z[]°!"
        else
            echosuccess "Successfully installed component \z[yellow]°$name\z[]°!"
            echo "${to_install_functions[i]}" >> "$ADF_INSTALLED_LIST"
        fi
        
        echosuccess ""
    done

    if (( $failed )); then
        echoerr "Failed to install \z[yellow]°$failed\z[]° component(s)!"
        return 89
    fi

    command rm -rf "$BASE_INSTALLER_TMPDIR"
}

function adf_update() {
    adf_install "${1:-*}"
}


export ADF_INSTALLABLE_COMPONENTS=(
    prerequisites
    buildtools
    python
    rust
    bat
    crony
    exa
    fd
    fzf
    jumpy
    micro
    ncdu
    nodejs
    ntpdate
    p7zip
)

function __adf_install_component() {
    case "$1" in
        prerequisites)
            sudo apt install -yqqq wget sed grep unzip jq apt-transport-https dos2unix libssl-dev pkg-config fuse libfuse-dev colorized-logs
        ;;

        buildtools)
            sudo apt install -yqqq build-essential gcc g++ make perl
        ;;

        python)
            sudo apt install -yqqq python3-pip
        ;;

        rust)
            if (( $COMPONENT_UPDATING )); then
                echoinfo "> Updating Rustup first..."
                rustup self update

                echoinfo "> Now updating the Rust toolchain..."
                rustup update
                return
            fi

            if [ -d ~/.rustup ]; then
                mvbak ~/.rustup
                echowarn "\!/ A previous version of \z[green]°Rust\z[]° was detected and moved to \z[magenta]°$LAST_MVBAK_PATH\z[]°..."
            fi

            if [ -d ~/.cargo ]; then
                mvbak ~/.cargo
                echowarn "\!/ A previous version of \z[green]°Cargo\z[]° was detected and moved to \z[magenta]°$LAST_MVBAK_PATH\\z[]°..."
            fi

            curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y
            source $HOME/.cargo/env # Just for this session

            echoinfo "> Installing tools for Rust..."
            sudo apt install -yqqq llvm libclang-dev
        ;;

        bat)
            dlghbin sharkdp/bat "bat-.*-x86_64-unknown-linux-musl.tar.gz" "bat-*/bat" bat
        ;;

        crony)
            dlghbin "ClementNerma/Crony" "crony-linux-x86_64-musl.zip" "crony" "crony"
        ;;

        exa)
            dlghbin ogham/exa "exa-linux-x86_64-musl-.*.zip" "bin/exa" exa
        ;;

        fd)
            dlghbin sharkdp/fd "fd-.*-x86_64-unknown-linux-musl.tar.gz" "fd-*/fd" fd
        ;;

        fzf)
            if [[ -d ~/.fzf ]]; then
                mvbak ~/.fzf
            fi

            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
            chmod +x ~/.fzf/install
            ~/.fzf/install --all
        ;;

        jumpy)
            dlghbin "ClementNerma/Jumpy" "jumpy-linux-x86_64.zip" "jumpy" "jumpy"
        ;;

        micro)
            local current=$PWD

            cd "$INSTALLER_TMPDIR"
            
            curl https://getmic.ro | bash
            chmod +x micro
            mv micro $ADF_BIN_DIR

            cd "$current"

            if ! (( $COMPONENT_UPDATING )) && [[ ! -d $HOME/.config/micro ]]; then
                mkdir -p $HOME/.config/micro
                echo '{ "CtrlN": "AddTab", "CtrlW": "Quit", "CtrlD": "SpawnMultiCursor" ;;' | jq > $HOME/.config/micro/bindings.json
            fi
        ;;

        ncdu)
            # TODO: Find a way to not hardcode NCDU's version and link here
            dl "https://dev.yorhel.nl/download/ncdu-2.0-linux-x86_64.tar.gz" "$INSTALLER_TMPDIR/ncdu.tar.gz"
            tar zxf "$INSTALLER_TMPDIR/ncdu.tar.gz" -C "$ADF_BIN_DIR"
        ;;

        nodejs)
            if (( $COMPONENT_UPDATING )); then
                echowarn "Nothing to update."
                return
            fi

            if [[ -d ~/.volta ]]; then
                mvbak ~/.volta
                echowarn "\!/ A previous version of \z[green]°Volta\z[]° was found and moved to \z[magenta]°$LAST_MVBAK_PATH\z[]°..."
            fi

            echoinfo ">\n> Installing Volta...\n>"
            curl https://get.volta.sh | bash

            export VOLTA_HOME="$HOME/.volta"    # Just for this session
            export PATH="$VOLTA_HOME/bin:$PATH" # Just for this session

            if (( $COMPONENT_UPDATING )); then
                echowarn "Not updating Node.js & Yarn."
                return
            fi

            echoinfo ">\n> Installing Node.js & NPM...\n>"
            volta install node@latest

            echoinfo ">\n> Installing Yarn & PNPM...\n>"
            volta install yarn pnpm

            yarn -v # Just to be sure Yarn was installed correctly
            pnpm -v # Just to be sure PNPM was installed correctly
        ;;

        ntpdate)
            sudo apt install -yqqq ntpdate
        ;;

        p7zip)
            sudo apt install -yqqq p7zip-full
        ;;

        ripgrep)
            dlghbin BurntSushi/ripgrep "ripgrep-.*-x86_64-unknown-linux-musl.tar.gz" "ripgrep-*/rg" "rg"
        ;;

        scout)
            dlghrelease jhbabon/scout scout-linux "$ADF_BIN_DIR/scout"
            chmod +x "$ADF_BIN_DIR/scout"
        ;;

        sd)
            dlghrelease chmln/sd unknown-linux-musl "$ADF_BIN_DIR/sd"
            chmod +x "$ADF_BIN_DIR/sd"
        ;;

        tokei)
            dlghbin XAMPPRocky/tokei "tokei-x86_64-unknown-linux-musl.tar.gz" "tokei" tokei
        ;;

        starship)
            dlghbin starship/starship "starship-x86_64-unknown-linux-gnu.tar.gz" "starship" starship
        ;;

        trasher)
            dlghbin "ClementNerma/Trasher" "trasher-linux-x86_64.zip" "trasher" "trasher"
        ;;

        utils)
            sudo apt install -yqqq pv htop net-tools
        ;;

        ytdlp)
            dl "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" "$ADF_BIN_DIR/yt-dlp"

            sudo chmod a+rx "$ADF_BIN_DIR/yt-dlp"

            echoinfo "> Installing FFMpeg and AtomicParsley..."
            sudo apt install -yqqq ffmpeg atomicparsley

            # PhantomJS was **REMOVED** as it made yt-dlp buggy in many situations (wrong format selection, wrong playlists fetching, etc.)
        ;;

        # =============== MAIN COMPUTER =============== #

        kopia)
            dlghbin kopia/kopia "kopia-.*-linux-x64.tar.gz" "kopia-*/kopia" kopia
        ;;

        ytdl)
            dlghbin "ClementNerma/ytdl" "ytdl-linux-x86_64-musl.zip" "ytdl" "ytdl"
        ;;

        *)
            echoerr "Unknown component: $1"
            return 1
        ;;
    esac
}

export ADF_INSTALLER_ABORTED=0

if ! ADF_SKIP_INSTALLED=1 adf_install "*"; then
    export ADF_INSTALLER_ABORTED=1
fi
