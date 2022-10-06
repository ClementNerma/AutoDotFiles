if [[ $ZER_UPDATING = 0 ]]; then
    echoinfo "> Installing dependencies..."
    sudo apt install libacl1-dev libacl1 liblz4-dev libzstd1 libzstd-dev liblz4-1 libb2-1 libb2-dev -y
fi

echoinfo "> Installing Borg..."
sudo pip3 install --upgrade "borgbackup[fuse]"

echoinfo "> Installing Borgmatic..."
sudo pip3 install --upgrade "borgmatic"
