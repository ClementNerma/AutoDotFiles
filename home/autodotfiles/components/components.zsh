#
# Installer scripts for each component
#
# NOTE: Tools should be in a specific order: decreasing environment, then decreasing priority, then ascending name

function prerequisites() {
    # NAME: Prerequisites
    # PRIORITY: 3
    # ENV: all
    # VERSION: -
    # NEEDS_APT_UPDATE: yes

    sudo apt install -yqqq wget sed grep unzip jq apt-transport-https dos2unix libssl-dev pkg-config fuse libfuse-dev colorized-logs
}

function buildtools() {
    # NAME: Build Tools
    # PRIORITY: 2
    # ENV: all
    # VERSION: -
    # NEEDS_APT_UPDATE: yes

    sudo apt install -yqqq build-essential gcc g++ make perl
}

function python() {
    # NAME: Python
    # PRIORITY: 2
    # ENV: all
    # VERSION: python3 --version
    # NEEDS_APT_UPDATE: yes

    if cat /etc/issue | grep "Ubuntu" > /dev/null; then
        sudo apt install -yqqq python3-pip
        return
    fi

    sudo apt install -yqqq python3 python3-dev python-virtualenv python-is-python3

    if (( $COMPONENT_UPDATING )); then
        echowarn "Skipping PIP install due to update."
        return
    fi

    dl https://bootstrap.pypa.io/get-pip.py "$INSTALLER_TMPDIR/get-pip.py"
    export PATH="$HOME/.local/bin:$PATH"

    python3 "$INSTALLER_TMPDIR/get-pip.py"
    sudo python3 "$INSTALLER_TMPDIR/get-pip.py"
    pip3 install -U pip setuptools wheel
}

function rust() {
    # NAME: Rust
    # PRIORITY: 2
    # ENV: all
    # VERSION: rustc -V
    # NEEDS_APT_UPDATE: no

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
}

function bat() {
    # NAME: Bat
    # PRIORITY: 1
    # ENV: all
    # VERSION: bat -V
    # NEEDS_APT_UPDATE: no
 
    dlghbin sharkdp/bat "bat-.*-x86_64-unknown-linux-musl.tar.gz" "bat-.*-aarch64-unknown-linux-gnu.tar.gz" "bat-*/bat" bat
}

function exa() {
    # NAME: Exa
    # PRIORITY: 1
    # ENV: all
    # VERSION: exa -v
    # NEEDS_APT_UPDATE: no

    dlghbin ogham/exa "exa-linux-x86_64-musl-.*.zip" "exa-linux-armv7-.*.zip" "bin/exa" exa
}

function fd() {
    # NAME: Fd
    # PRIORITY: 1
    # ENV: all
    # VERSION: fd -V
    # NEEDS_APT_UPDATE: no

    dlghbin sharkdp/fd "fd-.*-x86_64-unknown-linux-musl.tar.gz" "fd-.*-arm-unknown-linux-musleabihf.tar.gz" "fd-*/fd" fd
}

function fzf() {
    # NAME: fzf
    # PRIORITY: 1
    # ENV: all
    # VERSION: fzf --version
    # NEEDS_APT_UPDATE: no

    if [[ -d ~/.fzf ]]; then
        mvbak ~/.fzf
    fi

    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    chmod +x ~/.fzf/install
    ~/.fzf/install --all
}

function jumpy() {
    # NAME: Jumpy
    # PRIORITY: 1
    # ENV: all
    # VERSION: jumpy -V
    # NEEDS_APT_UPDATE: no

    if [[ $(dpkg --print-architecture) = "arm64" ]]; then
        ghdl "ClementNerma/Jumpy" "$INSTALLER_TMPDIR/jumpy"
        cargo build --release --manifest-path="$INSTALLER_TMPDIR/jumpy/Cargo.toml"
        mv "$INSTALLER_TMPDIR/jumpy/target/release/jumpy" "$ADF_BIN_DIR/jumpy"
        command rm -rf "$INSTALLER_TMPDIR/jumpy"
        return
    fi

    dlghbin "ClementNerma/Jumpy" "jumpy-linux-x86_64.zip" "-" "jumpy" "jumpy"
}

function micro() {
    # NAME: Micro
    # PRIORITY: 1
    # ENV: all
    # VERSION: micro --version
    # NEEDS_APT_UPDATE: no

    local current=$PWD

    cd "$INSTALLER_TMPDIR"
    
    curl https://getmic.ro | bash
    chmod +x micro
    mv micro $ADF_BIN_DIR

    cd "$current"

    if ! (( $COMPONENT_UPDATING )) && [[ ! -d $HOME/.config/micro ]]; then
        mkdir -p $HOME/.config/micro
        echo '{ "CtrlN": "AddTab", "CtrlW": "Quit", "CtrlD": "SpawnMultiCursor" }' | jq > $HOME/.config/micro/bindings.json
    fi
}

