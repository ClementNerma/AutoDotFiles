if [[ $(dpkg --print-architecture) = "arm64" ]]; then
	_ZOXIDE_GREPPER="zoxide-armv7-unknown-linux-musleabihf"
else
	_ZOXIDE_GREPPER="zoxide-x86_64-unknown-linux-musl"
fi

dlghbin ajeetdsouza/zoxide "zoxide-x86_64-unknown-linux-musl.tar.gz" "zoxide-aarch64-unknown-linux-musl.tar.gz" "zoxide-*/zoxide" "zoxide"
