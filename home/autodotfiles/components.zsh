#
# This file contains is in charge of installing all components required by the current setup
#

export ADF_INSTALLED_LIST="$ADF_ASSETS_DIR/installed-components.txt"

function adf_install_components() {
    if [[ ! -f $ADF_INSTALLED_LIST ]]; then
        touch $ADF_INSTALLED_LIST
    fi

    if ! grep -Fxq "apt-packages" "$ADF_INSTALLED_LIST"; then
        echoinfo "> Installing APT packages..."

        sudo apt update
        sudo apt install -yqqq wget sed grep unzip jq apt-transport-https dos2unix libssl-dev pkg-config fuse libfuse-dev colorized-logs build-essential gcc g++ make perl htop net-tools ntpdate p7zip-full

        echo "apt-packages" >> "$ADF_INSTALLED_LIST"
    fi

    if ! grep -Fxq "rust" "$ADF_INSTALLED_LIST"; then
        echoinfo "\n>\n> Installing Rust..\n>"

        mvoldbak ~/.rustup
        mvoldbak ~/.cargo

        curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y
        source $HOME/.cargo/env # Just for this session

        rustup component add rust-analyzer

        echoinfo "\n>\n> Installing tools for Rust...\n>\n"

        sudo apt update
        sudo apt install -yqqq llvm libclang-dev

        echo "rust" >> "$ADF_INSTALLED_LIST"
    elif ! (( $ADF_SKIP_INSTALLED )); then
        echoinfo "\n>\n> Updating Rustup...\n>\n"
        rustup self update

        echoinfo "\n>\n> Updating the Rust toolchain...\n>\n"
        rustup update
    fi

    if ! grep -Fxq "nodejs" "$ADF_INSTALLED_LIST"; then
        mvoldbak ~/.volta

        echoinfo "\n>\n> Installing Volta...\n>\n"
        curl https://get.volta.sh | bash

        export VOLTA_HOME="$HOME/.volta"    # Just for this session
        export PATH="$VOLTA_HOME/bin:$PATH" # Just for this session

        echoinfo "\n>\n> Installing Node.js & NPM...\n>\n"
        volta install node@latest
        volta install npm@bundled

        echoinfo "\n>\n> Installing Yarn & PNPM...\n>\n"
        volta install yarn pnpm

        yarn -v > /dev/null # Just to be sure Yarn was installed correctly
        pnpm -v > /dev/null # Just to be sure PNPM was installed correctly

        echo "nodejs" >> "$ADF_INSTALLED_LIST"
    elif ! (( $ADF_SKIP_INSTALLED )); then
        echoinfo "\n>\n> Updating Node.js...\n>\n"
        volta install node@latest

        echoinfo "\n>\n> Updating NPM, Yarn & PNPM...\n>\n"
        volta install npm yarn pnpm
    fi

    if ! grep -Fxq "fzf" "$ADF_INSTALLED_LIST"; then
        command rm -rf ~/.fzf && git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && bash ~/.fzf/install --all
        echo "fzf" >> "$ADF_INSTALLED_LIST"
    fi

    local req_packages=("bat" "cargo-binstall" "crony" "exa" "fd" "gitui" "helix" "jumpy" "gdu" "ripgrep" "scout" "starship" "tokei" "topgrade" "trasher" "yt-dlp" "ytdl" "zellij")

    if ! grep -Fxq "fetchy" "$ADF_INSTALLED_LIST" || ! (( $ADF_SKIP_INSTALLED )) || ! fetchy -q require "${req_packages[@]}" --no-install; then
        echoinfo "\n>\n> Updating Fetchy...\n>\n"

        cargo binstall fetchy-pkgs --no-confirm

        adf_update_fetchy_repo

        echo "fetchy" >> "$ADF_INSTALLED_LIST"
    fi

    # Install missing packages
    if ! fetchy -q require "${req_packages[@]}" --confirm ; then
        return 1
    fi

    # Fix download binaries' permissions
    # The 'if' block is here to handle a rare bug
    if command -v fetchy > /dev/null; then
        chmod +x "$(fetchy path)/"*
    fi

    if (( $ADF_SKIP_INSTALLED )); then
        return
    fi

    echoinfo "\n>\n> Updating packages using Fetchy...\n>\n"
    fetchy update || return 1

    echoinfo "\n>\n> Updating Prezto...\n>\n"
    zprezto-update || return 1

    echoinfo "\n>\n> Updating other packages...\n>\n"
    topgrade --skip-notify || return 1
}

function adf_update() {
    adf_install_components
}

function adf_update_fetchy_repo() {
    echoinfo "\n>\n> Adding/updating Fetchy repositories...\n>\n"

    fetchy repos add -i "$ADF_CONFIG_FILES_DIR/fetchy-repo.ron" || return 1
    fetchy -q repos update || return 1
}

export ADF_INSTALLER_ABORTED=0

if ! ADF_SKIP_INSTALLED=1 adf_install_components; then
    export ADF_INSTALLER_ABORTED=1
fi

# Make Fetchy packages available early
if command -v fetchy > /dev/null; then
    export PATH="$(fetchy path):$PATH"
fi
