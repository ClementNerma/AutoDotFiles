dl "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" "$ADF_BIN_DIR/yt-dlp"

sudo chmod a+rx "$ADF_BIN_DIR/yt-dlp"

echoinfo "> Installing FFMpeg and AtomicParsley for Youtube-DL..."
sudo apt install -yqqq ffmpeg atomicparsley
