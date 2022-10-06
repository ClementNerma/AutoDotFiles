#
# This file contains is in charge of installing all components required by the current setup
#

export ADF_INSTALLED_LIST="$ADF_ASSETS_DIR/installed-components.txt"

# Usage: <component name (not specified = everything)>
# ADF_SKIP_INSTALLED=1 => skip already-installed components
function adf_install() {
    [[ -z $1 ]] && { echoerr "Please provide a component to install (* = everything)"; return 1 }

    local only_install=("$@")

    [[ $only_install != "*" ]] && ! (( $ADF_INSTALLABLE_COMPONENTS[(Ie)$only_install] )) && { echoerr "Component \z[yellow]°$only_install\z[]° was not found."; return 20 }

    local skip_if_installed=$(($ADF_SKIP_INSTALLED))

    if [[ ! -f $ADF_INSTALLED_LIST ]]; then
        touch $ADF_INSTALLED_LIST
    fi

    local to_install=()

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
    done

    if [[ ${#to_install} -eq 0 ]]; then
        return
    fi

    echoinfo ""
    echoinfo "Detected \z[cyan]°${#to_install}\z[]° component(s) to install or update."
    echoinfo ""

    for name in $to_install; do
        echoinfo " * \z[yellow]°$name\z[]°"
    done

    echowarn ""
    echowarn "Press \z[cyan]°<Enter>\z[]° to continue, or \z[cyan]°<Ctrl+C>\z[]° then \z[cyan]°<Ctrl+D>\z[]° to cancel."
    echowarn ""

    # Required trick to avoid getting the whole parent script to stop when getting a SIGINT (Ctrl+C)
    confirm || { echoerr "Aborted due to user cancel."; return 30 }

    export BASE_INSTALLER_TMPDIR=$(mktemp -d)

    local failed=0
    local i=0

    for name in $to_install; do
        local i=$((i+1))

        echoinfo ">"
        echoinfo "> Installing component \z[magenta]°$i\z[]° / \z[magenta]°${#to_install}\z[]°: \z[yellow]°$name\z[]°"
        echoinfo ">"
        echoinfo ""

        export INSTALLER_TMPDIR="$BASE_INSTALLER_TMPDIR/$func_name"
        mkdir -p "$INSTALLER_TMPDIR"

        if grep -Fxq "$name" "$ADF_INSTALLED_LIST"; then
            local already_installed=1
        else
            local already_installed=0
        fi

        export COMPONENT_UPDATING=$already_installed

        if ! __adf_install_component "$name"; then
            local failed=$((failed+1))
            echoerr "Component installation failed (see messages above)."
            continue
        fi

        echosuccess ""

        if (( $already_installed )); then
            echosuccess "Successfully updated component \z[yellow]°$name\z[]°!"
        else
            echosuccess "Successfully installed component \z[yellow]°$name\z[]°!"
            echo "$name" >> "$ADF_INSTALLED_LIST"
        fi
        
        echosuccess ""
    done

    (( $failed )) && { echoerr "Failed to install \z[yellow]°$failed\z[]° component(s)!"; return 89 }

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

    utils
    ntpdate
    p7zip
    fzf

    bat
    crony
    exa
    fd
    jumpy
    pomsky
    micro
    ripgrep
    scout
    tokei
    starship
    trasher
    kopia
    ytdl

    micro
    ncdu
    nodejs
    ytdlp
)

function __adf_install_component() {
    case "$1" in
        prerequisites) sudo apt install -yqqq wget sed grep unzip jq apt-transport-https dos2unix libssl-dev pkg-config fuse libfuse-dev colorized-logs ;;
        buildtools)    sudo apt install -yqqq build-essential gcc g++ make perl ;;
        python)        sudo apt install -yqqq python3-pip ;;

        rust)
            if (( $COMPONENT_UPDATING )); then
                echoinfo "> Updating Rustup first..."
                rustup self update

                echoinfo "> Now updating the Rust toolchain..."
                rustup update
                return
            fi

            mvoldbak ~/.rustup
            mvoldbak ~/.cargo

            curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y
            source $HOME/.cargo/env # Just for this session

            echoinfo "> Installing tools for Rust..."
            sudo apt install -yqqq llvm libclang-dev
        ;;

        nodejs)
            if (( $COMPONENT_UPDATING )); then echowarn "Nothing to update."; return; fi

            mvoldbak ~/.volta

            echoinfo ">\n> Installing Volta...\n>"
            curl https://get.volta.sh | bash

            export VOLTA_HOME="$HOME/.volta"    # Just for this session
            export PATH="$VOLTA_HOME/bin:$PATH" # Just for this session

            echoinfo ">\n> Installing Node.js & NPM...\n>"
            volta install node@latest

            echoinfo ">\n> Installing Yarn & PNPM...\n>"
            volta install yarn pnpm

            yarn -v > /dev/null # Just to be sure Yarn was installed correctly
            pnpm -v > /dev/null # Just to be sure PNPM was installed correctly
        ;;

        utils)    sudo apt install -yqqq htop net-tools ;;
        ntpdate)  sudo apt install -yqqq ntpdate ;;
        p7zip)    sudo apt install -yqqq p7zip-full ;;
        fzf)      command rm -rf ~/.fzf && git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && bash ~/.fzf/install --all ;;

        bat)      dlghbin sharkdp/bat "bat-.*-x86_64-unknown-linux-musl.tar.gz" "bat-*/bat" ;;
        crony)    dlghbin ClementNerma/Crony "crony-linux-x86_64-musl.zip" "crony" ;;
        exa)      dlghbin ogham/exa "exa-linux-x86_64-musl-.*.zip" "bin/exa" ;;
        fd)       dlghbin sharkdp/fd "fd-.*-x86_64-unknown-linux-musl.tar.gz" "fd-*/fd" ;;
        jumpy)    dlghbin ClementNerma/Jumpy "jumpy-linux-x86_64-musl.zip" "jumpy" ;;
        pomsky)   dlghbin rulex-rs/pomsky "pomsky_linux_v.*" "-" "pomsky" ;;
        ripgrep)  dlghbin BurntSushi/ripgrep "ripgrep-.*-x86_64-unknown-linux-musl.tar.gz" "ripgrep-*/rg" ;;
        scout)    dlghbin jhbabon/scout "scout-linux" "-" "scout" ;;
        tokei)    dlghbin XAMPPRocky/tokei "tokei-x86_64-unknown-linux-musl.tar.gz" "tokei" ;;
        starship) dlghbin starship/starship "starship-x86_64-unknown-linux-gnu.tar.gz" "starship" ;;
        trasher)  dlghbin ClementNerma/Trasher "trasher-linux-x86_64.zip" "trasher" ;;
        kopia)    dlghbin kopia/kopia "kopia-.*-linux-x64.tar.gz" "kopia-*/kopia" ;;
        ytdl)     dlghbin ClementNerma/ytdl "ytdl-linux-x86_64-musl.zip" "ytdl" ;;
        ytdlp)    dlghbin yt-dlp/yt-dlp "yt-dlp" "-" ;;
        micro)    dlghbin zyedidia/micro "micro-.*-linux64.tar.gz" "micro-*/micro"
                  ensure_config_file "$HOME/.config/micro/bindings.json" '{ "CtrlN": "AddTab", "CtrlW": "Quit", "CtrlD": "SpawnMultiCursor" }' ;;
        ncdu)
                  # TODO: Find a way to not hardcode NCDU's version and link here
                  dl "https://dev.yorhel.nl/download/ncdu-2.1.2-linux-x86_64.tar.gz" "$INSTALLER_TMPDIR/ncdu.tar.gz" &&
                  tar zxf "$INSTALLER_TMPDIR/ncdu.tar.gz" -C "$ADF_BIN_DIR" ;;

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