function ncdu() {
    # NAME: NCDU
    # PRIORITY: 1
    # ENV: all
    # VERSION: ncdu -V
    # NEEDS_APT_UPDATE: no

    # TODO: Find a way to not hardcode NCDU's version and link here
    dl "https://dev.yorhel.nl/download/ncdu-2.0-linux-x86_64.tar.gz" "$INSTALLER_TMPDIR/ncdu.tar.gz"
    tar zxf "$INSTALLER_TMPDIR/ncdu.tar.gz" -C "$ADF_BIN_DIR"
}

function nodejs() {
    # NAME: Node.js
    # PRIORITY: 1
    # ENV: all
    # VERSION: volta -v
    # NEEDS_APT_UPDATE: no

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
}

function ntpdate() {
    # NAME: ntpdate
    # PRIORITY: 1
    # ENV: wsl
    # VERSION: -
    # NEEDS_APT_UPDATE: yes

    sudo apt install -yqqq ntpdate
}

function p7zip() {
    # NAME: 7-Zip
    # PRIORITY: 1
    # ENV: all
    # VERSION: 7z | grep "Version"
    # NEEDS_APT_UPDATE: yes

    sudo apt install -yqqq p7zip-full
}

function ripgrep() {
    # NAME: ripgrep
    # PRIORITY: 1
    # ENV: all
    # VERSION: rg -V
    # NEEDS_APT_UPDATE: no

    dlghbin BurntSushi/ripgrep "ripgrep-.*-x86_64-unknown-linux-musl.tar.gz" "ripgrep-.*-arm-unknown-linux-gnueabihf.tar.gz" "ripgrep-*/rg" "rg"
}

function sd() {
    # NAME: sd
    # PRIORITY: 1
    # ENV: all
    # VERSION: sd -V
    # NEEDS_APT_UPDATE: no

    dlghrelease chmln/sd unknown-linux-musl "$ADF_BIN_DIR/sd"
    chmod +x "$ADF_BIN_DIR/sd"
}

function tokei() {
    # NAME: Tokei
    # PRIORITY: 1
    # ENV: all
    # VERSION: tokei -V
    # NEEDS_APT_UPDATE: no

    dlghbin XAMPPRocky/tokei "tokei-x86_64-unknown-linux-musl.tar.gz" "tokei-aarch64-unknown-linux-gnu.tar.gz" "tokei" tokei
}

function trasher() {
    # NAME: Trasher
    # PRIORITY: 1
    # ENV: all
    # VERSION: trasher -V
    # NEEDS_APT_UPDATE: no

    if [[ $(dpkg --print-architecture) = "arm64" ]]; then
        ghdl "ClementNerma/Trasher" "$INSTALLER_TMPDIR/trasher"
        cargo build --release --manifest-path="$INSTALLER_TMPDIR/trasher/Cargo.toml"
        mv "$INSTALLER_TMPDIR/trasher/target/release/trasher" "$ADF_BIN_DIR/trasher"
        command rm -rf "$INSTALLER_TMPDIR/trasher"
        return
    fi

    dlghbin "ClementNerma/Trasher" "trasher-linux-x86_64.zip" "-" "trasher" "trasher"
}

function utils() {
    # NAME: Utilities
    # PRIORITY: 1
    # ENV: all
    # VERSION: -
    # NEEDS_APT_UPDATE: yes

    sudo apt install -yqqq pv htop net-tools
}

function ytdlp() {
    # NAME: YT-DLP
    # PRIORITY: 1
    # ENV: all
    # VERSION: yt-dlp --version
    # NEEDS_APT_UPDATE: no

    dl "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" "$ADF_BIN_DIR/yt-dlp"

    sudo chmod a+rx "$ADF_BIN_DIR/yt-dlp"

    echoinfo "> Installing FFMpeg and AtomicParsley..."
    sudo apt install -yqqq ffmpeg atomicparsley

    # REMOVED as it makes yt-dlp buggy in many situations (wrong format selection, wrong playlists fetching, etc.)
    #
    # echoinfo "> Downloading dependencies for PhantomJS..."
    # sudo apt install -yqqq chrpath libxft-dev libfreetype6 libfreetype6-dev libfontconfig1 libfontconfig1-dev
    # # TODO: Find a way to not hardcode the version here
    # echoinfo "> Downloading PhantomJS..."
    # dl "https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2" "$INSTALLER_TMPDIR/phantomjs.tar.bz2"
    # tar -xf "$INSTALLER_TMPDIR/phantomjs.tar.bz2" -C "$INSTALLER_TMPDIR"
    # mv "$INSTALLER_TMPDIR/phantomjs-"*"/bin/phantomjs" "$ADF_BIN_DIR/phantomjs"
    # chmod +x "$ADF_BIN_DIR/phantomjs"
}

