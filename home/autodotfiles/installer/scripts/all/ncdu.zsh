# TODO: Find a way to not hardcode NCDU's version and link here
dl "https://dev.yorhel.nl/download/ncdu-2.0-beta2-linux-x86_64.tar.gz" "$INSTALLER_TMPDIR/ncdu.tar.gz"
tar zxf "$INSTALLER_TMPDIR/ncdu.tar.gz" -C "$ADF_BIN_DIR"
