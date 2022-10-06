curl https://getmic.ro | bash
chmod +x micro
mv micro $ADF_BIN_DIR

if [[ ! -d $HOME/.config/micro ]]; then
    mkdir $HOME/.config/micro
    cat <<-EOF  > $HOME/.config/micro/bindings.json
{
    "CtrlN": "AddTab",
    "CtrlW": "Quit",
    "CtrlD": "SpawnMultiCursor"
}
EOF
fi