function ytsync_cache_builder() {
    # NAME: YTSync Cache Builder
    # PRIORITY: 1
    # ENV: all
    # VERSION: ytsync-cache-builder -V
    # NEEDS_APT_UPDATE: no

    if [[ $(dpkg --print-architecture) = "arm64" ]]; then
        ghdl "ClementNerma/ytsync-cache-builder" "$INSTALLER_TMPDIR/ytsync-cache-builder"
        cargo build --release --manifest-path="$INSTALLER_TMPDIR/ytsync-cache-builder/Cargo.toml"
        mv "$INSTALLER_TMPDIR/ytsync-cache-builder/target/release/ytsync-cache-builder" "$ADF_BIN_DIR/ytsync-cache-builder"
        command rm -rf "$INSTALLER_TMPDIR/ytsync-cache-builder"
        return
    fi

    dlghbin "ClementNerma/ytsync-cache-builder" "ytsync-cache-builder-linux-x86_64.zip" "-" "ytsync-cache-builder" "ytsync-cache-builder"
}

# function zoxide() {
#     # NAME: Zoxide
#     # PRIORITY: 1
#     # ENV: all
#     # VERSION: zoxide -V
#     # NEEDS_APT_UPDATE: no

#     dlghbin ajeetdsouza/zoxide "zoxide-v.*-x86_64-unknown-linux-musl.tar.gz" "zoxide-v.*-aarch64-unknown-linux-musl.tar.gz" "zoxide" "zoxide"
# }

# =============== MAIN COMPUTER =============== #

# function borg() {
#     # NAME: Borg
#     # PRIORITY: 1
#     # ENV: main-pc/all
#     # VERSION: borg -V
#     # NEEDS_APT_UPDATE: no

#     if ! (( $COMPONENT_UPDATING )); then
#         echoinfo "> Installing dependencies..."
#         sudo apt install libacl1-dev libacl1 libacl1-dev liblz4-dev libzstd1 libzstd-dev liblz4-1 libb2-1 libb2-dev -y

#         echoinfo "> Now installing Borg..."
#     fi

#     dlghrelease borgbackup/borg "borg-linux64$" "$ADF_BIN_DIR/borg"
#     chmod +x "$ADF_BIN_DIR/borg"
# }

# function borgmatic() {
#     # NAME: Borgmatic
#     # PRIORITY: 1
#     # ENV: main-pc/all
#     # VERSION: borgmatic --version
#     # NEEDS_APT_UPDATE: no

#     pip3 install --user --upgrade "borgmatic"
# }

function kopia() {
    # NAME: Kopia
    # PRIORITY: 1
    # ENV: main-pc/all
    # VERSION: kopia --version
    # NEEDS_APT_UPDATE: no

    dlghbin kopia/kopia "kopia-.*-linux-x64.tar.gz" "kopia-.*-linux-arm64.tar.gz" "kopia-*/kopia" kopia
}

function miniserve() {
    # NAME: MiniServe
    # PRIORITY: 1
    # ENV: main-pc/all
    # VERSION: miniserve -V
    # NEEDS_APT_UPDATE: no

    dlghrelease svenstaro/miniserve "miniserve-v.*-x86_64-unknown-linux-musl" "$ADF_BIN_DIR/miniserve"
    chmod +x "$ADF_BIN_DIR/miniserve"
}

function rclone() {
    # NAME: RClone (Windows)
    # PRIORITY: 1
    # ENV: main-pc/wsl
    # VERSION: rclone.exe -V | sed -n 1p
    # NEEDS_APT_UPDATE: no
    
    dlghbin "rclone/rclone" "rclone-.*-windows-amd64.zip" "-" "rclone-*/rclone.exe" "rclone.exe"
}

# =============== OPTIONAL =============== #

function imagemagick() {
    # NAME: ImageMagick
    # PRIORITY: 0
    # ENV: all
    # VERSION: convert --version
    # NEEDS_APT_UPDATE: yes

    sudo apt install imagemagick
}
