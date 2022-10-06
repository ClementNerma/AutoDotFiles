if [[ $(dpkg --print-architecture) = "arm64" ]]; then
	ghdl "ClementNerma/Trasher" "$INSTALLER_TMPDIR/trasher"
	cargo build --release --manifest-path="$INSTALLER_TMPDIR/trasher/Cargo.toml"
	mv "$INSTALLER_TMPDIR/trasher/target/release/trasher" "$ADF_BIN_DIR/trasher"
	command rm -rf "$INSTALLER_TMPDIR/trasher"
	return
fi

dlghbin "ClementNerma/Trasher" "trasher-linux-x86_64.zip" "-" "trasher" "trasher"
